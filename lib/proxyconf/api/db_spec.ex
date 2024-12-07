defmodule ProxyConf.Api.DbSpec do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_specs" do
    field :api_id, :string
    field :cluster, :string
    field :data, ProxyConf.Vault.EncryptedBinary

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(db_spec, attrs) do
    db_spec
    |> cast(attrs, [:cluster, :api_id, :data])
    |> validate_required([:cluster, :api_id, :data])
  end
end
