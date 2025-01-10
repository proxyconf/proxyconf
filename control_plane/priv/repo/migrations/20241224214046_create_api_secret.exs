defmodule Proxyconf.Repo.Migrations.CreateApiSecret do
  use Ecto.Migration

  def change do
    create table(:api_secret) do
      add(:cluster, :string)
      add(:name, :string)
      add(:value, :binary)

      timestamps(type: :utc_datetime)
    end
  end
end
