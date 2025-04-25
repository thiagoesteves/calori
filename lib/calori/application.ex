defmodule Calori.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CaloriWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:calori, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Calori.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Calori.Finch},
      # Start a worker by calling: Calori.Worker.start_link(arg)
      Calori.Worker,
      # Start to serve requests, typically the last entry
      CaloriWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Calori.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CaloriWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
