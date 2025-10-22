# PDF Converter

A modern, real-time web application built with Phoenix LiveView for converting various document and image formats to PDF. Features drag-and-drop file uploads, batch conversion, and download management with conversion history tracking.

## Features

- **Multi-Format Support**: Convert documents and images to PDF format
  - Documents: DOC, DOCX, TXT, ODT, RTF
  - Images: JPG, JPEG, PNG, GIF, BMP, TIFF
  - PDF passthrough support
- **Batch Processing**: Upload and convert up to 10 files simultaneously (max 10MB per file)
- **Real-Time Updates**: Phoenix LiveView provides instant feedback and progress tracking
- **Drag & Drop Interface**: Modern, intuitive file upload experience
- **Download Options**: 
  - Download individual PDFs
  - Bulk download as ZIP archive
- **Conversion History**: Track recent conversions with metadata
  - Original filename and format
  - File size
  - Conversion duration
  - Timestamp
- **Database Persistence**: SQLite-backed storage for conversion records

## Technology Stack

- **Framework**: Phoenix 1.8.1 with LiveView 1.1.0
- **Language**: Elixir ~> 1.15
- **Database**: SQLite3 with Ecto
- **UI**: TailwindCSS with Heroicons
- **Conversion Engine**: LibreOffice (headless mode)
- **Web Server**: Bandit 1.5

## Prerequisites

Before running this application, ensure you have the following installed:

- **Elixir** 1.15 or later ([Installation Guide](https://elixir-lang.org/install.html))
- **Erlang/OTP** (typically installed with Elixir)
- **LibreOffice** (required for document/image conversion)
  - Ubuntu/Debian: `sudo apt-get install libreoffice`
  - macOS: `brew install libreoffice`
  - Arch Linux: `sudo pacman -S libreoffice-fresh`
- **Node.js** (for asset compilation)

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd pdf_converter
   ```

2. **Install dependencies**
   ```bash
   mix setup
   ```
   This command will:
   - Install Elixir dependencies
   - Create and migrate the database
   - Install and setup assets (TailwindCSS, esbuild)
   - Build assets

3. **Verify LibreOffice installation**
   ```bash
   libreoffice --version
   ```

## Usage

### Starting the Server

Start the Phoenix server:

```bash
mix phx.server
```

Or start it inside IEx for interactive development:

```bash
iex -S mix phx.server
```

The application will be available at [`http://localhost:4000`](http://localhost:4000)

### Converting Files

1. Navigate to `http://localhost:4000`
2. Click the upload area or drag and drop files (up to 10 files)
3. Click "Convert to PDF" button
4. Download individual PDFs or all files as a ZIP archive
5. View recent conversions in the history section

## Development

### Available Mix Commands

```bash
# Setup project (install deps, create DB, setup assets)
mix setup

# Run tests
mix test

# Database commands
mix ecto.create        # Create database
mix ecto.migrate       # Run migrations
mix ecto.reset         # Drop, create, and migrate database
mix ecto.drop          # Drop database

# Asset commands
mix assets.setup       # Install asset dependencies
mix assets.build       # Build assets for development
mix assets.deploy      # Build and minify assets for production

# Pre-commit checks (compile, format, test)
mix precommit
```

### Project Structure

```
lib/
├── pdf_converter/
│   ├── application.ex           # OTP application
│   ├── converter.ex             # Core conversion logic with LibreOffice
│   ├── files.ex                 # Files context for DB operations
│   ├── files/
│   │   └── converted_file.ex    # ConvertedFile schema
│   ├── repo.ex                  # Ecto repository
│   └── mailer.ex                # Email functionality
├── pdf_converter_web/
│   ├── components/              # Reusable UI components
│   ├── controllers/
│   │   ├── download_controller.ex  # File download handler
│   │   ├── error_html.ex
│   │   └── error_json.ex
│   ├── live/
│   │   └── converter_live.ex    # Main LiveView for conversion UI
│   ├── endpoint.ex              # Phoenix endpoint
│   ├── router.ex                # Route definitions
│   ├── telemetry.ex             # Metrics and monitoring
│   └── gettext.ex               # Internationalization
priv/
├── repo/migrations/             # Database migrations
├── static/
│   ├── uploads/                 # Temporary upload directory
│   └── converted/               # Converted PDF storage
```

### Key Modules

- **PdfConverter.Converter** (`lib/pdf_converter/converter.ex:1`): Handles file conversion using LibreOffice, manages upload/output directories, and creates ZIP archives
- **PdfConverter.Files** (`lib/pdf_converter/files.ex:1`): Context module for managing converted file records in the database
- **PdfConverterWeb.ConverterLive** (`lib/pdf_converter_web/live/converter_live.ex:1`): LiveView component managing the upload UI, conversion process, and real-time updates
- **PdfConverterWeb.DownloadController** (`lib/pdf_converter_web/controllers/download_controller.ex:1`): Handles single and batch PDF downloads

## Configuration

### Environment Configuration

The application supports different configurations per environment:

- `config/dev.exs` - Development settings
- `config/test.exs` - Test environment
- `config/prod.exs` - Production settings
- `config/runtime.exs` - Runtime configuration

### File Upload Limits

Upload constraints are configured in `lib/pdf_converter_web/live/converter_live.ex:16`:

```elixir
allow_upload(:files,
  accept: ~w(.doc .docx .txt .pdf .jpg .jpeg .png .gif .bmp .odt .rtf .tiff),
  max_entries: 10,           # Maximum number of files
  max_file_size: 10_000_000  # 10MB per file
)
```

### Storage Directories

- Uploads: `priv/static/uploads/`
- Converted PDFs: `priv/static/converted/`

These directories are automatically created when the application starts.

## Production Deployment

### Building for Production

```bash
# Prepare assets
mix assets.deploy

# Set production environment variables
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export DATABASE_PATH=/path/to/production/database.db
export PHX_HOST=yourdomain.com

# Run database migrations
MIX_ENV=prod mix ecto.migrate

# Start the application
MIX_ENV=prod mix phx.server
```

### Production Checklist

- [ ] Set `SECRET_KEY_BASE` environment variable
- [ ] Configure `PHX_HOST` for your domain
- [ ] Set `DATABASE_PATH` for SQLite database location
- [ ] Ensure LibreOffice is installed on production server
- [ ] Set appropriate file permissions for upload/converted directories
- [ ] Configure reverse proxy (nginx/Apache) if needed
- [ ] Set up SSL/TLS certificates
- [ ] Configure firewall rules

For detailed deployment information, see the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Testing

Run the test suite:

```bash
mix test
```

The test environment uses an in-memory SQLite database that's created and migrated automatically.

## Troubleshooting

### LibreOffice Not Found

If you see errors about LibreOffice not being found:

1. Verify installation: `which libreoffice`
2. Ensure it's in your PATH
3. Try running manually: `libreoffice --headless --version`

### File Upload Issues

- Check file size limits (default: 10MB per file)
- Verify file format is supported
- Ensure upload directory has write permissions

### Database Errors

```bash
# Reset the database
mix ecto.reset
```

## License

This project is available as open source.

## Learn More

### Phoenix Framework

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

### Phoenix LiveView

- Docs: https://hexdocs.pm/phoenix_live_view
- Source: https://github.com/phoenixframework/phoenix_live_view

### Elixir

- Official website: https://elixir-lang.org/
- Documentation: https://hexdocs.pm/elixir
