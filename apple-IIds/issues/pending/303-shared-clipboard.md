---
name: shared clipboard
phase: 3
status: pending
blockedBy: [201]
---

# 303 — shared clipboard

Copy on screen A, paste on screen B. The IIds Scrap Manager on each
side talks to a shared scrap that the broker mediates.

## current behavior

Each instance has its own Scrap Manager with its own in-memory scrap.
A copy on screen A is invisible on screen B.

## intended behavior

- The broker holds a **shared scrap state**: the most recent scrap
  data, its scrap type (text, picture, etc.), the originating
  instance, and a timestamp.
- When IIds A's Scrap Manager performs `PutScrap`, GS/OS — modified
  via a small patch — also writes the scrap to the broker.
- When IIds B's Scrap Manager performs `GetScrap`, GS/OS reads from
  the broker first; if the broker has a more recent scrap than B's
  local, the broker's wins.
- Scrap types supported in phase 3: TEXT and PICT (Super Hi-Res
  picture). Other types (sound, custom) are deferred.
- The "more recent" rule is timestamp-based: each scrap update
  carries a monotonic timestamp from the broker. Simple last-write
  semantics; no merge.
- Pasting on the originating screen still works normally — the local
  Scrap Manager has the data and the broker has the same data.
- If neither side has copied anything in this session, the broker's
  shared scrap is empty and `GetScrap` returns the local scrap (which
  may itself be empty).

## suggested implementation steps

1. Add a `shared_scrap` table to the broker's state: `{data, type,
   originator, timestamp}`.
2. Write a GS/OS source patch (`patches/030-shared-scrap.gsos.s.patch`)
   that hooks into `PutScrap` and `GetScrap` in the Scrap Manager.
   On `PutScrap`, after the normal local-write, send the data to the
   broker via a small SmartPort request (or via the broker-as-device
   mechanism if phase 7 has landed first).
3. On `GetScrap`, before returning the local scrap, query the broker
   for a newer one. If found, return it; the local scrap is updated
   too for consistency.
4. Implement the broker side of the SmartPort calls.
5. Test: copy text on screen A, paste on screen B. Copy a Super
   Hi-Res selection on screen B, paste on screen A.
6. Test the timestamp logic: copy on A at T=1, copy on B at T=2,
   paste on A. The paste should return B's scrap (newer), not A's.

## related documents

- `docs/001-architecture-overview.md` — broker responsibilities,
  shared clipboard
- `docs/004-roadmap.md` — phase 6 issue 601 (Scrap Manager native)
  takes this further; phase 7 issue 702 may move the channel from
  SmartPort to the Broker Input device
- `issues/702-broker-input-device.md` (pending/) — a parallel
  channel for input; the scrap channel is similar in spirit

## known design questions

- Should pasting on the originating screen produce a "no-op" warning
  if the broker's scrap is the same as the local one? No — silent
  is fine, the user doesn't need feedback that "the clipboard hasn't
  changed."
- Sound scrap and custom scrap types — defer to a follow-up issue
  once phase 3 lands.

## notes

- This is the cleanest seam for early OS-level mod work — the Scrap
  Manager is small, well-documented, and the GS/OS source release
  almost certainly contains its source. Worth using this as the
  pilot patch for the cross-surface patch convention if the
  About-string mod isn't dramatic enough.
