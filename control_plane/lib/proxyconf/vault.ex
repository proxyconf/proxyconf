defmodule ProxyConf.Vault do
  @moduledoc """
    This module implements the Cloak.Vault used to encrypt data in Ecto.Repo
  """
  use Cloak.Vault, otp_app: :proxyconf

  @impl GenServer
  def init(config) do
    encryption_key_fn =
      Application.fetch_env!(:proxyconf, ProxyConf.Vault)
      |> Keyword.fetch!(:encryption_key_fn)

    config =
      Keyword.put(config, :ciphers,
        default:
          {Cloak.Ciphers.AES.GCM,
           tag: "AES.GCM.V1", key: encryption_key_fn.() |> Base.decode64!()}
      )

    {:ok, config}
  end

  defmodule EncryptedBinary do
    @moduledoc """
      Local Ecto type used in schemas that require field level encrytion
    """
    use Cloak.Ecto.Binary, vault: ProxyConf.Vault
  end
end
