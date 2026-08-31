# 083-the-patterns — info

The build patterns carried on the chip. Issue 303.

Shapes that have worked before, offered to the machine as suggestions it may take or leave. Not code -- code would decide how the machine gets built, and that decision is not the seed's to make.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `083-the-patterns.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/083-the-patterns.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.PATTERNS` |  |
| `M.as_text(name)` | `architecture` is required by any pattern that differs between machines, and refused rather than defaulted. |
| `M.names()` |  |
| `M.offer(catalogue, hands)` | `architecture` is which processor this card is for. |

### In more detail

**`M.as_text(name)`**

`architecture` is required by any pattern that differs between machines,
and refused rather than defaulted. A card carries the text for the
processor it is for; there is no such thing as the general answer, and a
default here would be a plausible-looking wrong one.

**`M.offer(catalogue, hands)`**

`architecture` is which processor this card is for. The hand that hands
back a whole pattern needs it for the same reason the payload builder
does: one of them is different on every machine.

## Every pattern has four parts, and the fourth is the one that matters

What it is, where it has worked, what it costs, and WHERE IT STOPS WORKING. A shape recommended without its failure mode is a trap with a good reputation.

## These are suggestions and say so

Most of them are written elsewhere in this project as though they were how the machine works. They are not; they are how some machines have worked. A machine that organises itself completely differently and ignores all of these has done nothing wrong.

## Worth knowing

The one exception is the calling convention, which is not a suggestion but an agreement -- everything the machine writes has to agree with everything else it wrote, and that agreement has to start somewhere.

## Where it sits

**Belongs to** `303`.

**Checked by** `085-test-the-payload`.

