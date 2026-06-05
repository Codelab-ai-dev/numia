#!/bin/sh
set -e

echo "Running database migrations..."
migrate -path /migrations -database "$DB_URL" up

echo "Starting API..."
exec /api
