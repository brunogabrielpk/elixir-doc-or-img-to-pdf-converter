defmodule PdfConverterWeb.ConverterLive do
  use PdfConverterWeb, :live_view

  alias PdfConverter.{Converter, Files}

  @impl true
  def mount(_params, _session, socket) do
    Converter.ensure_directories()

    socket =
      socket
      |> assign(:uploaded_files, [])
      |> assign(:converted_files, [])
      |> assign(:recent_files, Files.list_recent_converted_files())
      |> assign(:converting, false)
      |> assign(:error_message, nil)
      |> allow_upload(:files,
        accept: ~w(.doc .docx .txt .pdf .jpg .jpeg .png .gif .bmp .odt .rtf .tiff),
        max_entries: 10,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("convert", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :files, fn %{path: path}, entry ->
        dest_path = Path.join(Converter.upload_dir(), "#{entry.uuid}_#{entry.client_name}")
        File.cp!(path, dest_path)
        {:ok, {dest_path, entry.client_name}}
      end)

    if length(uploaded_files) == 0 do
      {:noreply, assign(socket, error_message: "Please select files to convert")}
    else
      socket = assign(socket, converting: true, error_message: nil)

      # Convert files
      results =
        Enum.map(uploaded_files, fn {path, filename} ->
          case Converter.convert_to_pdf(path, filename) do
            {:ok, conversion_data} ->
              # Save to database
              {:ok, record} = Files.create_converted_file(conversion_data)
              # Clean up uploaded file
              File.rm(path)
              {:ok, record}

            {:error, reason} ->
              File.rm(path)
              {:error, reason}
          end
        end)

      # Separate successes and failures
      {successes, failures} =
        Enum.split_with(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      converted_records = Enum.map(successes, fn {:ok, record} -> record end)

      socket =
        socket
        |> assign(:converted_files, converted_records)
        |> assign(:converting, false)
        |> assign(:recent_files, Files.list_recent_converted_files())

      socket =
        if length(failures) > 0 do
          error_messages = Enum.map(failures, fn {:error, reason} -> reason end)

          assign(socket,
            error_message: "Some files failed to convert: #{Enum.join(error_messages, ", ")}"
          )
        else
          socket
        end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("download-single", %{"id" => id}, socket) do
    file = Files.get_converted_file!(String.to_integer(id))

    {:noreply,
     socket
     |> push_event("download", %{url: "/download/#{file.id}"})}
  end

  @impl true
  def handle_event("download-all", _params, socket) do
    if length(socket.assigns.converted_files) > 0 do
      {:noreply,
       socket
       |> push_event("download", %{
         url:
           "/download/batch/#{Enum.map(socket.assigns.converted_files, & &1.id) |> Enum.join(",")}"
       })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, converted_files: [], error_message: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 py-8">
      <h1 class="text-4xl font-bold text-center mb-8 text-gray-800">PDF Converter</h1>

      <div class="bg-white rounded-lg shadow-lg p-6 mb-8">
        <h2 class="text-2xl font-semibold mb-4 text-gray-700">Upload Files</h2>
        <p class="text-gray-600 mb-4">
          Supported formats: DOC, DOCX, TXT, PDF, JPG, JPEG, PNG, GIF, BMP, ODT, RTF, TIFF
        </p>

        <form phx-submit="convert" phx-change="validate" class="space-y-4">
          <div
            class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-blue-500 transition-colors"
            phx-drop-target={@uploads.files.ref}
          >
            <.live_file_input upload={@uploads.files} class="hidden" />
            <label for={@uploads.files.ref} class="cursor-pointer">
              <svg
                class="mx-auto h-12 w-12 text-gray-400"
                stroke="currentColor"
                fill="none"
                viewBox="0 0 48 48"
              >
                <path
                  d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              <p class="mt-2 text-sm text-gray-600">
                Click to select files or drag and drop
              </p>
              <p class="text-xs text-gray-500 mt-1">
                Up to 10 files, max 10MB each
              </p>
            </label>
          </div>

          <%= if @error_message do %>
            <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
              {@error_message}
            </div>
          <% end %>

          <div :if={length(@uploads.files.entries) > 0} class="space-y-2">
            <%= for entry <- @uploads.files.entries do %>
              <div class="flex items-center justify-between bg-gray-50 p-3 rounded">
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-900">{entry.client_name}</p>
                  <div class="mt-1 bg-gray-200 rounded-full h-2">
                    <div class="bg-blue-600 h-2 rounded-full" style={"width: #{entry.progress}%"}>
                    </div>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="ml-4 text-red-600 hover:text-red-800"
                >
                  &times;
                </button>
              </div>
            <% end %>
          </div>

          <button
            type="submit"
            disabled={@converting || length(@uploads.files.entries) == 0}
            class="w-full bg-blue-600 text-white py-3 px-4 rounded-lg font-semibold hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
          >
            <%= if @converting do %>
              Converting...
            <% else %>
              Convert to PDF
            <% end %>
          </button>
        </form>
      </div>

      <%= if length(@converted_files) > 0 do %>
        <div class="bg-white rounded-lg shadow-lg p-6 mb-8">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-2xl font-semibold text-gray-700">Converted Files</h2>
            <div class="space-x-2">
              <%= if length(@converted_files) > 1 do %>
                <button
                  phx-click="download-all"
                  class="bg-green-600 text-white py-2 px-4 rounded-lg hover:bg-green-700 transition-colors"
                >
                  Download All as ZIP
                </button>
              <% end %>
              <button
                phx-click="clear"
                class="bg-gray-600 text-white py-2 px-4 rounded-lg hover:bg-gray-700 transition-colors"
              >
                Clear
              </button>
            </div>
          </div>

          <div class="space-y-2">
            <%= for file <- @converted_files do %>
              <div class="flex items-center justify-between bg-gray-50 p-4 rounded">
                <div>
                  <p class="font-medium text-gray-900">{file.original_filename}</p>
                  <p class="text-sm text-gray-600">
                    Size: {format_bytes(file.file_size)} |
                    Converted in: {file.conversion_duration_ms}ms
                  </p>
                </div>
                <a
                  href={"/download/#{file.id}"}
                  class="bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700 transition-colors"
                  download
                >
                  Download PDF
                </a>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if length(@recent_files) > 0 do %>
        <div class="bg-white rounded-lg shadow-lg p-6">
          <h2 class="text-2xl font-semibold mb-4 text-gray-700">Recent Conversions</h2>
          <div class="space-y-2">
            <%= for file <- @recent_files do %>
              <div class="flex items-center justify-between bg-gray-50 p-4 rounded">
                <div>
                  <p class="font-medium text-gray-900">{file.original_filename}</p>
                  <p class="text-sm text-gray-600">
                    Converted: {Calendar.strftime(file.inserted_at, "%Y-%m-%d %H:%M:%S")} |
                    Size: {format_bytes(file.file_size)}
                  </p>
                </div>
                <a
                  href={"/download/#{file.id}"}
                  class="bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700 transition-colors"
                  download
                >
                  Download
                </a>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end
end
