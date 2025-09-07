defmodule Mdedit.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          content: String.t() | nil,
          slug: String.t() | nil,
          admin_token: String.t() | nil,
          expires_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "documents" do
    field :title, :string
    field :content, :string
    field :slug, :string
    field :admin_token, :string
    field :expires_at, :utc_datetime

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

  @doc """
  Changeset for creating a new document with admin token.
  """
  def create_changeset(document, attrs \\ %{}) do
    document
    |> cast(attrs, [:title, :content, :slug, :expires_at])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
    |> maybe_validate_slug()
    |> unique_constraint(:slug)
    |> maybe_put_slug()
    |> put_change(:admin_token, generate_admin_token())
    |> maybe_put_default_expiration()
  end

  @doc """
  Generates a secure admin token for document ownership.
  """
  def generate_admin_token do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64(padding: false)
  end

  @doc """
  Checks if the given admin token matches the document's admin token.
  For documents without admin tokens (legacy documents), no one has admin access.
  """
  def admin?(%__MODULE__{admin_token: nil}, _provided_token) do
    # Legacy documents without admin tokens - no admin access (can't be deleted)
    false
  end

  def admin?(%__MODULE__{admin_token: admin_token}, provided_token)
      when is_binary(provided_token) and is_binary(admin_token) do
    Plug.Crypto.secure_compare(admin_token, provided_token)
  end

  def admin?(_, _), do: false

  @doc """
  Checks if a document has expired.
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Returns expiration options with labels and durations.
  """
  def expiration_options do
    [
      {"1 day", {1, :day}},
      {"1 week", {1, :week}},
      {"1 month", {1, :month}},
      {"1 year", {1, :year}}
    ]
  end

  @doc """
  Calculates expiration datetime from duration tuple.
  """
  def calculate_expiration({amount, :day}), do: DateTime.add(DateTime.utc_now(), amount * 24 * 60 * 60, :second)
  def calculate_expiration({amount, :week}), do: DateTime.add(DateTime.utc_now(), amount * 7 * 24 * 60 * 60, :second)
  def calculate_expiration({amount, :month}), do: DateTime.add(DateTime.utc_now(), amount * 30 * 24 * 60 * 60, :second)
  def calculate_expiration({amount, :year}), do: DateTime.add(DateTime.utc_now(), amount * 365 * 24 * 60 * 60, :second)

  defp maybe_put_default_expiration(changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        # Default to 1 month if not specified
        default_expiration = calculate_expiration({1, :month})
        put_change(changeset, :expires_at, default_expiration)
      _expires_at ->
        changeset
    end
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
