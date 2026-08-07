# 139, 140 — the loop, and first light — info

`139` emits the driver: the routine a bare machine enters that reads what it
was told, thinks about it, and says what it thought. `140` runs it twice —
once on the development machine where a failure can be pointed at, and once on
an emulated computer with no operating system, which is the claim that
matters. Issue `107a`, steps five through eight of `107`.

## Running it

```
luajit src/140-test-the-driver.lua              # both halves
luajit src/140-test-the-driver.lua --quick      # without booting a board
```

## What `139` exports

| Name | Meaning |
|---|---|
| `PLAN_SLOTS`, `plan_offsets()`, `plan_bytes()` | the driver's plan, as data and as offsets |
| `WISH_SLOTS`, `wish_offsets()`, `wish_bytes()` | what a sampler needs to be told |
| `REASONS` | why a turn stopped, as numbers |
| `declare()`, `declare_wishes()` | the structures as the host's FFI sees them, checked slot by slot against the assembly |
| `sampler_room(vocabulary)` | how much room the sampler's three scratch arrays need |
| `sampler_x86_64(sampler)` | `sampler_setup` as assembler text |
| `x86_64()` | `drive` as assembler text |

```
int64_t drive(DriverPlan *plan)
int64_t sampler_setup(SamplerPlan *plan, SamplerStream *stream,
                      void *room, int64_t bytes, const SamplerWishes *wishes)
```

`drive` returns why it stopped and also leaves it in the plan, beside how far
the cache reaches and how many words were said. `sampler_setup` returns bytes
used or minus the shortfall — `133`'s convention, usable here because there is
only one way for it to fail.

## Why a turn stopped

| | | |
|---|---|---|
| `1` | finished | the token that means finished, drawn and swallowed |
| `2` | length | as many words as it was allowed |
| `3` | room_ran_out | the context is full |
| `-1` | unsayable | a byte of the carried text no token says; `detail` says where |
| `-2` | too_long | more tokens than the machine can hold; `detail` says how many |
| `-3` | nothing | it was told nothing at all |
| `-4` | unknown | a drawn token the vocabulary cannot say back |

The three that are not failures are positive and the four that are come back
negative, so a caller that only wants to know whether anything went wrong looks
at the sign. **A finished turn and an exhausted one are kept apart** — both
look like a machine that stopped talking, and they call for completely
different responses from whoever is watching.

## Everything it calls, it calls through a pointer

There is no linker. A call written by name needs somebody to fill in the
offset afterwards, and that somebody does not exist — which is two of the four
silences in `107`'s table, where an offset stayed zero and a call with offset
zero is a call to itself. So the routines' addresses arrive in the plan, the
way the conducting takes its kernels (`056`), and whoever fills the plan is the
only thing that has to know where anything is.

## The order of the loop is the readable loop's order, exactly

Length checked before drawing. The finish token checked after drawing, and the
drawn token not kept. The room checked after keeping and before conducting.

Each of those decides whether one more token is drawn; a drawn token is
discrete; and one different token means the two machines are having different
conversations from that word onwards. This is the one place in the project
where matching the reference means matching its control flow rather than its
arithmetic.

## The cache is appended to, not rebuilt

`061` reuses the longest common prefix of what the cache holds, because between
turns it can be handed a whole new context. This one only ever appends, so it
keeps a position and advances it — the same arithmetic with none of the
comparison. Correct **only** while nothing rewrites the context underneath it,
which stops being true the moment the machine can drop or reorder what it
holds.

## What it is not

Not the machine's whole life. It does one turn and returns why it stopped, and
the forever-loop that ought to sit around it is deliberately absent: with no
hands and no channel there is nothing for the machine to think about next, so
it would draw from the same scores forever. The outer loop arrives with the
hands — step nine of `107` — which is what gives a finished turn something to
have been about.

## What `140` proves, and how

The readable loop (`061`) builds its own plan, its own cache and its own
prepared tables from the same model; if it shared any of them the comparison
would be a program agreeing with itself. Then the assembly sets a machine up
from nothing — finds the weights, divides the memory, fills the plan, builds
the word tables, readies the randomness — and drives. The words must match
token for token.

On the board, the model, the starting text and the carried randomness ride
inside the payload sixty-four kilobytes past its first instruction (`029`), and
every one is reached by measuring from where the code is standing. That is not
how a shipped card will carry them — see the open question in `107a` — but it
exercises exactly the address arithmetic a shipped one would.

**Bytes go to the console as hexadecimal rather than as characters.** This
model's vocabulary says low bytes including nought, and a nought handed to a
console that wants a terminated string ends the line there — so a machine that
said the right thing would look like one that said half of it.

## Result on 2026-08-07

33 of 33. On the emulated board: 22 tensors found, 5312 bytes divided, the
plan filled, 1328 bytes of word tables built, 768 bytes of sampler scratch
readied, and six words spoken — the same six, in the same order, that the
readable loop speaks from the same text with the same carried randomness.
