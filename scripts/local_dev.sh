#!/bin/bash
# Local development helper script
# Usage: ./scripts/local_dev.sh

set -e

echo "Ripple local development setup"
echo "================================"

read -p "Supabase URL (https://xxx.supabase.co): " SUPABASE_URL
read -p "Supabase Anon Key: " SUPABASE_ANON_KEY

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "Both values are required."
    exit 1
fi

echo ""
echo "Getting dependencies..."
flutter pub get

echo ""
echo "Starting app with dart-define injection..."
flutter run --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
