defmodule PdfConverter.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :pdf_converter

  require Logger

  def create do
    load_app()

    for repo <- repos() do
      adapter = repo.__adapter__()

      case adapter.storage_up(repo.config()) do
        :ok ->
          Logger.info("Database created successfully for #{inspect(repo)}")

        {:error, :already_up} ->
          Logger.info("Database already exists for #{inspect(repo)}")

        {:error, term} ->
          Logger.error("Failed to create database for #{inspect(repo)}: #{inspect(term)}")
          {:error, term}
      end
    end
  end

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    Logger.info("Migrations completed successfully")
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
