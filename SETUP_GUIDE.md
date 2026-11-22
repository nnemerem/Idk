# Ripple - Quick Setup & GitHub Actions Build Guide

## 🚀 One-Time Setup (5 minutes)

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com) → New Project
2. Wait for database to provision (~2 min)
3. Go to **Project Settings → API** → Copy:
   - `Project URL` → `SUPABASE_URL`
   - `anon/public` key → `SUPABASE_ANON_KEY`
4. Go to **Authentication → Providers** → Enable **Anonymous sign-ins** (for Guest Mode)

### 2. Add GitHub Secrets
In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value |
|-------------|-------|
| `SUPABASE_URL` | `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

### 3. Run Database Migrations
In Supabase Dashboard → **SQL Editor** → Run the migrations from `README.md` (or run `supabase db push` if using CLI)

---

## 📱 Get Your Build

### Option A: Automatic on Tag (Recommended)
```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```
→ Check **Actions tab** → Wait for green check → **Download artifacts** or **GitHub Release**

### Option B: Manual Trigger
1. Go to **Actions → Build Android** → **Run workflow**
2. Select branch → **Run workflow**
3. Wait ~5 min → **Download APK/AAB from artifacts**

### Option C: Local Build (if you install Flutter)
```bash
flutter pub get
flutter build apk --release  # Android
# flutter build ipa --release  # iOS (macOS only)
```

---

## 🔧 Local Development

```bash
# 1. Copy config template
cp lib/config/supabase_config.dart lib/config/supabase_config.local.dart

# 2. Edit with YOUR credentials
# (This file is gitignored)

# 3. Run
flutter run
```

---

## 📦 What You Get

| Artifact | Use Case |
|----------|----------|
| `app-arm64-v8a-release.apk` | Modern Android (64-bit) |
| `app-armeabi-v7a-release.apk` | Older Android (32-bit) |
| `app-x86_64-release.apk` | Android emulators |
| `app-release.aab` | **Google Play Store upload** |
| `Ripple.ipa` | iOS Ad Hoc / TestFlight |

---

## 🐛 Troubleshooting

| Issue | Fix |
|-------|-----|
| `SUPABASE_URL not set` | Add secrets in GitHub repo settings |
| `Anonymous auth failed` | Enable Anonymous provider in Supabase Auth settings |
| `Build fails on pub get` | Check `pubspec.yaml` for version conflicts |
| `iOS build fails` | Requires Apple Developer account for signing |

---

## 🎯 Next Steps After Install

1. Open app → **"Check It Out"** (Guest Mode - browse only)
2. Tap heart/comment/save → **Sign Up prompt appears**
3. Create account → Full access (post, reel, DM, follow)
4. Profile → **"Switch to Real Account"** to exit guest mode

---

**Need help?** Check the Actions logs or create an issue!