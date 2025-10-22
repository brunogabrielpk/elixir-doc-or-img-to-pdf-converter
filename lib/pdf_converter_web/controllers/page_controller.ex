defmodule PdfConverterWeb.PageController do
  use PdfConverterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
