defmodule Calori.ConfigProvider.Secrets.Manager do
  @moduledoc """
  https://hexdocs.pm/elixir/1.14.0-rc.1/Config.Provider.html

  Fetch secrets from AWS Secrets Manager, then load those secrets into configs.

  Similar examples:
    - https://github.com/Adzz/gcp_secret_provider/blob/master/lib/gcp_secret_provider.ex
    - https://github.com/sevenmind/vault_config_provider
  """
  @behaviour Config.Provider

  require Logger

  @impl Config.Provider
  def init(_path), do: []

  @doc """
  load/2.

  Args:
    - config is the current config
    - opts is just the return value of init/1.

  Calls out to AWS Secrets Manager, parses the JSON response, sets configs to parsed response.
  """
  @impl Config.Provider
  def load(config, opts) do
    Logger.info("Running Config Provider for Secrets")
    env = Keyword.get(config, :calori) |> Keyword.get(:env)

    secrets_adapter =
      Keyword.get(config, :calori)
      |> Keyword.get(Calori.ConfigProvider.Secrets.Manager)
      |> Keyword.get(:adapter)

    secrets_path =
      Keyword.get(config, :calori)
      |> Keyword.get(Calori.ConfigProvider.Secrets.Manager)
      |> Keyword.get(:path)

    if env == "local" do
      Logger.info("  - No secrets retrieved, local environment")
      config
    else
      {:ok, _} = Application.ensure_all_started(:hackney)
      {:ok, _} = Application.ensure_all_started(:ex_aws)

      Logger.info("  - Trying to retrieve secrets: #{secrets_adapter} - #{secrets_path}")

      secrets = secrets_adapter.secrets(config, secrets_path, opts)

      secret_key_base = keyword(:secret_key_base, secrets["CALORI_SECRET_KEY_BASE"])
      erlang_cookie = secrets["CALORI_ERLANG_COOKIE"] |> String.to_atom()

      # Config Erlang Cookie if the node exist
      node = :erlang.node()

      if node != :nonode@nohost do
        :erlang.set_cookie(node, erlang_cookie)
      end

      Config.Reader.merge(
        config,
        calori: [
          {CaloriWeb.Endpoint, secret_key_base}
        ]
      )
    end
  end

  defp keyword(key_name, value) do
    Keyword.new([{key_name, value}])
  end
end
