# 076, 077, 078 — keeping something, and touching what can break — info

`076` is persistent storage; `077` is finding and operating hardware under
the discipline of `docs/003a`; `078` checks both together. Issues `206` and
`205`, which land together or not at all: the discipline that makes
exploring survivable depends on writing a note first, and the note needs
somewhere to land.

## Running the checks

```
luajit src/078-test-keep-and-touch.lua
```

## `076` — blocks, and an extent the machine owns

| Name | Meaning |
|---|---|
| `new(options)` | the devices as the machine sees them |
| `enumerate(store)` | what is attached, how large, writable, removable |
| `read`, `write` | blocks, refusing anything that is not whole blocks |
| `claim(store, name, at, blocks)` | takes an extent and writes the mark |
| `look_for_claim(store, places)` | the next boot, finding it again |
| `offer(...)` | `storage`, `keep`, `recall` as hands |

**No filesystem.** The machine can build one if it wants one. What the seed
needs is blocks, an extent it owns, and the ability to find that extent
again — a filesystem built in would decide on the grown machine's behalf how
it organises itself.

**A read-only medium refuses rather than pretending.** That is the expected
case, since the seed is meant to be plugged into machine after machine
unchanged, so the refusal is ordinary and must never be discovered by a
write that silently did nothing.

**A mark naming another device is not adopted.** A disk cloned from another
machine carries one, and adopting it would mean two machines writing over
each other with nothing saying so.

**The mark is parsed by lines, not by pattern.** It has hyphens in it, and a
hyphen in a Lua pattern is a quantifier — so the pattern matched nothing,
every field came back empty, and every claim looked like a stranger's. It
surfaced only because the refusal tried to name whose it was.

## `077` — the body, and the five ways to destroy it

| Name | Meaning |
|---|---|
| `DESTROYING` | the five kinds, each with what it does when written wrongly |
| `look(hardware)` | what answers, where its controls are, which line it pulls |
| `peek` | reading, which is where the information is |
| `poke` | writing, which is where the danger is |
| `confirm(hardware, kind, description)` | opens one kind, read-only |
| `offer(...)` | `body`, `read_register`, `write_register`, `dangers` |

Three rules, each enforced rather than recommended:

**The note comes first.** Device, register, value and expectation go to
storage *before* the write, because a probe that kills the machine cannot
report anything afterwards — the reporting channel dies with the machine. A
machine with nowhere to write a note may not explore at all.

**A prediction is required.** A write that says what it expects can be
evaluated; one that does not produces a result nobody can interpret.

**The destroying registers are refused by default** — voltage, clock,
thermal, non-volatile, pin direction — and the refusal says what each one
does, because a refusal that does not explain itself teaches nothing and
gets worked around. Confirming a description opens one kind and only that
kind.

Writing reads the register back afterwards and returns what is actually
there, so the machine learns what happened rather than what it predicted.
The difference between those two is the entire content of an experiment.

## What is not covered

A read that never returns — some buses hang on an address nothing answers
on, and this is the most likely way an early machine dies. Finding the reset
first, which the discipline asks for and a pretend device has none of. And
moving in, which belongs to `601` where there is a real machine to hand
control to.

## Result on 2026-08-02

28 of 28.
