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
