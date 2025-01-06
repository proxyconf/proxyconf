defmodule ProxyConf.Api.DbSecret do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_secret" do
    field :cluster, :string
    field :name, :string
    field :value, ProxyConf.Vault.EncryptedBinary

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(db_secret, attrs) do
    db_secret
    |> cast(attrs, [:cluster, :name, :value])
    |> validate_required([:cluster, :name, :value])
  end
end
