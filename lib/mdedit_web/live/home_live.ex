defmodule MdeditWeb.HomeLive do
  use MdeditWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # In Etherpad-style system, no document discovery - only direct links
    {:ok, socket}
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
      </div>
    </Layouts.app>
    """
  end
end
