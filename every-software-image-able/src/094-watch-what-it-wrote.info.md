# 094-watch-what-it-wrote — info

Stepping through code nobody wrote by hand. Issue 703.

The code under inspection was produced at runtime by the model. There is no file, no symbols, no names -- so a debugger attached to the machine sees an address and can say nothing about what that address means. This is what turns "you are at 0x41f0" into "you are at instruction eleven of the thing it called the allocator."

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `094-watch-what-it-wrote.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/094-watch-what-it-wrote.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.LEDGER_SLOTS` | how the pairing looks in guest memory |
| `M.offsets(slots)` |  |
| `M.lay_out(runner, at, write)` | Writes the ledger into guest memory, so a tool outside can find it. |
| `M.find_ledger(read, from, to)` | What a tool outside does: scan guest memory for the magic number, because there is no symbol table to ask. |
| `M.read_ledger(read, read_string, at)` |  |
| `M.where_am_i(ledger, address)` | The answer this whole ticket exists for: turning an address into a place inside something the machine wrote, by name and by instruction. |
| `M.break_when_it_runs(runner)` | Where to stop: the moment the machine hands control to something it just wrote. |

### In more detail

**`M.LEDGER_SLOTS`**

Written down because a tool outside the machine has to find it. Every
field is eight bytes so the arithmetic outside is a multiplication rather
than a table of offsets somebody has to keep in step.

WHY A MAGIC NUMBER FIRST. A debugger scanning guest memory for this has
nothing else to recognise it by -- there is no symbol table saying "the
ledger is here". So the machine writes a number nothing else would
plausibly be, and the tool looks for it.

**`M.lay_out(runner, at, write)`**

Writes the ledger into guest memory, so a tool outside can find it. This
is the machine publishing its own bookkeeping -- nothing inside needs it
in this shape, and that is exactly why it has to be written down.

**`M.where_am_i(ledger, address)`**

The answer this whole ticket exists for: turning an address into a place
inside something the machine wrote, by name and by instruction.

**`M.break_when_it_runs(runner)`**

Where to stop: the moment the machine hands control to something it just
wrote. Those are exactly the addresses in the ledger, so the answer is the
ledger and this says so rather than making a second list.

## The naming problem is the whole ticket

Attaching a debugger is configuration; the trap runner (021) already does it. What is hard is that there is nothing to load symbols from, and what exists instead is the pairing 204 keeps -- the text the model wrote beside the bytes it became.

## Which puts a requirement back on 204

and it is met here rather than assumed: the machine's own bookkeeping has to be READABLE FROM OUTSIDE. A debugger sees raw guest memory, so the layout of the structure pairing text with bytes is part of a contract with a tool that lives outside the machine, even though nothing inside the machine needs it to be. That layout is declared here, once, as data -- the same rule as every other layout in this project.

## Where it sits

**Belongs to** `703`.

**Checked by** `096-test-watching-and-power`.

