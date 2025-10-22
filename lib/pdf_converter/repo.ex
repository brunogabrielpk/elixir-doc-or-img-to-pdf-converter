defmodule PdfConverter.Repo do
  use Ecto.Repo,
    otp_app: :pdf_converter,
    adapter: Ecto.Adapters.SQLite3
end
