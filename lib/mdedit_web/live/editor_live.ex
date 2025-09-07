defmodule MdeditWeb.EditorLive do
  @moduledoc """
  LiveView for collaborative markdown editing.

  Provides real-time editing and preview functionality with user presence tracking.
  """
  use MdeditWeb, :live_view

  alias Mdedit.Documents
  alias MdeditWeb.Presence

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # try to find existing document
    case Documents.get_document_by_slug(slug) do
      nil ->
        # Document doesn't exist, show expiration selection
        # Store admin token from connect_params for later use
        admin_token = get_connect_params(socket)["admin_token"]

        {:ok,
         socket
         |> assign(:slug, slug)
         |> assign(:document, nil)
         |> assign(:show_expiration_dialog, true)
         |> assign(:expiration_options, Mdedit.Documents.Document.expiration_options())
         |> assign(:selected_expiration, {1, :month}) # default
         |> assign(:stored_admin_token, admin_token)
        }

      document ->
        # Document exists, proceed normally
        admin_token = get_connect_params(socket)["admin_token"]
        setup_existing_document(socket, document, admin_token)
    end
  end

  def mount(_params, _session, socket) do
    # if no slug provided, create a new document
    slug = generate_slug()
    {:ok, push_navigate(socket, to: ~p"/editor/#{slug}")}
  end

  defp setup_existing_document(socket, document, admin_token) do
    # Use the admin token passed as parameter
    is_admin = Documents.admin?(document, admin_token)

    # subscribe to document updates for real-time collaboration
    topic = "document:#{document.slug}"
    presence_topic = "presence:#{document.slug}"

    # determine user_id based on connection status
    user_id =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mdedit.PubSub, topic)
        Phoenix.PubSub.subscribe(Mdedit.PubSub, presence_topic)

        # generate a user identifier
        user_id = generate_user_id()
        user_name = "User #{String.slice(user_id, 0, 6)}"

        # track presence
        {:ok, _} =
          Presence.track(self(), presence_topic, user_id, %{
            name: user_name,
            joined_at: System.system_time(:second)
          })

        user_id
      else
        nil
      end

    # create form for the document
    form = Documents.change_document(document) |> to_form()

    socket =
      socket
      |> assign(:document, document)
      |> assign(:form, form)
      |> assign(:preview_html, Documents.markdown_to_html(document.content || ""))
      |> assign(:topic, topic)
      |> assign(:presence_topic, presence_topic)
      |> assign(:connected_users, %{})
      |> assign(:user_id, user_id)
      |> assign(:last_content, document.content || "")
      |> assign(:mobile_tab, "editor")
      |> assign(:is_admin, is_admin)
      |> assign(:admin_token, if(is_admin, do: document.admin_token, else: nil))
      |> assign(:show_delete_confirmation, false)
      |> assign(:show_expiration_dialog, false)
      |> handle_presence_diff(%{})

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # Store admin token when document is first created
    if socket.assigns[:document] && socket.assigns[:document].admin_token &&
         socket.assigns.is_admin do
      socket =
        push_event(socket, "store_admin_token", %{
          slug: socket.assigns.document.slug,
          admin_token: socket.assigns.document.admin_token
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("content_changed", %{"content" => content}, socket) do
    # update the preview in real-time
    preview_html = Documents.markdown_to_html(content)

    # update the form with new content
    form =
      socket.assigns.document
      |> Map.put(:content, content)
      |> Documents.change_document()
      |> to_form()

    # broadcast the change to other connected users
    Phoenix.PubSub.broadcast(
      Mdedit.PubSub,
      socket.assigns.topic,
      {:content_changed, content, self()}
    )

    # Auto-save after a delay (debounced)
    Process.send_after(self(), {:auto_save, content}, 2000)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:preview_html, preview_html)
      |> assign(:last_content, content)

    {:noreply, socket}
  end

  def handle_event("save_document", _params, socket) do
    # get current form values
    title = Phoenix.HTML.Form.input_value(socket.assigns.form, :title) || ""
    content = Phoenix.HTML.Form.input_value(socket.assigns.form, :content) || ""

    document_params = %{title: title, content: content}

    case Documents.update_document(socket.assigns.document, document_params) do
      {:ok, document} ->
        # broadcast save to other users
        Phoenix.PubSub.broadcast(
          Mdedit.PubSub,
          socket.assigns.topic,
          {:document_saved, document, self()}
        )

        socket =
          socket
          |> assign(:document, document)
          # Don't recreate the form - just update the document reference
          # This preserves the current editor state
          |> put_flash(:info, "Document saved successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("title_changed", %{"value" => title}, socket) do
    # update the form with new title
    form =
      socket.assigns.document
      |> Map.put(:title, title)
      |> Documents.change_document()
      |> to_form()

    # broadcast title change to other users
    Phoenix.PubSub.broadcast(
      Mdedit.PubSub,
      socket.assigns.topic,
      {:title_changed, title, self()}
    )

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("share_document", _params, socket) do
    # Get the full URL for sharing
    url = "#{MdeditWeb.Endpoint.url()}/editor/#{socket.assigns.document.slug}"

    socket =
      socket
      |> put_flash(:info, "Collaboration link copied! Share it to edit together.")
      |> push_event("copy_to_clipboard", %{text: url})

    {:noreply, socket}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in ["editor", "preview"] do
    {:noreply, assign(socket, :mobile_tab, tab)}
  end

  def handle_event("select_expiration", %{"expiration" => expiration_key}, socket) do
    selected_expiration =
      case expiration_key do
        "1_day" -> {1, :day}
        "1_week" -> {1, :week}
        "1_month" -> {1, :month}
        "1_year" -> {1, :year}
        _ -> {1, :month}
      end

    {:noreply, assign(socket, :selected_expiration, selected_expiration)}
  end

  def handle_event("create_document_with_expiration", _params, socket) do
    expiration_datetime = Mdedit.Documents.Document.calculate_expiration(socket.assigns.selected_expiration)

    document_attrs = %{
      title: "New Document",
      content: default_content(),
      slug: socket.assigns.slug,
      expires_at: expiration_datetime
    }

    case Documents.create_document_with_admin(document_attrs) do
      {:ok, document} ->
        # Document created successfully, now set it up using stored admin token
        admin_token = socket.assigns.stored_admin_token
        socket = setup_existing_document(socket, document, admin_token)
        case socket do
          {:ok, socket} ->
            {:noreply, socket}
          socket ->
            {:noreply, socket}
        end

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create document")}
    end
  end

  def handle_event("show_delete_confirmation", _params, socket) do
    if socket.assigns.is_admin do
      {:noreply, assign(socket, :show_delete_confirmation, true)}
    else
      {:noreply, put_flash(socket, :error, "Only the creator can delete this document")}
    end
  end

  def handle_event("hide_delete_confirmation", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirmation, false)}
  end

  def handle_event("delete_document", _params, socket) do
    if socket.assigns.is_admin do
      case Documents.delete_document(socket.assigns.document) do
        {:ok, _document} ->
          # Clear admin token from localStorage
          {:noreply,
           socket
           |> push_event("clear_admin_token", %{slug: socket.assigns.document.slug})
           |> put_flash(:info, "Document deleted successfully")
           |> redirect(to: ~p"/")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete document")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the creator can delete this document")}
    end
  end

  @impl true
  def handle_info({:content_changed, content, sender_pid}, socket) do
    # don't update if this change came from current user
    if sender_pid != self() do
      preview_html = Documents.markdown_to_html(content)

      # update the form with new content
      form =
        socket.assigns.document
        |> Map.put(:content, content)
        |> Documents.change_document()
        |> to_form()

      socket =
        socket
        |> assign(:form, form)
        |> assign(:preview_html, preview_html)
        |> push_event("sync_content", %{content: content})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:title_changed, title, sender_pid}, socket) do
    if sender_pid != self() do
      # update the form with new title
      form =
        socket.assigns.document
        |> Map.put(:title, title)
        |> Documents.change_document()
        |> to_form()

      {:noreply, assign(socket, :form, form)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:document_saved, document, sender_pid}, socket) do
    if sender_pid != self() do
      socket =
        socket
        |> assign(:document, document)
        |> assign(:form, Documents.change_document(document) |> to_form())
        |> put_flash(:info, "Document updated by another user")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {:noreply, handle_presence_diff(socket, diff)}
  end

  def handle_info({:auto_save, content}, socket) do
    # Only auto-save if the content hasn't changed since the timer was set
    current_content = Phoenix.HTML.Form.input_value(socket.assigns.form, :content) || ""

    if current_content == content and content != socket.assigns.document.content do
      title = Phoenix.HTML.Form.input_value(socket.assigns.form, :title) || ""
      document_params = %{title: title, content: content}

      case Documents.update_document(socket.assigns.document, document_params) do
        {:ok, document} ->
          # broadcast save to other users
          Phoenix.PubSub.broadcast(
            Mdedit.PubSub,
            socket.assigns.topic,
            {:document_saved, document, self()}
          )

          socket =
            socket
            |> assign(:document, document)
            |> put_flash(:info, "Auto-saved")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end


  defp default_content do
    """
    # Welcome to the collaborative markdown editor!

    Start typing to see the live preview on the right.
    """
  end

  defp generate_slug do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
    |> String.downcase()
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(12)
    |> Base.url_encode64(padding: false)
    |> String.downcase()
  end

  defp handle_presence_diff(socket, _diff) do
    presence = Presence.list(socket.assigns.presence_topic)

    connected_users =
      presence
      |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
        {user_id, meta}
      end)
      |> Enum.into(%{})

    assign(socket, :connected_users, connected_users)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if assigns[:show_expiration_dialog] && @show_expiration_dialog do %>
      <!-- Show only the expiration dialog when document doesn't exist -->
      <div class="h-screen flex items-center justify-center bg-base-200">
        <!-- Expiration Selection Dialog -->
        <div class="card bg-base-100 shadow-xl max-w-md w-full mx-4">
          <div class="card-body text-center">
            <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-primary/10 mb-4">
              <.icon name="hero-clock" class="h-6 w-6 text-primary" />
            </div>
            <h2 class="card-title justify-center mb-2">Set Document Expiration</h2>
            <p class="text-sm text-base-content/70 mb-6">
              Choose how long this document should remain accessible. After expiration, it will no longer be available.
            </p>

            <div class="space-y-3 mb-6">
              <%= for {label, duration} <- @expiration_options do %>
                <label class="flex items-center space-x-3 cursor-pointer p-3 rounded-lg hover:bg-base-200 transition-colors">
                  <input
                    type="radio"
                    name="expiration"
                    value={duration_to_key(duration)}
                    checked={@selected_expiration == duration}
                    phx-click="select_expiration"
                    phx-value-expiration={duration_to_key(duration)}
                    class="radio radio-primary"
                  />
                  <span class="text-sm font-medium"><%= label %></span>
                </label>
              <% end %>
            </div>

            <div class="card-actions justify-center">
              <button
                phx-click="create_document_with_expiration"
                class="btn btn-primary btn-wide"
              >
                <.icon name="hero-plus" class="w-4 h-4 mr-2" />
                Create Document
              </button>
            </div>
          </div>
        </div>
      </div>
    <% else %>
      <!-- Show normal editor when document exists -->
      <div class="h-screen flex flex-col">
        <!-- Responsive Header -->
        <header class="bg-base-100 border-b border-base-300 px-4 py-2">
          <!-- Desktop: Single Row -->
          <div class="hidden md:flex items-center justify-between min-h-8">
            <!-- Left side: Logo and Document Title -->
            <div class="flex items-center gap-4 flex-1 mr-4 lg:mr-0">
              <a href="/" class="flex items-center gap-2 text-lg font-bold">
                <.icon name="hero-document-text" class="w-5 h-5" /> MDEdit
              </a>
              <.input
                field={@form[:title]}
                type="text"
                id="document-title-desktop"
                class="input input-sm h-6"
                wrapper_class="mb-0 flex-1 max-w-md"
                placeholder="Document title..."
                phx-blur="title_changed"
                phx-change="title_changed"
              />
            </div>

    <!-- Right side: Users, Share, Save -->
          <div class="flex items-center gap-4">
            <!-- Connected Users -->
            <div class="flex items-center gap-2">
              <span class="text-sm text-base-content/70">
                {map_size(@connected_users)} online
              </span>
              <div class="flex -space-x-2">
                <div :for={{user_id, user} <- @connected_users} class="relative">
                  <div
                    class={
                      cn(
                        "w-7 h-7 rounded-full bg-primary text-primary-content",
                        "flex items-center justify-center text-xs font-medium",
                        "border-2 border-base-100"
                      )
                    }
                    title={user.name}
                  >
                    {String.first(user.name)}
                  </div>
                </div>
              </div>
            </div>

            <span class="text-xs text-base-content/50">
              Auto-save enabled
            </span>
            <.button
              type="button"
              phx-click="save_document"
              class="btn btn-ghost btn-sm"
              title="Manual save (Ctrl+S)"
            >
              <.icon name="hero-document-arrow-down" class="w-4 h-4 mr-1" /> Save
            </.button>
            <.button
              type="button"
              phx-click="share_document"
              class="btn btn-primary btn-sm"
              title="Share for collaboration"
            >
              <.icon name="hero-share" class="w-4 h-4 mr-1" /> Share
            </.button>
            <%= if @is_admin do %>
              <.button
                type="button"
                phx-click="show_delete_confirmation"
                class="btn btn-error btn-sm"
                title="Delete document (creator only)"
              >
                <.icon name="hero-trash" class="w-4 h-4 mr-1" /> Delete
              </.button>
            <% end %>
          </div>
        </div>

    <!-- Mobile: Two Rows -->
        <div class="md:hidden space-y-3">
          <!-- Top Row: Logo and Document Title -->
          <div class="flex items-center gap-3">
            <a href="/" class="flex items-center gap-2 text-lg font-bold flex-shrink-0">
              <.icon name="hero-document-text" class="w-5 h-5" /> MDEdit
            </a>
            <div class="flex-1">
              <.input
                field={@form[:title]}
                type="text"
                id="document-title-mobile"
                class="input input-bordered input-sm w-full"
                wrapper_class="mb-0"
                placeholder="Document title..."
                phx-blur="title_changed"
                phx-change="title_changed"
              />
            </div>
          </div>

    <!-- Bottom Row: Users and Actions -->
          <div class="flex items-center justify-between gap-2">
            <!-- Left: Connected Users -->
            <div class="flex items-center gap-2 flex-1">
              <span class="text-xs text-base-content/70">
                {map_size(@connected_users)} online
              </span>
              <div class="flex -space-x-1">
                <div :for={{user_id, user} <- @connected_users} class="relative">
                  <div
                    class={
                      cn(
                        "w-6 h-6 rounded-full bg-primary text-primary-content",
                        "flex items-center justify-center text-xs font-medium",
                        "border-2 border-base-100"
                      )
                    }
                    title={user.name}
                  >
                    {String.first(user.name)}
                  </div>
                </div>
              </div>
            </div>

    <!-- Right: Actions -->
            <div class="flex items-center gap-2">
              <span class="text-xs text-base-content/50 hidden sm:inline">
                Auto-save
              </span>
              <.button
                type="button"
                phx-click="save_document"
                class="btn btn-ghost btn-sm sm:btn-xs"
                title="Manual save (Ctrl+S)"
              >
                <.icon name="hero-document-arrow-down" class="w-4 h-4" />
                <span class="hidden sm:inline ml-1">Save</span>
              </.button>
              <.button
                type="button"
                phx-click="share_document"
                class="btn btn-primary btn-sm sm:btn-xs sm:btn-primary"
                title="Share for collaboration"
              >
                <.icon name="hero-share" class="w-4 h-4" />
                <span class="hidden sm:inline ml-1">Share</span>
              </.button>
              <%= if @is_admin do %>
                <.button
                  type="button"
                  phx-click="show_delete_confirmation"
                  class="btn btn-error btn-sm sm:btn-xs sm:btn-error"
                  title="Delete document (creator only)"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                  <span class="hidden sm:inline ml-1">Delete</span>
                </.button>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <MdeditWeb.Layouts.flash_group flash={@flash} />

    <!-- Main Editor Area -->
      <div class="flex-1 flex flex-col overflow-hidden">
        <!-- Desktop: Side by Side -->
        <div class="hidden md:flex flex-1 overflow-hidden">
          <!-- Editor Pane -->
          <div class="w-1/2 flex flex-col border-r border-base-300">
            <div class="bg-base-100 px-4 py-2 border-b border-base-300">
              <h2 class="text-sm font-semibold text-base-content/70">Editor</h2>
            </div>
            <.form for={@form} id="editor-form" class="h-full">
              <textarea
                id="markdown-editor"
                name="content"
                phx-change="content_changed"
                phx-hook="EditorHook"
                class="w-full h-full resize-none border-0 focus:ring-0 focus:outline-none font-mono text-sm leading-relaxed bg-transparent p-4"
                placeholder="Start typing your markdown here..."
                spellcheck="false"
                autocomplete="off"
              >{Phoenix.HTML.Form.input_value(@form, :content)}</textarea>
            </.form>
          </div>

    <!-- Preview Pane -->
          <div class="w-1/2 flex flex-col">
            <div class="bg-base-100 px-4 py-2 border-b border-base-300">
              <h2 class="text-sm font-semibold text-base-content/70">Preview</h2>
            </div>
            <div class="flex-1 p-4 overflow-auto">
              <article
                id="markdown-preview"
                class="max-w-none"
              >
                {Phoenix.HTML.raw(@preview_html)}
              </article>
            </div>
          </div>
        </div>

    <!-- Mobile: Tabbed Interface -->
        <div class="md:hidden flex-1 flex flex-col overflow-hidden">
          <!-- Tab Navigation -->
          <div class="bg-base-100 border-b border-base-300">
            <div class="flex">
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="editor"
                class={[
                  "flex-1 px-4 py-2 text-sm font-medium border-b-2 transition-colors",
                  if(@mobile_tab == "editor",
                    do: "border-primary text-primary bg-primary/5",
                    else:
                      "border-transparent text-base-content/70 hover:text-base-content hover:border-base-300"
                  )
                ]}
              >
                <.icon name="hero-pencil-square" class="w-4 h-4 mr-2" /> Editor
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="preview"
                class={[
                  "flex-1 px-4 py-2 text-sm font-medium border-b-2 transition-colors",
                  if(@mobile_tab == "preview",
                    do: "border-primary text-primary bg-primary/5",
                    else:
                      "border-transparent text-base-content/70 hover:text-base-content hover:border-base-300"
                  )
                ]}
              >
                <.icon name="hero-eye" class="w-4 h-4 mr-2" /> Preview
              </button>
            </div>
          </div>

    <!-- Tab Content -->
          <div class="flex-1 overflow-hidden">
            <!-- Editor Tab -->
            <div class={["h-full", if(@mobile_tab != "editor", do: "hidden")]}>
              <.form for={@form} id="editor-form-mobile" class="h-full">
                <textarea
                  id="markdown-editor-mobile"
                  name="content"
                  phx-change="content_changed"
                  phx-hook="EditorHook"
                  class="w-full h-full resize-none border-0 focus:ring-0 focus:outline-none font-mono text-sm leading-relaxed bg-transparent p-4"
                  placeholder="Start typing your markdown here..."
                  spellcheck="false"
                  autocomplete="off"
                >{Phoenix.HTML.Form.input_value(@form, :content)}</textarea>
              </.form>
            </div>

    <!-- Preview Tab -->
            <div class={["h-full overflow-auto", if(@mobile_tab != "preview", do: "hidden")]}>
              <div class="p-4">
                <article
                  id="markdown-preview-mobile"
                  class="max-w-none"
                >
                  {Phoenix.HTML.raw(@preview_html)}
                </article>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <% end %>

    <!-- Delete Confirmation Modal -->
    <%= if assigns[:show_delete_confirmation] && @show_delete_confirmation do %>
      <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <div class="mt-3 text-center">
            <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100">
              <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-600" />
            </div>
            <h3 class="text-lg leading-6 font-medium text-gray-900 mt-4">Delete Document</h3>
            <div class="mt-2 px-7 py-3">
              <p class="text-sm text-gray-500">
                Are you sure you want to delete "{@document.title}"? This action cannot be undone and all content will be permanently lost.
              </p>
            </div>
            <div class="flex items-center justify-center space-x-4 mt-4">
              <button
                phx-click="hide_delete_confirmation"
                class="px-4 py-2 bg-gray-300 text-gray-800 text-base font-medium rounded-md shadow-sm hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-300"
              >
                Cancel
              </button>
              <button
                phx-click="delete_document"
                class="px-4 py-2 bg-red-600 text-white text-base font-medium rounded-md shadow-sm hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp duration_to_key({1, :day}), do: "1_day"
  defp duration_to_key({1, :week}), do: "1_week"
  defp duration_to_key({1, :month}), do: "1_month"
  defp duration_to_key({1, :year}), do: "1_year"
end
