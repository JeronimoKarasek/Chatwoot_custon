#!/bin/bash
set -e

# Chatwoot entrypoint script for Docker
# Prepares the database and runs the application

echo "=========================================="
echo "🚀 Chatwoot Custom - Starting..."
echo "=========================================="

# Wait for database to be ready
echo "⏳ Waiting for database..."
until bundle exec rails db:version 2>/dev/null; do
  echo "   Database not ready, waiting..."
  sleep 2
done
echo "✅ Database is ready!"

# Run database preparations
echo "📊 Preparing database..."
bundle exec rails db:chatwoot_prepare || {
  echo "⚠️  Warning: Database preparation had issues, but continuing..."
}

echo "✅ Setup complete!"
echo "=========================================="

# Execute the main command
exec "$@"
