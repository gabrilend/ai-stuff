# 10-068: The rmail Mailbox Feeds the Notes Directory Without Being Extracted As Notes

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: High (tooling files are currently being published as poems)
- **Type**: Feature + input hygiene
- **Status**: IN PROGRESS — built and tested; open questions below are unanswered.
- **Created**: 2026-09-22
- **Related**: 10-026 (sources + external sync config), 10-053 (excluding content),
  6-031 (poem exclusion tombstones)

## Summary

`/home/ritz/notes/` is the notes source. Inside it lives `rmail/`, a mailbox for
the rmail daemon (`/home/ritz/programs/r-mail/`): a program that receives
messages over the network and writes each one as a plain file into
`rmail/inbox/`. It is the "send a note from my phone" route.

Two halves:

1. **Inbound (lives outside this repository).** When a message lands in the
   mailbox inbox, a hook copies it into `/home/ritz/notes/` as an ordinary note,
   confirms the copy is byte-identical, and only then deletes the inbox file.
2. **Extraction (this repository).** The mailbox directory itself is machinery:
   a `config` file, a `contacts` file holding shared secrets, shell hooks, state
   JSON. None of it is writing and none of it may reach the site.

## Current Behavior

- **Before this issue:** the notes extractor walked every file under the notes
  directory recursively, so `rmail/contacts` and `rmail/inbox/lan-ip-changed`
  were extracted as notes poems (they appeared in
  `input/notes/files/poems.json`). The sync copied the whole mailbox into
  `input/notes/rmail/`, which is also uploaded.
- **Now:**
  - The notes directory entry in `config.lua` carries a list of excluded
    subdirectories (`{ "rmail" }`).
  - The source-config reader passes that list through to both consumers.
  - The external sync hands each entry to rsync as an anchored exclude, refuses
    to run if a listed subdirectory does not exist in the source (a stale entry
    is a configuration error, same rule as 10-053), and deletes any copy left in
    `input/` by syncs made before the exclusion existed.
  - The notes extractor prunes the same subdirectories from its file walk, so
    even a stale copy in `input/` or a ZIP-extracted source cannot leak.
  - The mailbox's `on_receive` hook is a Lua script that moves each received
    message into the notes directory (details below). The mailbox `config`
    points at it. The running daemon read its hook paths at startup, so it
    uses the new hook only after it is restarted.
  - `scripts/notes-tooling-exclusion.test.sh` passes (11 checks). The hook was
    tested by hand against a scratch notes folder: normal move with the
    sender's timestamp kept, refusal on a name collision (message stays in the
    inbox, error logged), a name containing a quote and a space.
  - The copy of the mailbox already in `input/notes/rmail/` is removed by the
    next sync.

## Intended Behavior

### Inbound hook (`/home/ritz/notes/rmail/hooks/on_receive.lua`)

rmail runs the `on_receive` hook in the background after it has written the
message to `inbox/`, with three arguments: sender name (string), subject
(string), absolute inbox file path (string). The daemon has already set the
inbox file's modification time to the sender's authoring time; the notes
extractor uses modification time as the poem's creation date, so the copy must
keep it.

1. Destination = notes directory + the inbox file's own name (rmail derives it
   from the subject, already sanitised to a single path component).
2. If the destination exists: do nothing to either file, log an error line. A
   note is never overwritten and the message is never lost.
3. Copy with timestamps preserved to a hidden temporary name in the notes
   directory, compare byte-for-byte with the inbox file, rename into place
   (atomic within one filesystem, so the extractor never sees a half-written
   note), compare again, then delete the inbox file.
4. Any failed step stops the hook with the inbox file still in place, and
   leaves an error line in `rmail/hooks/on_receive.log`.
5. Deleting the inbox file is a supported user action in rmail: the daemon's
   inbox reconciliation notices the missing file and tells the sender the
   message was deleted.

Messages the daemon writes itself (for example `lan-ip-changed`, a local
address-change notice) do not go through `on_receive`, so they stay in the
inbox.

### Extraction

- `sources.notes.directories[1].excluded_subdirectories` — array of strings,
  each a subdirectory name relative to the source root.
- Consumed by the external sync (rsync `--exclude=/<name>/`, plus removal of the
  stale destination copy) and by the notes extractor (find `-prune`).

## Suggested Implementation Steps

1. `config.lua`: add `excluded_subdirectories = { "rmail" }` to the notes
   directory entry, with a comment saying why.
2. `libs/sources-loader.lua`: carry the field through the directory list and the
   external-sync list.
3. `libs/external-sync.lua`: validate each entry exists under the source; add
   the rsync excludes; remove stale copies from the destination.
4. `scripts/extract-notes.lua`: prune the excluded subdirectories from the walk.
5. Test (`scripts/notes-tooling-exclusion.test.sh`): a scratch project and a
   scratch notes source with a mailbox inside; confirm the sync skips it and
   removes an old copy, a missing or path-like entry is refused, and the
   extractor never emits a note from it even when a copy is present.
6. Hook: write `rmail/hooks/on_receive.lua`, point the mailbox `config` at it,
   test it against a scratch notes directory (normal move, collision, mtime
   kept).

## Open Questions

1. **Collision (open, being designed):** the hook refuses and leaves the
   message in the inbox. Owner (2026-09-22): "can you instead make an outbox
   file pointing to the kuvalu-mail mailbox located at ~/mail/? ... This is
   only for if a name gets clobbered. ... we should only send the
   notification to kuvalu-mail if there's a filename collision. Then we just,
   don't do anything until the user manually resolves it."
   - Intended: on a collision the hook keeps both files untouched and writes an
     outbox message in this mailbox addressed to the owner's main mailbox at
     `~/mail/`, saying which note name collided.
   - Facts for the design: the `~/mail/` mailbox's configured name is `kuvalu`
     (not `kuvalu-mail`), port 8025. It has no contact entry for
     `kuvalu-notes`, and `kuvalu-notes` has none for it. Both sides need an
     entry with a shared token before a message can travel.
   - The owner separately wants a shell-login notice for any mail in `~/mail/`
     (replacing the random-words display while mail is waiting). That is a
     side project for the `~/mail/` mailbox, not part of this issue.

### Answered

2. **Note filename.** Should notes use the `YYYYMMDD-HHMMSS.txt` shape instead
   of rmail's subject-derived name? Owner (2026-09-22): "keep their filename.
   Rmail knows how to name them. The dated names are worse than the specific
   names, and only are applied if we don't supply one when sending the
   message." No change: the hook keeps rmail's name.
3. **Who may publish.** Owner (2026-09-22): "only my devices will be enabled as
   contacts for the kuvalu-notes mailbox." No filter in the hook. The contacts
   file is the gate.
4. **Daemon notices.** Owner (2026-09-22): "we're working on that in parallel
   in a different terminal. For now, you can remove it." The one
   `lan-ip-changed` notice was removed by hand. The general handling belongs to
   the other session.

## Related Documents / Tools

- `/home/ritz/programs/r-mail/docs/scripting-tutorial.md` — hook arguments.
- `/home/ritz/programs/r-mail/rmail.lua` — where `on_receive` is fired (after
  the inbox write, with the sender's modification time applied).
- `issues/completed/10-053-*` — the configured-exclusion rule this follows.
