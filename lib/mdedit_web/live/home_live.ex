defmodule MdeditWeb.HomeLive do
  use MdeditWeb, :live_view

  alias Mdedit.Documents

  @impl true
  def mount(_params, _session, socket) do
    documents = Documents.list_documents()

    socket =
      socket
      |> assign(:documents, documents)
      |> assign(:form, to_form(%{"title" => ""}))

    {:ok, socket}
  end

  @impl true
  def handle_event("create_document", %{"title" => title}, socket) do
    case Documents.create_document(%{title: title}) do
      {:ok, document} ->
        {:noreply, push_navigate(socket, to: ~p"/editor/#{document.slug}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete_document", %{"id" => id}, socket) do
    document = Documents.get_document!(id)
    {:ok, _} = Documents.delete_document(document)

    documents = Documents.list_documents()
    {:noreply, assign(socket, :documents, documents)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <.header>
          Collaborative Markdown Editor
          <:subtitle>
            Create, edit, and collaborate on markdown documents in real-time
          </:subtitle>
          <:actions>
            <.link navigate={~p"/editor"} class="btn btn-primary">
              <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Document
            </.link>
          </:actions>
        </.header>
        
    <!-- Quick Create Form -->
        <div class="card bg-base-100 shadow-sm border border-base-300 mb-8">
          <div class="card-body">
            <h3 class="card-title text-lg">Quick Create</h3>
            <.form for={@form} phx-submit="create_document" class="flex gap-2">
              <.input
                field={@form[:title]}
                type="text"
                placeholder="Enter document title..."
                class="input input-bordered flex-1"
                required
              />
              <.button type="submit" class="btn btn-primary">
                Create
              </.button>
            </.form>
          </div>
        </div>
        
    <!-- Documents List -->
        <div class="space-y-4">
          <h2 class="text-xl font-semibold">Recent Documents</h2>

          <%= if @documents == [] do %>
            <div class="text-center py-12 text-base-content/60">
              <.icon name="hero-document-text" class="w-16 h-16 mx-auto mb-4 opacity-50" />
              <p class="text-lg mb-2">No documents yet</p>
              <p>Create your first document to get started!</p>
            </div>
          <% else %>
            <div class="grid gap-4">
              <div
                :for={document <- @documents}
                class="card bg-base-100 shadow-sm border border-base-300 hover:shadow-md transition-shadow"
              >
                <div class="card-body">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <h3 class="card-title text-lg">
                        <.link navigate={~p"/editor/#{document.slug}"} class="link link-hover">
                          {document.title}
                        </.link>
                      </h3>
                      <p class="text-sm text-base-content/60 mt-1">
                        Last updated: {Calendar.strftime(document.updated_at, "%B %d, %Y at %I:%M %p")}
                      </p>
                      <p class="text-sm text-base-content/60">
                        Share URL:
                        <code class="text-xs bg-base-200 px-1 py-0.5 rounded">
                          /editor/{document.slug}
                        </code>
                      </p>
                    </div>
                    <div class="flex gap-2">
                      <.link
                        navigate={~p"/editor/#{document.slug}"}
                        class="btn btn-sm btn-outline"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> Edit
                      </.link>
                      <.button
                        phx-click="delete_document"
                        phx-value-id={document.id}
                        class="btn btn-sm btn-outline btn-error"
                        data-confirm="Are you sure you want to delete this document?"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </.button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
