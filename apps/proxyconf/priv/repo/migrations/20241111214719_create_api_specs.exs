defmodule Proxyconf.Repo.Migrations.CreateApiSpecs do
  use Ecto.Migration

  def change do
    create table(:api_specs) do
      add(:api_id, :string)
      add(:cluster, :string)
      add(:listener_address, :string)
      add(:listener_port, :integer)
      add(:vhost, :string)
      add(:data, :binary)

      timestamps(type: :utc_datetime)
    end
  end
end
