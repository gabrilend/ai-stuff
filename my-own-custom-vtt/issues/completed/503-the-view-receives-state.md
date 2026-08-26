# 503 -- The view receives state

**Phase:** 5, the bridge and the browser
**Blocked by:** [502](502-the-bridge-serves-a-browser.md)
**Blocks:** [504](504-drawing-between-two-ticks.md)
**Documents:** [the dynamic picture](../docs/012-the-dynamic-picture.md)

## Current behaviour

A websocket exists and carries instructions. Nothing decodes them.

## Intended behaviour

The browser decodes the instruction stream into a world it can draw, and turns
keys and clicks into commands.

**No pixel is ever computed on the host's machine and no image is ever pushed
down the wire.** The server sends state; the browser makes a picture.

That is the generate-then-view split at the last boundary, and the reason to hold
it here is the same as everywhere else: when something looks wrong it is either in
the wrong place or drawn wrong, and those are two programs, and the search halves.

It also means bandwidth scales with how much is happening rather than with how big
somebody's screen is, and that a completely different renderer can be pointed at
the same stream.

### What it holds

| Held | Source |
| --- | --- |
| Walls | `OP_WALL`, from the viewer's memory |
| Bodies | `OP_THING`, from the viewer's sight |
| Visibility polygon | `OP_FAN` |
| Tick number | `OP_TICK` |
| Refusals | `OP_REFUSAL`, shown as sentences |

**An update is the whole picture.** Each one replaces what was held rather than
amending it, which is why a dropped update costs a beat of freshness and nothing
else, and why a rollback does not desynchronise anything.

`OP_RECALL` says a stretch of time did not happen. The view discards its
prediction and waits for the next whole update rather than trying to reconcile.

### It holds no truth and is never trusted

Nothing here decides what may be seen. The server already decided, by not sending
it. The browser cannot reveal an ambush by being modified, because it was never
told about one -- and that is the entire reason the geometry runs on the host's
machine rather than here, where it would be far more convenient and completely
worthless.

## Suggested implementation steps

1. Write the decoder in JavaScript, driven by the same slot table the C encoder
   uses. **Generate the table into the page from the C header** rather than
   writing it twice -- two copies of a grammar drift, and the symptom is operands
   read at the wrong offsets.
2. Accumulate one update, then swap it in whole. Never draw a half-arrived one.
3. Turn keys into `VERB_DRIVE` and clicks into `VERB_ORDER_MOVE`.
4. Show refusals as sentences, where a person will actually see them.
5. Write the companion `.info.md`.
