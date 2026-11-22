# Ripple — Setup Guide

## 1. Create a Supabase project
1. Go to supabase.com → New Project
2. Wait for the database to provision
3. Project Settings → API → copy:
   - Project URL → `SUPABASE_URL`
   - `anon` public key → `SUPABASE_ANON_KEY`
4. Authentication → Providers → enable **Anonymous sign-ins** (guest mode)

## 2. Apply the schema
Supabase dashboard → SQL Editor → run `supabase/migrations/20240101000000_initial_schema.sql`
Then create these public storage buckets in dashboard → Storage: `avatars`, `posts`, `reels`, `stories`

## 3. Run the app
```bash
./scripts/local_dev.sh
```
Or directly:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## 4. Build
```bash
flutter build apk --release        # Android
flutter build ios                  # iOS (macOS only)
flutter build web --release        # Web (build/web)
flutter build windows              # Windows (build/windows)
flutter build linux                # Linux (build/linux)
flutter build macos                # macOS (macOS only)
```

## Troubleshooting
- `SUPABASE_URL not set` → pass the two dart-defines or edit scripts/local_dev.sh
- `Anonymous auth failed` → enable Anonymous provider in Supabase Auth settings
- `Build fails on pub get` → check Flutter SDK version (3.22+)

## Next steps
1. Open the app → "Check It Out" (guest mode, browse only)
2. Tap like/comment/save → "Sign In Required" dialog
3. Create an account → full access
4. Profile → "Switch to Real Account" to exit guest mode
