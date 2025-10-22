# PDF Converter - Podman/Docker Deployment Guide

This guide covers deployment using Podman Compose (also works with Docker Compose).

## Prerequisites

- Podman and podman-compose installed
- Git (to clone the repository)

## Quick Start

### Local Development (Database Only)

```fish
# Clone the repository
git clone <repository-url>
cd pdf_converter

# Start PostgreSQL database only
podman-compose -f docker-compose.dev.yml up -d

# Check logs
podman-compose -f docker-compose.dev.yml logs -f

# The database will automatically:
# - Create the pdf_converter_dev database
# - Create the pdf_converter database (for compatibility)
# - Be ready on localhost:5432

# Now run the app locally
mix deps.get
mix ecto.migrate
mix phx.server
```

### Full Production Deployment

```fish
# 1. Generate a secure secret key
set -Ux SECRET_KEY_BASE (openssl rand -base64 48)
set -Ux PHX_HOST "localhost"  # or your domain

# 2. Build and start everything (app + database)
podman-compose up -d --build

# 3. Watch the logs
podman-compose logs -f

# The application will automatically:
# - Wait for PostgreSQL to be ready
# - Create the database if it doesn't exist
# - Run all migrations
# - Start the Phoenix server on port 4000
```

The application will be available at `http://localhost:4000`

## Podman Compose Commands

### Starting Services

```fish
# Start in foreground (see logs)
podman-compose up

# Start in background (detached)
podman-compose up -d

# Build images and start
podman-compose up -d --build

# Start only specific service
podman-compose up -d postgres
```

### Stopping Services

```fish
# Stop all services
podman-compose down

# Stop and remove volumes (⚠️ deletes all data)
podman-compose down -v

# Stop specific service
podman-compose stop app
```

### Viewing Logs

```fish
# All services
podman-compose logs -f

# Specific service
podman-compose logs -f app
podman-compose logs -f postgres

# Last 100 lines
podman-compose logs --tail=100 app
```

### Service Management

```fish
# Restart services
podman-compose restart

# Restart specific service
podman-compose restart app

# Check service status
podman-compose ps

# Execute command in running container
podman-compose exec app /app/bin/pdf_converter remote
podman-compose exec postgres psql -U pdf_converter -d pdf_converter_prod
```

### Rebuilding

```fish
# Rebuild a specific service
podman-compose build app

# Rebuild without cache
podman-compose build --no-cache app

# Rebuild and restart
podman-compose up -d --build app
```

## Environment Variables

### Required for Production

```fish
# Generate and set these before deploying
set -Ux SECRET_KEY_BASE (openssl rand -base64 48)
set -Ux PHX_HOST "yourdomain.com"
```

### Optional Configuration

```fish
# Database configuration (if not using defaults)
set -Ux DATABASE_URL "ecto://user:pass@host:5432/database"
set -Ux POOL_SIZE "10"

# View current settings
env | grep SECRET_KEY_BASE
env | grep PHX_HOST
```

### Using .env File

Create a `.env` file in the project root:

```bash
SECRET_KEY_BASE=your-secret-key-here
PHX_HOST=yourdomain.com
```

Podman Compose will automatically load this file.

## Database Management

### Access PostgreSQL Shell

```fish
# Development database
podman-compose -f docker-compose.dev.yml exec postgres psql -U pdf_converter -d pdf_converter_dev

# Production database
podman-compose exec postgres psql -U pdf_converter -d pdf_converter_prod
```

### Backup Database

```fish
# Create backup
set timestamp (date +%Y%m%d_%H%M%S)
podman-compose exec postgres pg_dump -U pdf_converter pdf_converter_prod > backup_$timestamp.sql

# Verify backup
ls -lh backup_*.sql
```

### Restore Database

```fish
# Restore from backup
podman-compose exec -T postgres psql -U pdf_converter pdf_converter_prod < backup_20241022_123456.sql
```

### Reset Database (⚠️ Destructive)

```fish
# Stop services and remove volumes
podman-compose down -v

# Start fresh
podman-compose up -d
```

## Troubleshooting

### Database Connection Issues

```fish
# Check if PostgreSQL is ready
podman-compose exec postgres pg_isready -U pdf_converter

# Check database logs
podman-compose logs postgres

# Verify database exists
podman-compose exec postgres psql -U pdf_converter -l
```

### Application Won't Start

```fish
# Check application logs
podman-compose logs app

# Restart the app service
podman-compose restart app

# Rebuild if code changed
podman-compose up -d --build app
```

### Port Already in Use

```fish
# Check what's using port 4000
sudo lsof -i :4000

# Or change the port in docker-compose.yml
# Change "4000:4000" to "8080:4000"
# Then access at http://localhost:8080
```

### Volume Permission Issues

```fish
# Check volume permissions
podman volume inspect pdf_converter_uploads_data

# Remove and recreate volumes
podman-compose down -v
podman-compose up -d
```

## Development Workflow

### Making Code Changes

```fish
# For local development (database in container, app on host)
podman-compose -f docker-compose.dev.yml up -d
mix phx.server  # Edit code and it hot-reloads

# For containerized development (rebuild on changes)
podman-compose up -d --build app
```

### Running Migrations

```fish
# If app is in container
podman-compose exec app /app/bin/pdf_converter eval "PdfConverter.Release.migrate"

# If app is running locally
mix ecto.migrate
```

### Accessing IEx Console

```fish
# If app is in container
podman-compose exec app /app/bin/pdf_converter remote

# If app is running locally
iex -S mix phx.server
```

## Production Best Practices

1. **Always set SECRET_KEY_BASE**
   ```fish
   set -Ux SECRET_KEY_BASE (openssl rand -base64 48)
   ```

2. **Change database password** in `docker-compose.yml`

3. **Set up reverse proxy** (nginx, Caddy, Traefik) for SSL/TLS

4. **Regular backups**
   ```fish
   # Add to crontab
   0 2 * * * cd /path/to/pdf_converter && podman-compose exec postgres pg_dump -U pdf_converter pdf_converter_prod > backup_$(date +\%Y\%m\%d).sql
   ```

5. **Monitor logs**
   ```fish
   # Set up log rotation
   podman-compose logs --no-log-prefix > app.log
   ```

6. **Resource limits** - Add to docker-compose.yml:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2'
         memory: 2G
   ```

## File Structure

```
pdf_converter/
├── Dockerfile                    # Application container definition
├── docker-compose.yml            # Production: app + database
├── docker-compose.dev.yml        # Development: database only
├── entrypoint.sh                 # Container startup script
├── docker/
│   └── postgres/
│       └── init-db.sh           # PostgreSQL initialization
└── lib/
    └── pdf_converter/
        └── release.ex           # Database creation & migrations
```

## Support

For issues or questions:
- Check logs: `podman-compose logs -f`
- Verify services: `podman-compose ps`
- Database health: `podman-compose exec postgres pg_isready`
