# 403 -- The wire format

**Phase:** 4, people connect
**Blocked by:** [402](402-a-session-is-a-socket.md)
**Blocks:** [404](404-one-function-writes-to-a-socket.md),
[406](406-commands-run-a-gauntlet.md)
**Documents:** [commands enter through one door](../docs/010-commands-enter-through-one-door.md)

## Current behaviour

Commands exist already, decoded, in `051-commandlog.c`. Nothing encodes or
decodes them.

## Intended behaviour

A stream of instructions for a small machine. Not a sequence of fixed records, not
a text protocol, and **not something with a length field a sender can lie about**.

### An opcode, then a chain of flag words

Each instruction begins with an opcode, one byte, which indexes the dispatch
table that already exists. An opcode with no row is not a malformed command -- it
is not a command at all, and the socket closes. There is nothing to explain to a
sender who is not speaking the language.

Then flag words, which chain:

- **The first bit of every flag word is a continuation bit.** 1 means another
  follows; 0 means this is the last. There is no count and no length -- the words
  say when they stop.
- **Every other bit is positional and independent.** Three bits are three separate
  questions, not one question with eight answers.

```
0 1 1 0     last word, flags 1 and 2 present
1 1 0 0     flag 1 present -- and another word follows
```

The count of expressible states is identical to an integer encoding, so this buys
nothing in density. What it buys: testing one flag is one mask; adding a flag
renumbers nothing; and flags compose without anybody defining a value meaning
*both*.

### How long the chain may be is configuration

A hard limit, read before anybody connects. That is what keeps a self-terminating
format from being a way to make the server read forever, and it is what lets the
flag buffer be one of the pre-sized containers.

**The default should be small.** A server listening for five words when it
understands one is advertising an attack surface it does not use.

### Pre-sized containers, and nothing to validate

The decoder writes into a register file: fixed slots, allocated once, reused by
every instruction. Nothing allocates during decode.

> **The values a slot accepts are exactly the values its bits can hold. Anything
> outside that range is not rejected -- it is inexpressible.**

All 65,536 patterns in a sixteen-bit angle slot are legal angles. The format makes
the invalid unrepresentable, which beats checking for it, because a check can be
forgotten and a bit width cannot. A value landing between representable steps
**rounds**, and that is what a fixed-width field is, not an error being swallowed.

**References are the exception.** A 32-bit index is a perfectly legal number that
points past the end of an array, and that is refused rather than clamped --
clamping would aim a command at whichever body happened to be last.

## Suggested implementation steps

1. Define the opcode byte and the flag-word width. A byte gives seven flags per
   word, which is probably more than a command needs and therefore probably right
   -- but decide it, and write down why.
2. Write the decoder as a walk over set bits into slots. Not a parser.
3. Write the encoder, and make it canonical: one encoding per command, so the
   log can be diffed byte for byte.
4. Write the outbound encoding for world updates.
5. Write the companion `.info.md`.
6. Test the round trip: encode, decode, compare the decoded form. Then encode the
   decoded form again and compare bytes.
7. Test refusals: unknown opcode, a chain past the configured limit, an
   instruction cut short by the socket closing mid-read.
