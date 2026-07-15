# 63 — Cable-as-courier sync & space reconciliation

The cable is not just a wire — it holds its own store and carries data between
machines. This issue defines how slots sync on contact, how the cable ferries data
while unplugged, and what happens when two slots that want to merge do not fit.

## Current behavior

Not yet implemented. Peer mode (issue 62) will do a straightforward "make the far
side match" sync; this issue defines the richer courier + reservation + eviction
semantics on top of it.

## Intended behavior

- **Three participants, each a slot.** Computer A, the cable itself (it has onboard
  memory — an arena like any other), and computer B. The cable's slot is a *mobile*
  store: a courier.
- **Sync on contact.** The moment a cable is plugged in (or a new device appears),
  the data is moved into the memory section assigned on the receiving side — no
  manual trigger.
- **Carry while unplugged.** Unplug the cable from the computer (but not from its
  device / or the cable is the device) and it retains its slot's contents — it
  carries them around and can deposit them into whatever it is next plugged into.
- **Re-plug syncs.** Plug the carried cable into another computer and the two slots
  reconcile.
- **Space is reserved during transfer.** Before bytes move, the incoming size is
  estimated and that much space is *marked reserved* on the receiving side, so two
  concurrent transfers cannot both think the room is free.
- **Oversize is the only failure, and only on merge.** Running out of space happens
  only when two slots meant to *combine* hold data different enough that their union
  exceeds one side's capacity. When it does, **both ends complain** — the error is
  surfaced, never silently swallowed.
- **Reconciliation rule.** Transfer **newest first** until the slot is full; then
  **delete oldest** until enough space frees to fit the rest. Newest data wins;
  oldest is evicted.

## Suggested implementation steps

1. A per-slot reservation ledger: capacity, in-use, and reserved-in-flight bytes,
   consulted before any `OP_FILE_ALLOC`.
2. Age ordering that survives crossing machines: a logical sequence/version carried
   in file metadata (wall clocks differ between machines, and are avoided), resolved
   by a documented newest-wins rule — not raw local time.
3. A pre-flight estimate + reserve step; on insufficient room, an eviction pass
   (sort by age, delete oldest via `OP_FILE_DELETE`) until the reservation fits, else
   the "complain on both ends" error path.
4. Expressed entirely in the safe opcode set: reserve = `ALLOC`, fill = `WRITE`,
   evict = `DELETE`, age/direction = `META`.

## Related documents and tools

- Builds on issue 62 (peer mount) and the store (issue 12); uses the opcode set
  (issue 13). Interface surfaced through the mount (`docs/mount-as-filesystem.md`).
