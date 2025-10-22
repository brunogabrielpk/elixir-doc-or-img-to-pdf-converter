defmodule PdfConverter.Files.ConvertedFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "converted_files" do
    field :original_filename, :string
    field :original_extension, :string
    field :pdf_path, :string
    field :file_size, :integer
    field :conversion_duration_ms, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(converted_file, attrs) do
    converted_file
    |> cast(attrs, [
      :original_filename,
      :original_extension,
      :pdf_path,
      :file_size,
      :conversion_duration_ms
    ])
    |> validate_required([:original_filename, :original_extension, :pdf_path, :file_size])
  end
end
