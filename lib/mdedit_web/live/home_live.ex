defmodule MdeditWeb.HomeLive do
  use MdeditWeb, :live_view

  alias Mdedit.Documents

  @impl true
  def mount(_params, _session, socket) do
    documents = Documents.list_documents()

    socket =
      socket
      |> assign(:documents, documents)

    {:ok, socket}
  end

  @impl true
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
      <!-- Hero Section -->
      <div class="container mx-auto p-4 max-w-6xl flex flex-col">
        <!-- Hero Content -->
        <div class="text-center flex-shrink-0">
          <div class="inline-flex items-center justify-center w-12 h-12 bg-primary/10 rounded-xl mb-3">
            <.icon name="hero-document-text" class="w-6 h-6 text-primary" />
          </div>
          <h1 class="text-3xl font-bold text-base-content mb-3 leading-tight">
            Collaborative <span class="text-primary">Markdown</span> Editor
          </h1>
          <p class="text-base text-base-content/70 mb-4 max-w-xl mx-auto">
            Write, edit, and collaborate on markdown documents in real-time.
          </p>
          <.link
            navigate={~p"/editor"}
            class="btn btn-primary rounded-full"
          >
            <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Start Writing
          </.link>
        </div>

    <!-- Documents Section -->
        <%= if @documents != [] do %>
          <div class="max-w-4xl mx-auto flex-1 flex flex-col min-h-0 mt-8">
            <div class="flex items-center justify-between mb-3 flex-shrink-0">
              <h2 class="text-lg font-semibold text-base-content">Recent Documents</h2>
              <span class="text-xs text-base-content/60">
                {length(@documents)} document{if length(@documents) != 1, do: "s"}
              </span>
            </div>

            <div class="flex flex-col gap-2 overflow-y-auto">
              <div
                :for={document <- @documents}
                class="group bg-base-100 rounded-lg border border-base-300/50 transition-all duration-300 overflow-hidden flex items-center justify-between p-3 w-full sm:w-96 gap-3"
              >
                <div class="flex-1">
                  <h3 class="text-sm font-medium text-base-content truncate">
                    <.link
                      navigate={~p"/editor/#{document.slug}"}
                      class="hover:text-primary transition-colors duration-200"
                    >
                      {document.title}
                    </.link>
                  </h3>
                  <div class="flex items-center gap-3 mt-1">
                    <p class="text-xs text-base-content/60 flex-shrink-0">
                      {Calendar.strftime(document.updated_at, "%b %d")}
                    </p>
                    <span class="text-xs text-base-content/50 text-ellipsis overflow-hidden">
                      /editor/{document.slug}
                    </span>
                  </div>
                </div>
                <.button
                  phx-click="delete_document"
                  phx-value-id={document.id}
                  class="btn btn-sm btn-ghost"
                  data-confirm="Are you sure you want to delete this document?"
                  title="Delete document"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </.button>
              </div>
            </div>
          </div>
        <% else %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
