defmodule Mdedit.Documents do
  @moduledoc """
  The Documents context.
  """

  import Ecto.Query, warn: false
  alias Mdedit.Repo
  alias Mdedit.Documents.Document

  @type document_attrs :: %{optional(atom()) => any()}

  @doc """
  Gets a document by slug if it exists and hasn't expired.

  ## Examples

      iex> get_document_by_slug("my-document")
      %Document{}

      iex> get_document_by_slug("nonexistent")
      nil

      iex> get_document_by_slug("expired-document")
      nil

  """
  def get_document_by_slug(slug) when is_binary(slug) do
    case Repo.get_by(Document, slug: slug) do
      nil -> nil
      document ->
        if Document.expired?(document) do
          nil
        else
          document
        end
    end
  end

  @doc """
  Gets a document by slug, raising if not found.

  ## Examples

      iex> get_document_by_slug!("my-document")
      %Document{}

      iex> get_document_by_slug!("nonexistent")
      ** (Ecto.NoResultsError)

  """
  def get_document_by_slug!(slug) when is_binary(slug) do
    Repo.get_by!(Document, slug: slug)
  end

  @doc """
  Creates a document.

  ## Examples

      iex> create_document(%{field: value})
      {:ok, %Document{}}

      iex> create_document(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_document(attrs \\ %{}) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a document with admin token for ownership.

  ## Examples

      iex> create_document_with_admin(%{title: "My Document"})
      {:ok, %Document{}}

  """
  def create_document_with_admin(attrs \\ %{}) do
    %Document{}
    |> Document.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a document.

  ## Examples

      iex> update_document(document, %{field: new_value})
      {:ok, %Document{}}

      iex> update_document(document, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_document(%Document{} = document, attrs) do
    document
    |> Document.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a document.

  ## Examples

      iex> delete_document(document)
      {:ok, %Document{}}

      iex> delete_document(document)
      {:error, %Ecto.Changeset{}}

  """
  def delete_document(%Document{} = document) do
    Repo.delete(document)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking document changes.

  ## Examples

      iex> change_document(document)
      %Ecto.Changeset{data: %Document{}}

  """
  def change_document(%Document{} = document, attrs \\ %{}) do
    Document.changeset(document, attrs)
  end

  @doc """
  Checks if the provided admin token grants admin access to the document.

  ## Examples

      iex> admin?(document, "valid_token")
      true

      iex> admin?(document, "invalid_token")
      false

  """
  @spec admin?(Document.t(), String.t() | nil) :: boolean()
  def admin?(%Document{} = document, admin_token) do
    Document.admin?(document, admin_token)
  end

  @doc """
  Converts markdown content to HTML.

  ## Examples

      iex> markdown_to_html("# Hello")
      "<h1>Hello</h1>"

  """
  @spec markdown_to_html(binary()) :: binary()
  def markdown_to_html(content) when is_binary(content) do
    options = %Earmark.Options{
      gfm: true,
      breaks: true,
      code_class_prefix: "language-"
    }

    case Earmark.as_html(content, options) do
      {:ok, html, _warnings} -> html
      {:error, _html, _errors} -> "<p>Error parsing markdown</p>"
    end
  end

  def markdown_to_html(_), do: ""
end
