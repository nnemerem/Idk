#!/bin/bash
# Local development helper script
# Usage: ./scripts/local_dev.sh

set -e

echo "🎨 Ripple Local Development Setup"
echo "================================="

CONFIG_FILE="lib/config/supabase_config.dart"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# Check if already configured
if grep -q "your-project.supabase.co" "$CONFIG_FILE"; then
    echo ""
    echo "📝 Config needs your Supabase credentials!"
    echo ""
    echo "Get them from: https://supabase.com/dashboard/project/_/settings/api"
    echo ""
    read -p "Enter Supabase URL (https://xxx.supabase.co): " SUPABASE_URL
    read -p "Enter Supabase Anon Key: " SUPABASE_ANON_KEY

    if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
        echo "❌ Both values required!"
        exit 1
    fi

    # Update config file
    sed -i.bak "s|https://your-project.supabase.co|$SUPABASE_URL|" "$CONFIG_FILE"
    sed -i.bak "s|your-anon-key-here|$SUPABASE_ANON_KEY|" "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.bak"

    echo "✅ Config updated!"
else
    echo "✅ Config already has credentials"
fi

echo ""
echo "📦 Getting dependencies..."
flutter pub get

echo ""
echo "🚀 Starting app..."
flutter run