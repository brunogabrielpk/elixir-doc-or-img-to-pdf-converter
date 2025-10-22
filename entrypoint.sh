#!/bin/bash
set -e

echo "=== PDF Converter Application Starting ==="

# Extract database connection info from DATABASE_URL
DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\(.*\):.*/\1/p')
DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
DB_USER=$(echo $DATABASE_URL | sed -n 's/.*:\/\/\(.*\):.*/\1/p')
DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\(.*\)$/\1/p')

echo "Database Configuration:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"

# Wait for PostgreSQL to be ready
echo ""
echo "Waiting for PostgreSQL to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while ! pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "ERROR: PostgreSQL did not become ready in time"
    exit 1
  fi
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES - PostgreSQL is unavailable, waiting..."
  sleep 2
done

echo "✓ PostgreSQL is ready!"

# Create database if it doesn't exist
echo ""
echo "Ensuring database exists..."
/app/bin/pdf_converter eval "PdfConverter.Release.create"

# Run migrations
echo ""
echo "Running database migrations..."
/app/bin/pdf_converter eval "PdfConverter.Release.migrate"

echo ""
echo "✓ Database setup complete!"
echo ""
echo "=== Starting Phoenix Server ==="
echo ""

# Start the application
exec /app/bin/pdf_converter start
