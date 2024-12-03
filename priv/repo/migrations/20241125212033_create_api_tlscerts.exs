defmodule Proxyconf.Repo.Migrations.CreateApiTlscerts do
  use Ecto.Migration

  def change do
    create table(:api_tlscerts) do
      add :cluster, :string
      add :key_pem, :binary
      add :cert_pem, :binary

      timestamps(type: :utc_datetime)
    end
  end
end
