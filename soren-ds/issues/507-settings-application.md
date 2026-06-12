# 507 — Settings application

## Current behavior

The handedness and drawer-swap settings live in `/settings/`
files (408) but no input-stream code reads them. Every event
fires under the device's default handedness regardless of what
the user set, and the four center buttons always map to the same
drawer regardless of the swap flag.

## Intended behavior

A small `settings-applier` box reads the two relevant settings at
boot and re-reads them whenever the settings file changes. It
applies them to the event stream:

- **Handedness.** A boolean: left-handed or right-handed. The
  applier rewrites the *semantic role* of button events: in
  right-handed mode the D-pad is "navigation" and ABXY is
  "action"; in left-handed mode they swap roles. Physical button
  identity is unchanged; only the semantic-role tag the event
  carries changes. Apps subscribe to either the physical-tag
  events (the raw stream) or the semantic-tag events (the
  applier's output) depending on what they need.
- **Drawer-swap.** A boolean: standard or swapped. The applier
  rewrites the *target screen* on the four center-button events.
  Under the standard mapping (`start1`→bottom-left,
  `select1`→bottom-right, `select2`→top-left,
  `start2`→top-right), the rewriter passes through. Under the
  swap, `start1`+`select1` events get retagged with the top
  screen and `start2`+`select2` events get retagged with the
  bottom.

The applier subscribes to a `settings-change` event box that
fires whenever a relevant setting file is written. On change,
the applier re-reads from disk through `read-path` (406) and
updates its in-memory state with release ordering so any worker
reading the state sees a consistent before-or-after, never a
torn half-read.

The applier sits in the input-poll map (501) between the raw
event boxes from 502–504 and the consumer maps in phase 6
onward.

## Suggested implementation steps

1. `settings_applier_box()` — the rewriter.
2. `settings_change_event` — wires up to a watch on
   `/settings/` writes from 408.
3. Wire the applier into the input-poll map (501).
4. Document the physical-tag versus semantic-tag distinction in
   `docs/004-input-model.md` if it isn't already explicit.

## Related documents

- `docs/004-input-model.md`.
- `docs/011-filesystem.md` — the `/settings/` tree.

## Blocked by

408, 502.

## Blocks

508, phase 6.
