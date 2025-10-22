defmodule PdfConverter.Files do
  @moduledoc """
  The Files context for managing converted files.
  """

  import Ecto.Query, warn: false
  alias PdfConverter.Repo
  alias PdfConverter.Files.ConvertedFile

  @doc """
  Returns the list of the last 5 converted files.
  """
  def list_recent_converted_files(limit \\ 5) do
    ConvertedFile
    |> order_by([f], desc: f.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single converted file.
  """
  def get_converted_file!(id), do: Repo.get!(ConvertedFile, id)

  @doc """
  Creates a converted file record.
  """
  def create_converted_file(attrs \\ %{}) do
    %ConvertedFile{}
    |> ConvertedFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a converted file record and its PDF file.
  """
  def delete_converted_file(%ConvertedFile{} = converted_file) do
    # Delete the physical PDF file
    File.rm(converted_file.pdf_path)
    Repo.delete(converted_file)
  end
end
