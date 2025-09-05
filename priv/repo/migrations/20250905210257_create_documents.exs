defmodule Mdedit.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :title, :string
      add :content, :text
      add :slug, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:documents, [:slug])
  end
end
