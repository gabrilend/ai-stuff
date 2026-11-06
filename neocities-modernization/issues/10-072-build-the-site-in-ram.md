# 10-072: Build the Site in RAM

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Storage change
- **Status**: Open
- **Created**: 2026-10-20
- **Related**: 10-054 (moved regenerable caches to RAM to spare the disk; the
  same goal for the caches, and the reason they went back to disk), 8-059
  (the project's two RAM folders and the `tmp/` links into them), 10-057
  (pipeline memory budget)

## The owner's words (2026-10-20)

> should be in RAM.

Said of the built pages, after learning that a full build rewrites about
4.7 GB of them on disk, and about the RAM folder being emptied at logout:
"It's fine." The site is uploaded right after it is built, so losing it at
logout costs a rebuild, nothing more.

## Current Behavior

**Built (2026-10-20), waiting on the one-time move and the owner's first
build.** `scripts/ensure-site-in-ram` makes `output` a link into
`tmp/shared-memory/site/`; inside it, each folder the build does not remake
links back to a disk home: `media` (the pictures) to `assets/site-media/`,
and `model-evaluation` (written by the model comparison, not the build) to
`assets/model-evaluation/`. `run.sh` calls it on every run, right after the
RAM folders are set up. The owner's `output/` is still a real folder, so the
next `run.sh` stops with a message until the one-time
`scripts/ensure-site-in-ram --migrate` has been run: it moves the two kept
folders to their disk homes and deletes the rest, which the next build
remakes (owner, 2026-10-20: "delete it now then"; checked first: every
other file in `output/` was rewritten by the 2026-10-07 build, and the build
record is rewritten every run).

Readers that had to change: the page check and the stale-file tool now
search with `find -H` (plain `find` does not go into a starting folder that
is a link, so the page check would have counted zero pages); deploy refuses
a missing or empty site before it contacts the live site, where it used to
fetch the live listing first. `.gitignore` names the link. Picture copying,
the download zip and the `--force` page cleanup work through the link
unchanged. Tested by `scripts/ensure-site-in-ram.test.sh` in a scratch
project (see its `.info.md`).

Left before closing: the owner runs `--migrate` and a full build, the
whole-site check passes on it, and one deploy works. The download zip can then live directly in the RAM site
instead of behind its own link (step 5); it works as it is.

Before this issue: the built site, `output/`, was an ordinary folder on the
disk. Every full build rewrote it:

| Part | Rewritten |
|---|---|
| similar and different pages (about 52,000 files) | every build |
| word pages, the word cloud, chronological pages and text export, the source browser | every build |
| `media/` (the pictures, about 1.5 GB) | only when a picture changes |

Re-rendering with the same inputs gives byte-identical pages, so most of
those writes replace a file with the same bytes. Measure with
`du -sh output output/media`.

One file already lives in RAM: the download zip is finished in
`tmp/shared-memory/` and `output/` holds only a link to it
(`scripts/build-download-zip`). Deploy (`scripts/deploy-to-neocities`)
follows links, and stops with a "rebuild first" message if the RAM copy is
gone. That is the pattern this issue extends to the whole site.

About 32 places in `run.sh`, `src/`, `libs/` and `scripts/` name the
`output/` folder directly, so moving it by changing each of them would be a
large, error-prone edit.

The RAM folder (`/dev/shm`, a 16 GB tmpfs on this machine) is emptied when
the owner's last login session ends (elogind's `RemoveIPC`), not only at
reboot. The owner has chosen to leave that setting alone.

## Intended Behavior

- `output/` is a link into the project's RAM folder
  (`tmp/shared-memory/output/`), so every program that writes "output/..."
  writes into RAM without being changed.
- `output/media/` is a link back to a folder on disk, because pictures
  rarely change and copying 1.5 GB into RAM after every logout is wasted
  work. Pictures are still copied only when they change.
- A build that finds the RAM folder empty (after a logout) recreates
  `output/` there and builds normally. Nothing on disk is lost, because
  nothing but pictures was ever kept there.
- Deploy, the page check and anything else that reads `output/` and finds
  the link pointing at nothing stops with a message saying to rebuild,
  never a silent empty upload (a deploy with pruning against an empty
  folder would delete the live site).

## Suggested Implementation Steps

1. Add one shared "make sure the site folder exists" step (in the helper
   that already makes `tmp/shared-memory/`), which creates the RAM folder,
   the `output/` link and the `output/media/` link to disk. `run.sh` calls
   it before the first stage that writes pages.
2. Move the current `output/` contents: pictures to the disk folder that
   `output/media/` will point at, everything else is rebuilt. Keep the old
   folder until one build and one deploy have worked from the new layout.
3. Check every reader of `output/` for a missing-site message: deploy, the
   page check, the download zip, the phase demos.
4. `.gitignore` lists `output/`; the trailing slash matches only a folder,
   and git sees a link as a file, so add `output` (no slash) or the link
   shows up as untracked.
5. Re-check the zip: its link sits inside `output/`, which is now in RAM
   too, so it can live there directly.
6. Tests: a scratch project folder where the RAM folder is emptied between
   two builds (simulating a logout) — the second build must succeed and
   deploy's file listing must find the pages; a dangling `output/` must
   make deploy refuse.
7. Measure: run a full build and count bytes written to the disk before and
   after (`/proc/<pid>/io` write_bytes, or the disk's own counters).

## Answered Questions (2026-10-20)

- Pictures stay on disk (owner: "yes").
- "Only write a page whose content changed": not built. Once pages live in
  RAM it saves no disk wear. The owner asked whether `--force` already does
  it; it does not, they answer different questions. `--force` skips each
  stage's "are my outputs already newer than my inputs?" check, so the
  whole stage runs again. Write-if-changed would act inside a stage that
  runs anyway, page by page, skipping a write whose bytes are the same.
- The owner starts every rebuild; testing here uses a scratch project.
