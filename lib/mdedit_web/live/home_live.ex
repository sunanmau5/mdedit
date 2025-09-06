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
      <div class="h-screen bg-gradient-to-br from-base-100 via-base-100 to-base-200 overflow-y-auto">
        <div class="container mx-auto px-4 py-4 max-w-6xl h-full flex flex-col">
          <!-- Hero Content -->
          <div class="text-center mb-6 flex-shrink-0">
            <div class="inline-flex items-center justify-center w-12 h-12 bg-primary/10 rounded-xl mb-3">
              <.icon name="hero-document-text" class="w-6 h-6 text-primary" />
            </div>
            <h1 class="text-3xl font-bold text-base-content mb-3 leading-tight">
              Collaborative
              <span class="text-primary">Markdown</span>
              Editor
            </h1>
            <p class="text-base text-base-content/70 mb-4 max-w-xl mx-auto">
              Write, edit, and collaborate on markdown documents in real-time.
            </p>
            <.link navigate={~p"/editor"} class="btn btn-primary px-6 py-2 rounded-full shadow-lg hover:shadow-xl transition-all duration-300">
              <.icon name="hero-plus" class="w-4 h-4 mr-2" />
              Start Writing
            </.link>
          </div>

          <!-- Documents Section -->
          <%= if @documents != [] do %>
            <div class="max-w-4xl mx-auto flex-1 flex flex-col min-h-0">
              <div class="flex items-center justify-between mb-3 flex-shrink-0">
                <h2 class="text-lg font-semibold text-base-content">Recent Documents</h2>
                <span class="text-xs text-base-content/60">{length(@documents)} document{if length(@documents) != 1, do: "s"}</span>
              </div>

              <div class="grid gap-2 overflow-y-auto">
                <div
                  :for={document <- @documents}
                  class="group bg-base-100 rounded-lg border border-base-300/50 hover:border-primary/30 hover:shadow-md transition-all duration-300 overflow-hidden"
                >
                  <div class="p-3">
                    <div class="flex items-center justify-between">
                      <div class="flex-1 min-w-0 mr-3">
                        <h3 class="text-sm font-medium text-base-content truncate">
                          <.link
                            navigate={~p"/editor/#{document.slug}"}
                            class="hover:text-primary transition-colors duration-200"
                          >
                            {document.title}
                          </.link>
                        </h3>
                        <div class="flex items-center gap-3 mt-1">
                          <p class="text-xs text-base-content/60">
                            {Calendar.strftime(document.updated_at, "%b %d")}
                          </p>
                          <span class="text-xs text-base-content/50">
                            /editor/{String.slice(document.slug, 0, 8)}...
                          </span>
                        </div>
                      </div>
                      <div class="flex gap-1">
                        <.link
                          navigate={~p"/editor/#{document.slug}"}
                          class="btn btn-xs btn-ghost hover:btn-primary transition-all duration-200"
                          title="Edit document"
                        >
                          <.icon name="hero-pencil" class="w-3 h-3" />
                        </.link>
                        <.button
                          phx-click="delete_document"
                          phx-value-id={document.id}
                          class="btn btn-xs btn-ghost hover:btn-error transition-all duration-200"
                          data-confirm="Are you sure you want to delete this document?"
                          title="Delete document"
                        >
                          <.icon name="hero-trash" class="w-3 h-3" />
                        </.button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% else %>
            <!-- Empty State -->
            <div class="max-w-md mx-auto text-center flex-1 flex flex-col justify-center">
              <div class="inline-flex items-center justify-center w-16 h-16 bg-base-200 rounded-full mb-3">
                <.icon name="hero-document-plus" class="w-8 h-8 text-base-content/40" />
              </div>
              <h3 class="text-base font-semibold text-base-content mb-2">No documents yet</h3>
              <p class="text-base-content/60 mb-3 text-sm">
                Create your first markdown document and start collaborating.
              </p>
              <.link navigate={~p"/editor"} class="btn btn-primary rounded-full px-4">
                <.icon name="hero-plus" class="w-4 h-4 mr-2" />
                Create Document
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
