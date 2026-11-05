# 302 — The arrival hook on kuvalu

phase 3, the relay through rmail

## Current behavior

The blitter (107) reads voice canvases from
`tmp/shared-memory/arrivals/`, but only scripts put them there.

## Intended behavior

One hook script, set as both `on_receive` and `on_update` in the guide
mailbox, doing only step 6 of `docs/datapath-round-trip.md`:

- with `on_receive` arguments (sender, subject, inbox file path), it reads
  the inbox file's body;
- with `on_update` arguments (sender, old inbox file path, new body), it
  takes the new body;
- either way, it writes the body to
  `tmp/shared-memory/arrivals/<sender>-<unix time>-<random>` (temporary
  name, then rename), prints nothing (so rmail keeps the new body), and
  exits.

The two kinds of call are told apart by a first argument written into the
config line, never by guessing from the arguments. Messages whose subject is
not `canvas` are logged and left alone. The hook does no parsing beyond that,
because `on_update` holds rmail up while it runs.

## Suggested implementation steps

1. LuaJIT, rebuilding the RAM tiers first since a reboot empties them.
2. Test by calling it directly with both argument shapes, then through the
   live mailbox from a stand-in (305).

## Related documents

- `docs/datapath-round-trip.md`
- `docs/rmail-constraints.md`, "Hooks run on arrival"

## Blocked by

107, 301.

## Blocks

305.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The first word is `receive` or `update`, from the config line (301),
   and each takes exactly rmail's three arguments.** Anything else is
   refused with exit 1 and a log line; the hook never guesses.
2. **`on_update`'s subject is its inbox file's name**, since rmail does not
   pass one. Only exactly `canvas` is taken: a second message that rmail
   names `canvas-2` is not the voice's living canvas, and is left alone.
3. **The body is the argument, or standard input when the argument is
   empty.** On rmail main a canvas is always in the argument (it is never
   empty), so standard input is never read there. Under rmail #215 a body
   over 64 KiB comes only on standard input.
4. **A sender that is not a plain name (letters, digits, `-`, `_`) is left
   alone**, since the name becomes part of a file name. Whether the sender
   is a voice, and whether the canvas says so, is the blitter's check
   (`wrong-sender`), not the hook's.
5. **Exit 1 when the body could not be written**, the inbox file is
   missing, the body is empty, or the call is unknown. Under rmail #215 a
   failing `on_update` makes rmail refuse the edit and send it again later,
   so a canvas is held back rather than lost. On rmail main the status is
   not read, and the log line is the record.
6. **No goodbye receipt.** Each call is a separate short program, and a
   receipt would be overwritten by every arrival. One log line per call
   goes to `tmp/shared-memory/arrival-hook.log`, and the blitter's receipt
   counts what arrived.
7. **The RAM tiers are made sure of on every call that writes**, through
   the project's `libs/ensure-ram-tiers.lua`, then the arrivals folder.
8. **The random part is 8 hex digits from `/dev/urandom`**, so two edits
   in one second are two files.

## Implementation notes (2026-11-05)

- `src/033-arrival-hook.lua` and `scripts/arrival-hook`, which finds its
  project from its own path.
- `src/034-test-arrival-hook.lua`: 22 pass. It calls the hook as rmail's
  config lines make it call, through a mailbox made by
  `scripts/make-mailboxes`, and ends with the real blitter making versions
  2 to 4 from what the hook wrote.
- Mutation checks, 12, were each caught but one: writing straight to the
  final name instead of a dot name, which cannot be seen by a test that
  runs one thing at a time. The rename is kept because the blitter reads
  the folder while the hook writes.
- `docs/datapath-round-trip.md`, step 6. `.file-index-counter` is at 034.

**Needs the owner's machine:** the hook called by the live guide mailbox on
kuvalu. The rehearsal (305) calls it through stand-in mailboxes here.
