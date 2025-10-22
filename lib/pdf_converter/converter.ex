defmodule PdfConverter.Converter do
  @moduledoc """
  Module for converting various file formats to PDF using LibreOffice.
  """

  require Logger

  @upload_dir "priv/static/uploads"
  @output_dir "priv/static/converted"

  @doc """
  Converts a file to PDF format.
  Supports: doc, docx, txt, and common image formats (jpg, jpeg, png, gif, bmp)
  """
  def convert_to_pdf(upload_path, original_filename) do
    require Logger
    Logger.info("Converting file: #{original_filename} from #{upload_path}")

    start_time = System.monotonic_time(:millisecond)

    # Ensure output directory exists
    File.mkdir_p!(@output_dir)

    extension = Path.extname(original_filename) |> String.downcase()
    base_name = Path.basename(original_filename, extension)
    timestamp = :os.system_time(:millisecond)
    output_filename = "#{base_name}_#{timestamp}.pdf"
    output_path = Path.join(@output_dir, output_filename)

    Logger.info("Extension: #{extension}, Output path: #{output_path}")

    result =
      case extension do
        ext when ext in [".doc", ".docx", ".txt", ".odt", ".rtf"] ->
          convert_document(upload_path, output_path)

        ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff"] ->
          convert_image(upload_path, output_path)

        ".pdf" ->
          # If already PDF, just copy it
          File.cp!(upload_path, output_path)
          {:ok, output_path}

        _ ->
          {:error, "Unsupported file format: #{extension}"}
      end

    case result do
      {:ok, pdf_path} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        Logger.info("Conversion successful: #{pdf_path}")

        {:ok,
         %{
           pdf_path: pdf_path,
           original_filename: original_filename,
           original_extension: String.trim_leading(extension, "."),
           file_size: File.stat!(pdf_path).size,
           conversion_duration_ms: duration
         }}

      error ->
        Logger.error("Conversion failed: #{inspect(error)}")
        error
    end
  end

  defp convert_document(input_path, output_path) do
    require Logger
    output_dir = Path.dirname(output_path)

    Logger.info("Running LibreOffice conversion: #{input_path} -> #{output_dir}")

    # LibreOffice command to convert to PDF
    case System.cmd(
           "libreoffice",
           [
             "--headless",
             "--convert-to",
             "pdf",
             "--outdir",
             output_dir,
             input_path
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        Logger.info("LibreOffice output: #{output}")
        # LibreOffice outputs with the original basename, need to find and rename
        input_basename = Path.basename(input_path, Path.extname(input_path))
        libreoffice_output = Path.join(output_dir, "#{input_basename}.pdf")

        Logger.info("Looking for LibreOffice output at: #{libreoffice_output}")

        if File.exists?(libreoffice_output) do
          File.rename!(libreoffice_output, output_path)
          {:ok, output_path}
        else
          {:error, "PDF file not created by LibreOffice at #{libreoffice_output}"}
        end

      {output, code} ->
        Logger.error("LibreOffice failed with code #{code}: #{output}")
        {:error, "LibreOffice conversion failed: #{output}"}
    end
  rescue
    e in ErlangError ->
      Logger.error("LibreOffice not found: #{inspect(e)}")
      {:error, "LibreOffice not found. Please install LibreOffice: #{inspect(e)}"}
  end

  defp convert_image(input_path, output_path) do
    # For images, we'll also use LibreOffice's conversion capability
    # Alternatively, you could use ImageMagick if available
    convert_document(input_path, output_path)
  end

  @doc """
  Creates a ZIP file containing multiple PDF files.
  """
  def create_zip(pdf_paths, zip_filename \\ "converted_files.zip") do
    zip_path = Path.join(@output_dir, zip_filename)

    # Read all files into memory and create zip with binary data
    # This avoids issues with spaces in filenames
    files_to_zip =
      Enum.map(pdf_paths, fn path ->
        filename = Path.basename(path)

        case File.read(path) do
          {:ok, content} ->
            {String.to_charlist(filename), content}

          {:error, reason} ->
            Logger.error("Failed to read file #{path}: #{inspect(reason)}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case :zip.create(String.to_charlist(zip_path), files_to_zip, [:memory]) do
      {:ok, {_filename, zip_binary}} ->
        File.write!(zip_path, zip_binary)
        {:ok, zip_path}

      error ->
        {:error, "Failed to create ZIP: #{inspect(error)}"}
    end
  end

  @doc """
  Gets the upload directory path.
  """
  def upload_dir, do: @upload_dir

  @doc """
  Gets the output directory path.
  """
  def output_dir, do: @output_dir

  @doc """
  Ensures upload and output directories exist.
  """
  def ensure_directories do
    File.mkdir_p!(@upload_dir)
    File.mkdir_p!(@output_dir)
  end
end
