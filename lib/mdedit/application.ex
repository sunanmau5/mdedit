defmodule Mdedit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MdeditWeb.Telemetry,
      Mdedit.Repo,
      {DNSCluster, query: Application.get_env(:mdedit, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Mdedit.PubSub},
      # Start a worker by calling: Mdedit.Worker.start_link(arg)
      # {Mdedit.Worker, arg},
      # Start to serve requests, typically the last entry
      MdeditWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mdedit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MdeditWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
