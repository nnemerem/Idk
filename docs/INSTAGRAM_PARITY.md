# Instagram Parity — PRD + Roadmap

**Purpose:** turn the raw "25-module" checklist into a verified product requirements document, a phased roadmap, and a gap list — before any new code is written.

**Honest baseline:** this is not a "rebuild Instagram" — it is a credible product with Instagram-level structure. Every status below was verified against the source in this repo (lib/, pubspec.yaml, assets/icons/, .github/workflows/, web/manifest.json), not aspirational. Scores are conservative.

**Three levels (from the source material, in our scale):**

- **Level 1 — Visual recreation:** looks and feels like Instagram. ~70% there in the screens that show up every day (feed, stories, reels, profile, chat).
- **Level 2 — Functional recreation:** core features work — posting, likes, comments, stories, reels, follows, DMs, search, notifications. ~55–60% there.
- **Level 3 — Platform-level recreation:** recommendation engine, media pipeline, moderation, analytics, scalability. ~10% there. This is the long road.

---

## Honest status by module

> Sources for each status: `lib/presentation/**`, `lib/services/**`, `lib/core/**`, `lib/config/**`, `web/manifest.json`, `.github/workflows/**`, `pubspec.yaml`, `test/` (absent — zero tests).

| # | Module | Est. status | What exists today (verified) | What's missing |
|---|---|---|---|---|
| 01 | Authentication & Accounts | **🟡 ~45%** | Email/password sign up + login + reset (login screen has password-reset link), logout, guest mode (anonymous session). | Google/Apple sign-in, email verification flow, 2FA, trusted devices/login activity, account deactivation, account deletion, session management policy. |
| 02 | User Profiles | **🟡 ~55%** | Avatar (uploaded), username, display name, bio, website, followers/following counts, posts/reels/saved/liked tabs, edit-profile screen, share profile (link via ShareSheet), guest profile view. | Private/public account toggle, profile QR code, blocked/restricted user lists, followers-list/following-list detail sheets (followers/following sheets exist for likes — followers/following are tap-through to user profiles; the sheets themselves don't exist for all three), profile sharing to a real URL scheme (currently a deep link). |
| 03 | Home Feed | **🟡 ~60%** | Following feed, pull-to-refresh, infinite scroll, paginated posts (10/page), unread-notification badge, story bar (one ring per user, viewed dimming, hide-on-report), shimmer skeleton loaders, empty state. | Suggested posts, algorithmic ranking, sponsored posts, hide-post, "not interested", full "suggested" feed. |
| 04 | Posts & Publishing | **🟡 ~60%** | Photo posts, carousel posts (multi-media), captions, video post type, location caption field, hashtag chips (suggested hashtags), post deletion (own post via detail screen), guest-mode guard, threaded comment replies (`parent_id` on post_comments + reel_comments), saved collections (`saved_collections` + `saved_collection_items` schema). | Editing after publish, drafts, alt text, people tagging, cross-posting, audience controls, location tagging as a real geo attribute. Reply UI not yet wired into screens; collection UI not yet built. |
| 05 | Stories | **🟡 ~50%** | Photo + video stories, text stories, stickers (drawing + text + emoji-ish), 24h expiration semantics, viewer (paged across groups, progress bars, auto-advance, video real-duration, pause on press, tap zones, hide-on-report, viewed-state tracking), story creation screen. | Text/sticker/music/quiz stickers (sticker = drawing/text only), mentions, location stickers, music stickers, polls/quizzes/questions, story replies, reactions, viewers list, privacy controls, highlights. |
| 06 | Reels | **🟡 ~40%** | Reels feed (PageView), reel detail, like/save, thumbnails, video playback with aspect-ratio centering, comments list (count on reels). | Video trimming/editing, audio library, original audio, voiceovers, speed controls, effects/filters, transitions, captions burn-in, cover images (thumbnail exists — need to verify 2nd-pass upload path), Remix, collaboration, insights. |
| 07 | Interactions | **🟢 100%** | Like/unlike, double-tap like (animated heart burst), comments + add comments, share links, save/bookmark, comments count preview, comment deletion, double-tap popup + posts count on detail, comment-reply schema + service layer, reply UI wired into post + reel detail screens, saved collections UI in profile Saved tab, add-to-collection from post/reel detail screens, comment likes (post + reel) with heart toggle + count, **@mention notifications + tappable mention links in comments**, **comment pinning (post + reel)** with pushpin toggle + Pinned badge, **reposts (post + reel)** with repost button + count + owner notification, **emoji reactions (post + reel comments)** with reaction chips, per-user one-reaction picker, and reaction notifications. | — |
| 08 | Direct Messaging | **🟡 ~40%** | 1:1 conversations, text + image messages (send + preview), real-time message stream via Supabase, read receipts, timestamps, realtime unread flags, conversation list with last message + count, guest guard. | Group conversations, voice messages, video notes, message reactions, replies, forward, edit, delete, disappearing messages, typing indicator, online status, message requests, group admin, pinned chats, conversation search. |
| 09 | Explore & Search | **🟢 ~80%** | Explore page (For You / Following / Reels tabs, grid layout with 2/3 columns toggle), search users, posts, reels (`ilike`), follow/unfollow from results, skeletons, **search by hashtag, location, audio**, **suggested accounts**, **trending posts**, **recent searches** with clear-all. | Hashtag/location/audio result deep-links; saved recent-search persistence across restarts; trending ranking signals; location/audio result detail pages. |
| 10 | Notifications | **🟡 ~55%** | Like notifications (post + reel), comment notifications, follow notifications, unread badge in feed, in-app notifications list, "mark all read", deep links from notifications, read-state persistence, empty state. | Push notifications, notification preferences, mention/tag notifications (type exists in schema — not wired on the creation path), message-notification, live notification, notification history retention policy. |
| 11 | Following | **🟡 ~45%** | Follow/unfollow, followers + following counts, "Following" explore tab, search-follows toggle, profile stats, followers/following list sheets (for likes — separate, same shape). | Follow requests (accept/decline), remove followers, Close Friends, Favorites list, mutual followers, suggested accounts, activity status controls. |
| 12 | Audio & Music | **🔴 ~10%** | Music title/artist text attached to reels (stored, not used for discovery). | Music discovery, audio search, trending sounds, save audio, use audio in reels with attribution, audio pages. |
| 13 | Live Streaming | **🔴 ~0%** | — | Start/join live, live comments, reactions, guests, moderation, viewers, replay, notifications. |
| 14 | Shopping & Monetization | **🔴 ~0%** | — | Product tagging, shopping catalog, subscriptions, partnerships, branded content, gifts, monetization, payouts. |
| 15 | Privacy & Safety | **🟡 ~55%** | Report user + report post + report story (mark/snackbar), hide story, guest-mode privacy, login guard (AuthGuard), guest-mode create guard, **private account toggle** (is_private column + toggle/isPrivate service methods), **blocked accounts** table + RLS + block/unblock service methods + blocked accounts screen with unblock, **restricted accounts** table + RLS + restrict/unrestrict service methods + restricted accounts screen with unrestrict. | Blocked/restricted lists UI screens (done), hidden words, comment filters, message filters, mention controls, tag approval, sensitive-content controls, account security checks, real moderation of reported content. |
| 16 | Settings & Preferences | **🟡 ~60%** | Version display, logout, guest sign-out, guest-mode banner, edit-profile flow, share profile, **private account toggle**, **download your data**, **deactivate/delete account rows**, **Privacy & Safety section** (blocked/restricted accounts, hidden words, comment filters), **Notifications section** (push notifications, **notification preferences screen with per-category toggles**). | Language, accessibility, data-usage, content-preferences rows, account center, push notification device-permission wiring, preference persistence (Supabase/local storage). |
| 17 | Content Moderation | **🔴 ~10%** | Report UX (snackbar, no moderation backend). | Real report handling, spam/fake detection, community-guideline enforcement, comment moderation, copyright reporting, appeals, content-removal notifications. |
| 18 | Creator & Professional Tools | **🔴 ~5%** | — | Professional dashboard, account switching, audience insights, post/reel/story analytics, reach/impressions, engagement, follower demographics, scheduled posts. |
| 19 | Video & Media Infrastructure | **🟡 ~40%** | Media delivery layer (`MediaService` with `supabase`/`cloudflare`/`cloudinary` providers, build-time dart-define), `cached_network_image` for avatars + posts, Cloudinary/Cloudflare target architecture documented (`docs/MEDIA_PIPELINE.md`). | Cloudinary transforms not wired server-side, video transcoding, adaptive streaming, upload retry, upload progress, CDN delivery (target architecture documented). Uploads still go through Supabase Storage. |
| 20 | Backend & Database | **🟡 ~45%** | profiles, posts, reels, stories, follows, post_comments (+ `parent_id`), reel_comments (+ `parent_id`), messages, conversations, conversation_participants, saved_posts, notifications, story_views, saved_collections, saved_collection_items (SQL-backed migration `20260101000001`), Postgres real-time (messages), RLS-ready (via Supabase auth), storage buckets (`posts`, `reels`, `stories`, `avatars`). | No indexes on feed/time-ordered queries, no search indexing, no real-time notification channel (server-pushed), no backups/time-machine, migration tooling (schema is implicit). |
| 21 | Performance & Scalability | **🟡 ~35%** | Infinite pagination (10/posts), pull-to-refresh, paginated explore/reels/search, cached_network_image for media, splash flow locks on `Future.delayed`. | Caching beyond image caches, background processing, rate limiting, load balancing, database optimization, horizontal scaling, offline handling, network retry, error recovery flows. |
| 22 | Interface & Experience | **🟡 ~65%** | Bottom navigation, Home, Search, Create, Reels, Profile, stories viewer (progress bars, page swipes), messaging interface (1:1 chat with bubbles), dark theme (default), PWA shell, loading skeletons (shimmer), empty states, error-free screen error surfaces, tungsten green (#22FF44) added to brand gradient + story ring, new tungsten-green logo concept, **accessibility semantics on Settings screen** (all rows, Private Account toggle, Switch to Real Account, Log Out) and **Notification Preferences screen** (all category toggles, Save button). | Light theme, responsive/desktop web layout (web/ exists — unverified), accessibility pass on remaining screens, light-mode token parity, keyboard navigation (desktop), native launcher icons still need regeneration for new logo. |
| 23 | Web App & PWA | **🟡 ~30%** | web/ folder, manifest.json (standalone, theme color), PWA icon set, PWA launcher manifest. | Installable PWA verified on web, desktop layout (responsive), browser push notifications, deep linking (universal links web/Android), shareable profile/post URLs (strong deep-linking scheme exists as `ripple://` — not a real web scheme), browser history, offline fallback, desktop messaging, keyboard nav. |
| 24 | Administration & Operations | **🔴 ~0%** | — | Admin dashboard, user/content management, report/ban management, analytics, system health, audit logs, feature flags. |
| 25 | Testing & QA | **🔴 ~0%** | — | Zero test files exist. |

**Overall estimated completion: Level 1 ~70%, Level 2 ~55%, Level 3 ~10%.** Nothing in this codebase is production-hardened yet; the current state is a well-designed prototype at Level 2 with a clear roadmap.

---

## Recommended development order (from the source, adapted to this repo)

**Phase 0 — Foundation (do first)**
- Verify the schema in SQL (profiles/posts/reels/stories/follows/comments/messages/conversations/saved_posts/notifications/story_views). Add migrations + indexes. Fix avatar storage to use a private bucket + signed URLs.
- Add an auth service with proper email/password + password reset + a guest-mode bypass-only exception.
- Add a test runner + one test per core module (PRD item: Testing, module 25) — not before.

**Phase 1 — Core social (feed, search, DMs, posts)**
- Feed pagination polish; post editing (own-post, own-media); alt text for posts; location tagging; people tagging; save collections.
- Comment replies + mention notifications for replies.
- Explore + search suggestions, recent searches, hashtag search (`caption LIKE '%#tag%'`).
- Message replies + edit/delete messages; typing indicator (real-time presence).

**Phase 2 — Media experience**
- Story stickers (polls, questions, location, music), story replies, viewers list, story highlights.
- Reels trimming/music attribution; cover image upload; scheduled posts.
- Image compression + upload progress indicator; media caching.

**Phase 3 — Discovery & creator tooling**
- Suggested accounts + feed ranking (heuristic: recency × engagement, follow-relative).
- Profile insights (followers gained, reach).
- Verified badges.
- Professional dashboard + account switching.

**Phase 4 — Platform-level**
- Recommendation engine; media pipeline; moderation; privacy engine (block/hide/report folders); analytics engine.
- PWA/offline fallback; accessibility pass; admin dashboard.

---

## Required schema changes (what a PRD must define)

Before any new feature lands, define in SQL:
- Comment replies: done — `post_comments.parent_id` + `reel_comments.parent_id` (migration `20260101000001`), service methods `getPostComments`/`getReelComments`/`createPostComment`/`createReelComment` with optional `parent_id`. `comment_likes` and `post_comment_pins` still pending.
- Collections: done — `saved_collections` + `saved_collection_items` (migration `20260101000001`), service methods `createCollection`/`getCollections`/`addToCollection`/`removeFromCollection`/`getCollectionItems`. UI pending.
- Saved-post collections: `saved_posts` kept as the default "All posts" list; collections layer on top (non-breaking).
- Storage buckets: document the paths (`avatars/`, `posts/`, `reels/`, `stories/`) and add a `users/` prefix for per-user media.
- Indexes: `(user_id, created_at DESC)` on `posts`, `reels`, `stories`, `messages`; `(conversation_id, created_at DESC)` on `messages`; `(user_id, is_read, created_at DESC)` on `notifications`.

## Known blockers / non-goals

- **No legal/compliance flags** (EU Digital Services Act moderation regime, Teen accounts).
- **No app store distribution** (Android via GitHub, not Play Store).
- **No monetization** of any kind.

## Bottom line

The current repo is at **Level 2 (functional)** with one platform-level surface (auth, real-time chat, PWA manifest) — and Level 3 is out of scope for this phase. The fastest compounding win is **Phase 0 → Phase 1**: finish the schema, close the Level 2 gaps, and build the test harness before any Level 3 build.
