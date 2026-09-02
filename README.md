# Creative Review Board

Weekly image-review dashboard for the creatives admin team sends before the Tuesday WBR. Runs as a plain web page on GitHub Pages; all feedback lives in a Supabase database. Meant to plug into the larger WBR system later by reading the same tables.

**Live board:** https://tannitadigpati7-bit.github.io/imagedashboard/creative-board.html
**Source:** `creative-board.html` — one static file, no build step. Loads `@supabase/supabase-js` from jsDelivr.

## Architecture

```
Browser (any device)  ──HTTPS──►  Supabase (Auth + Postgres + Storage)  ◄── WBR system reads the same tables
   creative-board.html                      free tier
```

- **Page:** `creative-board.html`, served free by GitHub Pages. Config (Supabase URL + anon key) is a block at the top of the file.
- **Login:** email + password (Supabase Auth). Accounts are created by an admin in the Supabase dashboard and handed out; no email sending involved. Session persists and auto-refreshes on the device. On first login the person links their email to a `people` row ("claim your name"); after that every rating/comment is stamped with it.
- **Visibility (enforced in the database, not just the UI):**
  - Reviewers can read/write **only their own** rows in `ratings` and `comments`.
  - **Admins** (`people.is_admin = true` — Tannita & Theerthi) read everyone's ratings and comments.
  - `images`, `weeks`, `requests` are visible to every signed-in user.
  - Enforced by RLS policies using `current_person()` / `is_admin()` (see `supabase-setup.sql`).
- **Data:** `people`, `weeks`, `images`, `ratings`, `comments`, `requests`. Each rating/comment is its own row (`ratings` upserts on `(image_id, person_id)`), so concurrent reviewers never overwrite each other.
- **Images:** uploaded to the `creatives` Storage bucket, compressed client-side to max 1280px JPEG; only the URL + byte size are stored in `images`.
- **Sync:** re-fetches every 5s (and on focus), redraws on change, skips the redraw while someone is typing.

## What it does

- **Review board** — drag creatives on (several at once) or "+ Add images"; drop a file on a card to replace it.
- **Full-image viewer** — click any thumbnail: zoom (buttons / scroll wheel / `+` `-` keys), pan by dragging when zoomed, `1:1` to reset, `Esc` to close.
- **Ratings** — 1–5 stars per image. Click your current star again to clear it. Admins see the average, count, and a chip per person; reviewers see only their own.
- **Comments** — a general comment box under each image, **or** click a spot in the full-image viewer to pin a comment to that point. Pinned comments show a numbered marker in the viewer and a 📍 in the card list. You must open the full image before the comment box unlocks.
- **Requests tab** — anyone types an ask; it queues with their name and date. Tick it off when done; moves to Completed with who/when.
- **Weeks** — "+ New week" starts a fresh set; old weeks stay browsable in the sidebar.
- **Storage bar** — bottom-left, image MB used against the 1 GB free-tier cap.

## First-time setup (fresh project)

1. Create a free Supabase project at https://supabase.com.
2. SQL Editor → New query → paste all of `supabase-setup.sql` → Run.
3. **Authentication → Providers → Email**: turn **OFF** "Confirm email" (so dashboard-created accounts work right away). Leave the Email provider itself enabled. Custom SMTP is not needed.
4. **Authentication → Users → Add user** — for each teammate: email + a password + tick **Auto Confirm User**. Hand out the passwords.
5. Settings → API → copy **Project URL** and **anon public** key into the `CONFIG` block near the top of `creative-board.html`, commit, push.
6. Repo → Settings → Pages → Source: Deploy from a branch, `main`, `/ (root)`.
7. Share the live URL. Each teammate signs in with their email + password, then picks their name once.

## Migrating an existing v2 project (thumbs / no login)

Run `migrate-v3.sql` in the SQL Editor, then do steps 3–4 above (turn off "Confirm email", create the user accounts). No data is lost.

## Admins

Set by `people.is_admin`. Seeded for `tannita@bathla.com` and `theerthi@bathla.com`. To add/remove an admin:

```sql
update public.people set is_admin = true  where email = 'someone@bathla.com';
update public.people set is_admin = false where email = 'someone@bathla.com';
```

## Editing later

Edit `creative-board.html` and push — GitHub Pages redeploys automatically. The database is the source of truth; the file is only the UI.

## WBR system integration

The WBR system reads the same Supabase tables (directly, or via its REST API with a service key — the RLS above targets `authenticated` end users, so server-side reads use the service role and see everything). `ratings` = star scores per creative per week; `comments` = feedback (with optional `x`/`y` pin coords); `requests` = the creative-request backlog.

## Notes / possible upgrades

- Login emails go through Supabase's built-in sender (low rate limit). For heavy bursts, add a free SMTP provider (e.g. Resend) under Auth → SMTP Settings.
- Cross-device sign-in works because auth uses the implicit flow (tokens in the URL hash), so the magic link can be opened in any browser.
- Live push instead of 5s polling: Supabase Realtime subscriptions.
- `requests` has unused `in_progress` / `assigned_to` columns; UI only toggles open/done.
- Pinch-to-zoom on touch isn't wired yet; the zoom buttons work on mobile.
