#!/bin/bash
set -e

echo "Creating additional databases..."

# Create pdf_converter database (without _dev suffix) if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE pdf_converter'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pdf_converter')\gexec
EOSQL

echo "Database setup complete!"
