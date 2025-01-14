defmodule ProxyConf.Api.DbSpec do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_specs" do
    field(:api_id, :string)
    field(:cluster, :string)
    field(:listener_address, :string)
    field(:listener_port, :integer)
    field(:vhost, :string)
    field(:data, ProxyConf.Vault.EncryptedBinary)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(db_spec, attrs) do
    db_spec
    |> cast(attrs, [:cluster, :api_id, :listener_address, :listener_port, :vhost, :data])
    |> validate_required([:cluster, :api_id, :listener_address, :listener_port, :vhost, :data])
  end
end
