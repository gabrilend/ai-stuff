# 302 — The arrival hook

phase 3, the relay through rmail

## Current behavior

The page keeper (107) reads frames from `tmp/shared-memory/arrivals/`, but
only scripts put them there.

## Intended behavior

One hook script, set as both `on_receive` and `on_update` in the guide
mailbox's config, that does only what step 3 of
`docs/datapath-frame-to-page.md` says:

- given `on_receive` arguments (sender, subject, inbox file path), it copies
  the inbox file's body;
- given `on_update` arguments (sender, old inbox file path, new body), it
  takes the new body;
- either way it writes the body to
  `tmp/shared-memory/arrivals/<sender>-<unix time>-<random>` (temporary name,
  then rename), prints nothing (so rmail keeps the new body), and exits.

The two kinds of call are told apart by a first argument added in the
config line, not by guessing from the arguments' shape.

Messages whose subject is not `frame` are not frames. They are logged and
left alone.

It must finish quickly, because `on_update` holds rmail up. It does no
parsing beyond that.

## Suggested implementation steps

1. Write it in LuaJIT, sourcing the RAM tier helper first, since the RAM
   folder may be gone after a reboot.
2. Test by calling it directly with both argument shapes, then through the
   live mailbox with a message sent from a stand-in mailbox (304).

## Related documents

- `docs/datapath-frame-to-page.md`
- `docs/rmail-constraints.md`, "Hooks run on arrival"

## Blocked by

107, 301.

## Blocks

304.
