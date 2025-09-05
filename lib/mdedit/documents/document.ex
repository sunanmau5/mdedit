defmodule Mdedit.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          content: String.t() | nil,
          slug: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "documents" do
    field :title, :string
    field :content, :string
    field :slug, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [:title, :content, :slug])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
    |> maybe_validate_slug()
    |> unique_constraint(:slug)
    |> maybe_put_slug()
  end

  defp maybe_validate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        changeset

      _slug ->
        validate_format(changeset, :slug, ~r/^[a-zA-Z0-9\-_]+$/,
          message: "must contain only letters, numbers, hyphens, and underscores"
        )
    end
  end

  defp maybe_put_slug(%Ecto.Changeset{valid?: true, changes: %{title: title}} = changeset) do
    case get_field(changeset, :slug) do
      nil -> put_change(changeset, :slug, slugify(title))
      _slug -> changeset
    end
  end

  defp maybe_put_slug(changeset), do: changeset

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
