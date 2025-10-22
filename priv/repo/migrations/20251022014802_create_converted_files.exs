defmodule PdfConverter.Repo.Migrations.CreateConvertedFiles do
  use Ecto.Migration

  def change do
    create table(:converted_files) do
      add :original_filename, :string, null: false
      add :original_extension, :string, null: false
      add :pdf_path, :string, null: false
      add :file_size, :integer, null: false
      add :conversion_duration_ms, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:converted_files, [:inserted_at])
  end
end
