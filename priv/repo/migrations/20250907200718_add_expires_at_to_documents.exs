defmodule Mdedit.Repo.Migrations.AddExpiresAtToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :expires_at, :utc_datetime
    end

    # Add index for efficient expiration queries
    create index(:documents, [:expires_at])
  end
end
