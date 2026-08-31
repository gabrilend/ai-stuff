# 128-say-elsewhere — info

Saying something, as a routine anything can call, on all three machines. Issue 403.

A computer that cannot be heard is debugged by watching it sit still. Every payload this project has booted says things, but each one spells its own words out inline as it emits them -- which works for a payload that knows at build time what it will say, and is no use at all to an engine that will say whatever a model produces.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `128-say-elsewhere.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/128-say-elsewhere.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.CONSOLE_OUTPUT_STRING` | where the firmware keeps the routine |
| `M.x86_64()` | described below |
| `M.aarch64()` | described below |
| `M.riscv64(p)` | described below |

### In more detail

**`M.CONSOLE_OUTPUT_STRING`**

The console protocol's second function, eight bytes in: reset is first,
output is second. Named rather than written inline, because a bare number
in the middle of assembly is the shape mistakes hide in -- the same
reasoning `069` gives for its own table of offsets.

**`M.x86_64()`**

void console_say(void *console, const uint8_t *bytes, int64_t length,
                 uint16_t *scratch, int64_t capacity)

console rdi, bytes rsi, length rdx, scratch rcx, capacity r8.

THE FORTY BYTES TAKEN OFF THE STACK ARE NOT SCRATCH. Firmware here is
called by a convention that requires the caller to leave thirty-two bytes
below the return address which the callee may use for its own arguments,
and to have the stack sixteen-byte aligned at the call. The routine never
reads those bytes. Not leaving them is the kind of fault that appears on
one firmware and not another.

**`M.aarch64()`**

void console_say(void *console, const uint8_t *bytes, int64_t length,
                 uint16_t *scratch, int64_t capacity)

console x0, bytes x1, length x2, scratch x3, capacity x4.

Firmware here is called the same way everything else is, so there is no
shuffling and no room to leave. What there is instead is the return
address, which must be saved because this routine calls something -- and
losing it is not a wrong answer but a machine that never comes back.

**`M.riscv64(p)`**

void console_say(void *console, const uint8_t *bytes, int64_t length,
                 uint16_t *scratch, int64_t capacity)

console a0, bytes a1, length a2, scratch a3, capacity a4.

Emitted into a counted program rather than returned as text, because this
assembler leaves a relocation on a branch to a label in its own file and
there is no linker to answer it -- so every loop here would be a silent
infinite one, which is a particularly unkind way for the routine that
exists to break silences to fail (054).

## Why it is wanted before anything else the driver does

Every silence this project has debugged was diagnosed by the last thing printed before it -- a call whose offset was zero, a payload entered with the firmware's registers, a binary truncated at four thousand and ninety-six bytes. On a machine with nothing above it, the only difference between a fault and a mystery is whether something was said first.

## The firmware wants wide characters

Its console takes two bytes per character and stops at a zero, so ordinary bytes have to be widened and terminated before they can be handed over. That is the whole of the work, and the reason this cannot simply be a store to a port.

## It chunks rather than assuming room

The caller says how large the scratch is; anything longer is said in as many pieces as it takes. A routine that assumed the buffer was big enough would write past it on exactly the long message somebody was trying to read after a crash.

## One architecture has to shuffle its arguments and two do not

and that is worth knowing before reading the first of them. Firmware on the first architecture is called by a different convention than the rest of that architecture's code uses -- arguments in c, d, r8, r9 rather than di, si, d, c -- so calling into it means moving things first, and leaving it room on the stack it never uses but expects to exist. On the other two, firmware is called exactly the way everything else is.

## Worth knowing

So this is the same capability made callable: hand it some bytes and a length and it says them.

## Where it sits

**Belongs to** `403`.

**Checked by** `129-test-say-elsewhere`.

