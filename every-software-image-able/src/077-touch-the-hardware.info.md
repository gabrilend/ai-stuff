# 077-touch-the-hardware — info

Finding out what body the machine has, and operating it -- under the discipline in docs/003a, which is this ticket's subject rather than its advice. Issue 205.

The machine can now ask every socket in the computer who is plugged into it, and read and write those devices' controls. Some of those controls destroy hardware permanently when written wrongly, so the dangerous ones are refused until a description has been read and confirmed, and every exploratory write must be written down before it happens and must say what it expects.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `077-touch-the-hardware.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/077-touch-the-hardware.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.DESTROYING` | what may not be touched without a confirmed description |
| `M.new(options)` | described below |
| `M.look(hardware)` | The machine finding out what limbs it has. |
| `M.peek(hardware, name, offset, width)` | Reads are where nearly all the information is and nearly none of the danger, so this is the easy one and is deliberately easier to reach than its w... |
| `M.write_the_note(hardware, note)` | Device, register, value, and what is expected -- to storage, before the write happens, so a probe that kills the machine still tells the next boot ... |
| `M.poke(hardware, name, offset, width, value, options)` | The dangerous one, and made harder to reach than the reading one on purpose. |
| `M.confirm(hardware, kind, description)` | Opening a destroying category. Confirming is a read-only act -- it is reading a description and saying it matches what the part reports about itsel... |
| `M.kinds()` |  |
| `M.offer(catalogue, hands, hardware)` |  |

### In more detail

**`M.DESTROYING`**

From docs/003a, with the mechanism for each, because a refusal that does
not say what it is protecting teaches nothing and gets worked around.

**`M.new(options)`**

```
options:
  enumerate  function() -> a list of devices, each with slot, vendor,
             part, class, registers, interrupt
  read       function(device, offset, width) -> value
  write      function(device, offset, width, value)
  store      a storage (076), for the notes
  note_on    which device the notes are written to
  note_at    which block they start at
```

**`M.peek(hardware, name, offset, width)`**

Reads are where nearly all the information is and nearly none of the
danger, so this is the easy one and is deliberately easier to reach than
its writing twin.

Two things keep "reads are safe" from being exactly true, and both are
said rather than assumed away: some registers clear themselves when read,
so reading them is a change; and on some buses a read from an address
nothing answers on hangs until something resets the bus. Both are
survivable. Neither is destructive.

**`M.write_the_note(hardware, note)`**

Device, register, value, and what is expected -- to storage, before the
write happens, so a probe that kills the machine still tells the next boot
what killed it.

**`M.poke(hardware, name, offset, width, value, options)`**

The dangerous one, and made harder to reach than the reading one on
purpose.

options: expecting (what the machine thinks will happen; required),
         kind (which destroying category this register is, if any)

**`M.confirm(hardware, kind, description)`**

Opening a destroying category. Confirming is a read-only act -- it is
reading a description and saying it matches what the part reports about
itself -- which is why it is separate from writing anything.

## Why the discipline is a constraint and not a preference

Writing the wrong value to the wrong register destroys hardware permanently -- not a crash, not corruption, not something a reboot clears. Every other failure in this project is recoverable by writing more software. These are not.

## The note comes first, and that is why this needs storage

(206). A probe that kills the machine cannot report anything afterwards -- the reporting channel dies with the machine (notes/023). So the intent is written to storage BEFORE the write happens, and the next boot reads it and knows what killed the last one. Without somewhere to put it, the discipline is an intention with no failing test attached, and these two tickets land together or not at all.

## Where it sits

**Belongs to** `205`.

**Checked by** `078-test-keep-and-touch`, `093-test-devices-that-die`.

