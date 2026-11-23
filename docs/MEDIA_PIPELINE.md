# Media pipeline — target architecture

Decision log for the media delivery strategy. Source of truth for *why* the app is built this way.

## Recommended stack (confirmed direction)

| Layer | Provider | What it does |
|---|---|---|
| Backend, database, auth, realtime | **Supabase** | Auth (email/password, guest), Postgres (profiles/posts/reels/stories/follows/comments/messages/notifications/saved_posts), real-time messages + notifications, storage backend |
| Media delivery & CDN | **Cloudflare** | Global CDN for media delivery; edge caching; serves media to users fast worldwide. **R2** is the storage backend the CDN fronts (to be wired once Cloudflare credentials exist) |
| Image/video transformations | **Cloudinary** | Resize/crop avatars to small bitmap sizes (e.g. 128px avatars), image compression, video poster tiles, thumbnail generation |

**Key rule:** Supabase stays the database + auth + realtime brain. Cloudflare + Cloudinary take over **media serving** — they never become the data source of truth.

## What is wired today

`MediaService` (`lib/services/media_service.dart`) decides how media URLs are constructed, configured at build time via dart-define:

```bash
# Default (unchanged behaviour) — Supabase Storage public URLs
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# Cloudflare CDN
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=MEDIA_PROVIDER=cloudflare \
  --dart-define=CLOUDFLARE_CDN_BASE_URL=https://cdn.your-domain.co

# Cloudinary transformations
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=MEDIA_PROVIDER=cloudinary \
  --dart-define=CLOUDINARY_CLOUD_NAME=your-cloud-name
```

Behaviour:

- Absolute URLs already stored in the DB (`https://...`) are returned unchanged — existing rows remain valid.
- The config is read **once at build time** (default: `supabase`), so no per-request provider lookup.
- `MediaService.getAvatarUrl(...)` is the single entry point for avatar URLs — currently used implicitly (every avatar URL comes from the stored profile `avatar_url`); when the Cloudinary provider is active it produces `w_128,h_128,r_fill,c_thumb`-style transformations instead.

## What is NOT wired yet (honest scope)

- **Uploads stay in Supabase Storage** today — the app does not currently write or read media through Cloudflare R2. Migrating uploads to R2 (via a Cloudflare edge worker / R2 API from the app or a Cloudflare Worker function) is Phase 1 infra work once Cloudflare credentials exist.
- **Cloudinary transformations** exist as URL construction only — there is no server-side transformation pipeline yet. v1 uses Cloudinary URL transforms for avatars once avatars land in Cloudinary; for video thumbnails and compression this needs a worker/cron on the dashboard side, out of app-side scope here.
- **RLS and storage policy** — Supabase Storage public buckets are still the path. The media pipeline doc must not be mistaken for a RLS migration.

## Target (Phase 1+)

1. Media buckets in Cloudflare R2 (one per category: avatars, posts, reels, stories).
2. Cloudflare CDN in front of R2 (`cdn.your-domain.co`), with edge caching of public media and bypass-auth for public paths.
3. Avatar uploads go to Cloudinary; poster/thumbnail generation via Cloudinary or a Cloudflare Worker (from the original post/reel, not the app).
4. The app keeps working with today's `MEDIA_PROVIDER=supabase` default until Cloudflare credentials exist — a clean one-line change at build time.

## Why

- Supabase = the smallest correct backend: one place for auth, database, realtime.
- Cloudflare = global edge, CDN caching, and cheap/storage-efficient R2; independent of Supabase.
- Cloudinary = the right tool for image transformations (avatars, posters, thumbnails).

This is a media-delivery swap, not a data migration. The schema in `supabase/migrations/` does not change.
