defmodule ProxyConf.Api.DbTlsCert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_tlscerts" do
    field :cluster, :string
    field :hostname, :string
    field :local_ca, :boolean
    field :cert_pem, :binary
    field :key_pem, ProxyConf.Vault.EncryptedBinary

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(db_tls_cert, attrs) do
    db_tls_cert
    |> cast(attrs, [:cluster, :hostname, :local_ca, :key_pem, :cert_pem])
    |> validate_required([:cluster, :hostname, :local_ca, :key_pem, :cert_pem])
  end
end
