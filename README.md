# Creative Review Board

Weekly image-review dashboard for the creatives Tannita & Theerthi's team sends before the Tuesday WBR. Runs as a plain web page on GitHub Pages; all feedback lives in a Supabase database. Meant to plug into the larger WBR system later by reading the same tables.

**Live board:** https://tannitadigpati7-bit.github.io/imagedashboard/creative-board.html
**Source:** `creative-board.html` — one static file, no build step.

## Architecture

```
Browser (any device)  ──HTTPS──►  Supabase (Postgres + Storage)  ◄── WBR system reads the same tables
   creative-board.html                 free tier
```

- **Page:** `creative-board.html`, served free by GitHub Pages from this repo. Config (Supabase URL + anon key) is a block at the top of the file.
- **Data:** six Postgres tables — `people`, `weeks`, `images`, `reactions`, `comments`, `requests`. Each reaction/comment is its own row (`INSERT ... ON CONFLICT` for reactions), so simultaneous clicks from different reviewers can't overwrite each other.
- **Images:** uploaded from the page to a public Supabase Storage bucket (`creatives`), compressed client-side to max 1280px JPEG. Only the URL is stored in `images`. No size cap on the board.
- **Sync:** the page re-fetches every 5s (and on tab focus) and redraws when something changed. It skips the redraw while a reviewer is typing so it can't yank the cursor.
- **Identity:** pick-your-name reviewer profiles stored per device (`localStorage`), stamped on every row. Honor-system, not passworded.

## What it does

- **Review board** — drag creatives onto the board (several at once) or "+ Add images"; drop a file on an existing card to replace it.
- **Reactions** — thumbs up / thumbs down per image, counts on the buttons, net-score chip, and chips showing who reacted which way.
- **Comments** — "What should change?" box under every image.
- **Requests tab** — anyone types an ask; it queues with their name and date. Tick the checkbox when the creative is done; it moves to Completed with who/when.
- **Weeks** — "+ New week" starts a fresh set each Tuesday; old weeks stay browsable in the sidebar.

## First-time setup

1. **Supabase project** — create a free one at https://supabase.com.
2. **Run the schema** — Supabase → SQL Editor → New query → paste all of `supabase-setup.sql` → Run. (Safe to re-run.)
3. **Wire the page** — Supabase → Settings → API. Copy **Project URL** and the **anon public** key into the `CONFIG` block near the top of `creative-board.html`, commit, push.
4. **Turn on GitHub Pages** — repo → Settings → Pages → Source: `Deploy from a branch`, branch `main`, folder `/ (root)`. Wait ~1 min.
5. Share `https://tannitadigpati7-bit.github.io/imagedashboard/creative-board.html` with the team. No accounts needed to react or comment.

The anon key is designed to be public — the row-level rules in `supabase-setup.sql` are what limit access (read/write those six tables only, nothing else in the project).

## Editing later

Just edit `creative-board.html` and push — GitHub Pages redeploys automatically. There's no artifact/publish dance and no "read the live version first" — the database is the source of truth, the file is only the UI.

## WBR system integration

The WBR system reads the same Supabase tables directly (or via its REST API). Nothing to export or migrate. `reactions` gives you the vote tally per creative per week; `requests` is the creative-request backlog.

## Notes / possible upgrades

- Live push instead of 5s polling: Supabase Realtime subscriptions on the six tables.
- Verified identity: swap the name-picker for Supabase anonymous auth or a shared passcode.
- The `requests` table already has `in_progress` and `assigned_to` columns; the UI currently only toggles open/done.
