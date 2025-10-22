defmodule PdfConverterWeb.DownloadController do
  use PdfConverterWeb, :controller

  alias PdfConverter.{Files, Converter}

  def download_single(conn, %{"id" => id}) do
    file = Files.get_converted_file!(id)

    if File.exists?(file.pdf_path) do
      pdf_filename =
        "#{Path.basename(file.original_filename, Path.extname(file.original_filename))}.pdf"

      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{pdf_filename}\"")
      |> send_file(200, file.pdf_path)
    else
      conn
      |> put_flash(:error, "File not found")
      |> redirect(to: "/")
    end
  end

  def download_batch(conn, %{"ids" => ids_string}) do
    require Logger
    Logger.info("download_batch called with ids: #{ids_string}")

    ids =
      ids_string
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    Logger.info("Parsed IDs: #{inspect(ids)}")

    files = Enum.map(ids, &Files.get_converted_file!/1)
    pdf_paths = Enum.map(files, & &1.pdf_path)

    Logger.info("PDF paths: #{inspect(pdf_paths)}")

    timestamp = :os.system_time(:millisecond)
    zip_filename = "converted_files_#{timestamp}.zip"

    case Converter.create_zip(pdf_paths, zip_filename) do
      {:ok, zip_path} ->
        Logger.info("ZIP created successfully at: #{zip_path}")
        Logger.info("ZIP file exists? #{File.exists?(zip_path)}")

        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header("content-disposition", "attachment; filename=\"converted_files.zip\"")
        |> send_file(200, zip_path)
        |> then(fn conn ->
          # Clean up zip file after sending
          Task.start(fn ->
            Process.sleep(1000)
            File.rm(zip_path)
          end)

          conn
        end)

      {:error, reason} ->
        Logger.error("Failed to create ZIP: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to create ZIP file")
        |> redirect(to: "/")
    end
  end
end
