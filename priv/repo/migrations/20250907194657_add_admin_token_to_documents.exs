defmodule Mdedit.Repo.Migrations.AddAdminTokenToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :admin_token, :string
    end

    # For existing documents without admin tokens, we'll leave them as nil
    # This means they remain accessible to everyone (legacy behavior)
    # New documents will automatically get admin tokens
  end
end
