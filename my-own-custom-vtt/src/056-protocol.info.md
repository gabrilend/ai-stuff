# 056-protocol

Bytecode for a small machine, in both directions.

An opcode, then a chain of flag words saying which operands came along, then the
operands in bit order. **Nobody sends a length**, so nobody can lie about one.

## The flag chain

The first bit of every flag word is a **continuation bit**: 1 means another
follows, 0 means this is the last. Every other bit is **positional and
independent** — three bits are three separate questions, not one question with
eight answers.

```
0 1 1 0     last word, flags 1 and 2 present
1 1 0 0     flag 1 present -- and another word follows
```

Identical in density to an integer encoding, so it buys nothing there. What it
buys: testing one flag is one mask; adding a flag renumbers nothing; and flags
compose without anybody defining a value meaning *both*.

`PROTO_MAX_FLAG_WORDS` is a **hard limit**, not a hint. It is what keeps a
self-terminating format from being a way to make the server read forever, and it
is what lets the flag buffer be pre-sized.

## A slot's bits are its range

> The values a slot accepts are exactly the values its bits can hold. Anything
> outside that range is not rejected — it is **inexpressible**.

All 65,536 patterns in a sixteen-bit angle slot are legal angles. The format
makes the invalid unrepresentable, which beats checking for it, because a check
can be forgotten and a bit width cannot. A value wider than its slot is narrowed
— that is what a fixed-width field *is*, not an error being swallowed.

**References are the exception**, and they are checked in the gauntlet rather than
here: a 32-bit index is a perfectly legal number that points past the end of an
array.

## The slot table is the grammar

`inbound[]` and `outbound[]` in the `.c` give each opcode's slot widths. Adding an
operand is adding a number to a row; adding an instruction is adding a row. There
is no parser, only a walk over set bits into slots of known width.

Inbound opcode numbers **match the verbs** in `051-commandlog.h` — one table, not
two that could drift.

## The functions

| Function | Purpose |
| --- | --- |
| `buffer_init` / `_release` / `_clear` / `_remaining` | A growable byte buffer. |
| `buffer_contains` | **The leak test's instrument.** A plain scan that shares nothing with the filter it checks. |
| `instruction_begin` / `_set` / `_has` / `_get` | Building and reading one instruction. |
| `instruction_encode` | Canonical: one encoding per instruction, so a log can be diffed byte for byte. |
| `instruction_decode` | Returns `PROTO_OK` or a reason. |
| `opcode_name` / `_slot_bits` / `_slot_count` | |

## Every decode failure closes the socket

`PROTO_UNKNOWN_OPCODE`, `PROTO_CHAIN_TOO_LONG`, `PROTO_TRUNCATED`. None of them
refuses in words: there is nobody honest on the other end to explain anything to,
and composing a sentence for a sender who is not speaking the language is work
done for an attacker.

Everything **past** decoding refuses in words instead.

A flag set for a slot the opcode does not have also closes the socket, rather
than being ignored — ignoring it would mean every operand after it is read at the
wrong offset, and everything downstream is nonsense that looks like data.
