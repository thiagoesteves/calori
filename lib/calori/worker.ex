defmodule Calori.Worker do
  @moduledoc false

  use GenServer
  require Logger

  ### ==========================================================================
  ### Callback functions
  ### ==========================================================================

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("Initialising #{__MODULE__} server")

    interval = 60_000

    schedule_new_deployment(interval)

    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:schedule, state) do
    schedule_new_deployment(state.interval)

    Logger.info("Running #{__MODULE__} Scheduler (/•ิ_•ิ) 🔥 (╯°□°)╯")

    {:noreply, state}
  end

  @impl true
  def code_change(old_vsn, state, _extra) do
    Logger.warning("Running Hotupgrade for #{__MODULE__} old-version: #{old_vsn}")
    {:ok, state}
  end

  ### ==========================================================================
  ### Public API
  ### ==========================================================================

  ### ==========================================================================
  ### Private functions
  ### ==========================================================================

  defp schedule_new_deployment(timeout), do: Process.send_after(self(), :schedule, timeout)
end
