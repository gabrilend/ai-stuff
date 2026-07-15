# 62 — Mount a USB-C peer under /mnt (peer mode, capstone)

Give every connected USB-C cable its own filesystem under `/mnt/usb-c-<peer>/`,
kept in sync with the far end over the link. Writing a file into the mount sends it
across the wire; files the peer sends appear in the mount. This is the capstone that
joins the mount, the store, and the transport.

## Current behavior

Not yet implemented. Depends on the local mount adapter (issue 61), the framing +
`link` interface (Phase 2), and the USB transport (Phases 3–4). Buildable in stages:
first over a loopback/pipe link on one machine, then over real USB-C.

## Intended behavior

- A mount manager watches for connected peers (a USB-C cable presenting our bulk
  interface) and, per peer, creates an arena+directory, opens the `link`, and mounts
  it at `/mnt/usb-c-<peer>/`. Disconnect unmounts and tears down cleanly.
- **Write-through:** every mutating VFS operation on the mount is applied to the
  local arena *and* encoded as an opcode and sent over the link, so the peer's store
  converges to match.
- **Read-through:** opcodes arriving from the peer mutate the local arena, so the
  files simply appear on the next directory listing — no polling of the far end per
  read.
- Reserved key `direction` (via `user.direction` xattr) travels as `OP_FILE_META`,
  carrying the vision's "assign directions for how the file should be handled."
- Conflicts (both ends change the same file) resolve by a documented rule (e.g.
  last-writer-by-sequence), surfaced rather than silently dropped.

## Suggested implementation steps

1. Reuse the issue-61 adapter, swapping its "apply locally" hook for "apply locally
   **and** emit an opcode to the link."
2. A peer/mount manager keyed by peer id: arena + directory + link + mountpoint per
   cable; mount under `/mnt/usb-c-<peer>/`.
3. Wire incoming link frames through the interpreter into the same directory the
   mount reads from.
4. Start on a loopback/pipe link (two directories, one machine) so the whole
   mount↔wire↔mount loop is testable before USB hardware; then move to the USB host
   (Phase 4) driving a gadget device (Phase 3).
5. Test: `cp` a file into one side's mount, assert it appears in the other side's
   mount byte-identical; `rm` on one side removes it on the other.

## Related documents and tools

- `docs/mount-as-filesystem.md`, `docs/datapath-file-transfer.md`. Blocks on issue
  61 + Phase 2 (+ Phases 3–4 for real USB). The final USB-C-cable-as-filesystem goal.
