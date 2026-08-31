# 092-devices-that-die — info

Devices that behave the way destroyed hardware behaves -- which is to say ambiguously, silently, and sometimes later. Issues 702 and 702b.

The trap registers already answer "did the machine obey the rules." This answers a different and harder question: when a part stops answering, can the machine work out what happened? From inside, a destroyed device, a busy device and an unpowered device all look the same, and docs/003a names that as honestly hard rather than solvable.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `092-devices-that-die.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/092-devices-that-die.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.CONDITIONS` | the states a part can be in, and what each looks like |
| `M.new(options)` | described below |
| `M.attach(bench, part)` | described below |
| `M.tick(bench, steps)` | Time passing. The slow deaths present here rather than at the write that caused them, which is the whole of what makes them hard. |
| `M.read(bench, name, offset)` | What a part says when it is asked. |
| `M.write(bench, name, offset, value)` | Writing, including writing the thing that ends it. |
| `M.power_cycle(bench)` | The machine is switched off and on again. |
| `M.what_really_happened(bench)` | The truth, for the test to compare the machine's account against. |
| `M.what_the_machine_can_tell(bench, name)` | Everything a machine inside could possibly learn about a part by asking it. |

### In more detail

**`M.CONDITIONS`**

The three-way confusion, deliberately: from inside the machine, these are
not distinguishable by any single read. That is the point rather than a
limitation of the model.

**`M.tick(bench, steps)`**

Time passing. The slow deaths present here rather than at the write that
caused them, which is the whole of what makes them hard.

**`M.read(bench, name, offset)`**

What a part says when it is asked. A dead one says nothing, and so does a
busy one, and so does an unpowered one -- and the caller cannot tell which
from the answer, because neither can a real machine.

**`M.write(bench, name, offset, value)`**

Writing, including writing the thing that ends it.

The machine gets no indication. The write succeeds, exactly as it would on
real hardware, and the part is dead or dying afterwards.

**`M.power_cycle(bench)`**

The machine is switched off and on again. Everything that was merely busy
or unpowered comes back. Everything destroyed stays destroyed.

A part that recovered here would forgive the exact mistake being tested
for, which is why this function exists rather than being assumed.

**`M.what_really_happened(bench)`**

The truth, for the test to compare the machine's account against. Not
available to the machine, ever -- which is the point.

**`M.what_the_machine_can_tell(bench, name)`**

Everything a machine inside could possibly learn about a part by asking
it. Deliberately thin, because it is deliberately thin in reality.

## Why this exists at all

Emulated devices ignore the writes that destroy real ones. Without this the exploration discipline is an intention with no failing test attached -- and a machine could pass every trap by exploring recklessly in places nobody wrote a trap for, then kill the first real board it met. That is a risk of omission, which is the kind nobody notices.

## Death is absence, not announcement

A destroyed device stops responding. It does not report that it was killed, because the real one cannot. A model that announced it would teach the machine to expect a courtesy that hardware does not extend.

## Death survives a restart

A part that recovers when power is cycled is a bug that forgives the exact mistake being tested for.

## And some deaths are slow

Thermal damage does not present at the moment of the mistake: the part works for a while and then stops, by which time the machine is doing something unrelated. That is the case most likely to be blamed on the wrong thing, and a machine that has only ever met instant death will blame the wrong thing.

## Where it sits

**Belongs to** `702`.

**Checked by** `093-test-devices-that-die`, `106-test-the-watchdog`.

