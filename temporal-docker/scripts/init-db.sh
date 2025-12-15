#!/bin/bash
set -e

# This script initializes the Temporal databases

echo "Creating temporal_visibility database..."

# Create the visibility database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE temporal_visibility;
    GRANT ALL PRIVILEGES ON DATABASE temporal_visibility TO temporal;
EOSQL

echo "Temporal databases initialized successfully!"
