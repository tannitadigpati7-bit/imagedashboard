# Creative Review Board

Weekly image-review dashboard for the creatives Tannita & Theerthi's team sends before the Tuesday WBR. Lives as a Claude artifact the whole team uses in the browser; this repo is the source of truth for `creative-board.html`.

**Live board:** https://claude.ai/code/artifact/4d45f818-755e-4c5b-a685-bb2861d5afd2
**Source:** `creative-board.html` in this folder — the file that is published as the artifact.

## What it does

- **Review board** — drag image files onto the board (several at once) or click "+ Add images"; drop a file onto an existing card to replace its image. Images are auto-compressed (max 1280px JPEG) before saving.
- **Reactions** — thumbs up / thumbs down per image, with counts on the buttons and a net-score chip.
- **Comments** — "What should change?" box under every image.
- **Requirements tab** — anyone types an ask; it queues as an open task with their name and date. Dev ticks the checkbox when done; it moves to Completed with who/when.
- **Weeks** — "+ New week" starts a fresh set each Tuesday; old weeks stay browsable in the sidebar.

## Identity & access

- Access = artifact sharing (share menu on the page). View-only viewers see everything but can't react.
- Identity inside the board = pick-your-name reviewer profiles (Dev, Tannita, Theerthi, Divya, Ashwini, Harish, Ruthrakesavan, Shashank, Shilpa; anyone can add themselves). Every reaction, comment and requirement is stamped with the profile name. Honor-system, not passworded; the artifact's version history records which account saved each change.

## How it saves (technical, for future sessions)

- Uses the artifact runtime capability (`window.claude.use("artifact")`). Shared state (people, weeks, images as data URIs, reactions, comments, requirements) lives in `data/state.json`, published from the page via the files form; falls back to full-HTML publish (state spliced into the `#seed` script block) when the files form is unavailable, e.g. while sharing is public. Newest `rev` wins at load.
- ~14 MB total budget; sidebar shows a storage meter. Clear old weeks' images when it fills.
- **Live sync fix (31 Aug 2026):** earlier versions only fetched `data/state.json` once at page load, so a reviewer's open tab never picked up anyone else's reactions/comments unless they hard-reloaded — you'd see your own changes instantly but not a teammate's. The page now polls `data/state.json` every 6s (and on tab focus) and merges in any revision newer than what's on screen, skipping the merge while a local edit is mid-publish so it can't get clobbered. A publish conflict also now triggers an immediate re-poll instead of just showing "Updated elsewhere…" and stopping there.
- **Editing the board later:** republish against the artifact URL, but the page saves a new version on every reaction — always read the live version first and build on it, or the publish will conflict. From a cloud session that needs `*.frame.claudeusercontent.com` on the network allowlist (Settings → Code → Network access). Never `force: true` without Dev's explicit say-so.

## WBR system integration

This board is meant to plug into the larger WBR system already being built. Once the live-sync fix is verified with the team, the plan is to embed/link this artifact (or its `creative-board.html`) into that system rather than keep it as a standalone link.
