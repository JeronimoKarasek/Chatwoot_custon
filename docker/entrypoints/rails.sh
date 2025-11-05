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
if bundle exec rails db:chatwoot_prepare; then
  echo "✅ Database preparation successful!"
else
  EXIT_CODE=$?
  echo "⚠️  Warning: Database preparation failed with exit code ${EXIT_CODE}"
  echo "   This might be expected on first run or if database already initialized."
  echo "   Application will attempt to start anyway..."
fi

echo "✅ Setup complete!"
echo "=========================================="

# Execute the main command
exec "$@"
