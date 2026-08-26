# Commands enter through one door

Everything a participant does arrives as a command, and every command travels the
same path into the world. There is one entry point, one decoder, and one place
where a command becomes a change.

The outbound direction had one rule. This direction has two:

> **A command is a request. The server decides, and may refuse. A refusal is a
> sentence.**
>
> **The server does not accept anything it does not recognise, and it writes only
> into containers it has already sized.**

## The stream is bytecode, not a struct

A participant's socket carries a stream of instructions for a small machine. Not
a sequence of fixed records, not a text protocol, not something with a length
field a sender can lie about.

Each instruction begins with an **opcode**, one byte, which indexes a dispatch
table. An opcode with no row in the table is not a malformed command -- it is not
a command at all, and the socket closes. There is nothing to explain to a sender
who is not speaking the language.

### Bitflags say which operands are present

After the opcode comes a **flag word**. Each bit stands for one operand, and the
operands follow **in bit order, low to high**. The decoder walks the set bits and
fills a slot per bit.

This buys four things at once:

**The instruction's length is derivable rather than declared.** Nobody sends a
length. The flags say what is present, each present operand has a fixed width, and
the total follows. A sender cannot claim an instruction is longer than it is,
because a sender never gets to claim anything about length.

**Absent operands cost nothing.** A command that does not need a destination does
not carry four bytes of zeroes.

**Two encoders producing the same command produce the same bytes.** Canonical bit
order means there is one encoding, which matters because the stream is the replay.

**The decoder is a loop over bits.** Not a switch, not a parser. Walk the set bits
of a word; for each, copy a known number of bytes into a known slot.

### Every value is recorded as it is decoded

Each operand is written to the command log at the moment it is decoded, before
anything acts on it. The log is what a replay reads back. This is why decoding and
executing are separate steps rather than one: a value that was recorded and then
refused is still part of the record, and a log of what people *tried* to do is the
most direct evidence available about where the interface is confusing.

## Pre-sized containers, and why there is nothing to validate

The decoder writes into a **register file**: a fixed set of slots, allocated once
at startup, reused by every instruction. Nothing allocates during decode. There is
no variable-length destination anywhere in the receive path.

Each slot has a width, and here is the part that matters:

> **The values a slot accepts are exactly the values its bits can hold. Anything
> outside that range is not rejected -- it is inexpressible.**

A slot holding an angle is sixteen bits, and all 65,536 patterns are legal angles,
because a full turn is 65,536. There is no such thing as an out-of-range angle. A
slot holding a movement direction is eight bits and every pattern means a
direction. **The format makes the invalid unrepresentable**, which is a stronger
guarantee than checking for it, because a check can be forgotten and a bit width
cannot.

Where a client's intent lands between two representable values -- it wants to face
somewhere finer than the angle grid allows -- the value **rounds to the nearest
representable one**. That is not a fallback and does not need to be reported: it is
what a fixed-width field *is*, the same way storing a position rounds it to the
nearest thousandth of a metre. Quantisation is the representation, not an error
being swallowed.

### The exception, which is real: references

The rule above holds for *values*. It does not hold for *references*.

A slot holding "which thing" is a 32-bit index. Every bit pattern is a legal
`uint32_t`, and most of them point past the end of the things array. That is a
genuinely invalid input and it is **refused**, never clamped -- clamping an index
would silently redirect a command onto whichever body happened to be last, which
is exactly the class of bug this whole design exists to prevent.

So: **value fields cannot be wrong; reference fields are checked.** Two rules, and
which one applies is a property of the slot, written in the slot's definition
rather than remembered by whoever writes the handler.

## The verbs

A dispatch table, not a switch. Adding a command is adding a row: an opcode, a
flag layout, a validator, and a handler.

| Opcode | Style | What it does |
| --- | --- | --- |
| `DRIVE` | `DRIVEN` | Set a body's intended direction and facing. What a held key becomes -- not "move one step" but "I am pushing this way", cleared when the key lifts. |
| `ORDER_MOVE` | `ORDERED` | Send a body toward a point. It walks there over subsequent ticks. |
| `ORDER_FACE` | `ORDERED` | Turn a body to look at a point. |
| `ORDER_STOP` | `ORDERED` | Cancel standing orders. |
| `INTERACT` | both | Act on a thing within reach. What "act on" means is the ruleset's. |
| `RULES_ACTION` | both | Opaque to the server. Forwarded to the ruleset with the sender's scope attached. Every game-specific thing arrives through this one opcode. |
| `EDIT_WORLD` | -- | Move a wall, place a thing, redraw a region. Requires `MAY_EDIT_WORLD`. |
| `SAY` | -- | Text. Routed by the same visibility rules as everything else, which is why it is a command and not a side channel. |
| `RETIER` | -- | Change a sprite's quality tier, mid-session. Changes nothing in the world; comes through this door anyway. See [the sprite studio](017-the-sprite-studio.md). |

## The gauntlet

Decoding produced a well-formed instruction in the register file. Now it has to
earn the right to happen. Same order every time, cheapest and most fundamental
first.

1. **Is the scope yours?** The scope's `viewer` must be the participant this
   socket belongs to. One integer comparison, and it is the load-bearing
   permission check in the entire system.
2. **Is the reference in range?** Every reference slot, against its array's count.
3. **Is the subject inside that scope?** A list scope: is the index in the slice.
   A region scope: does the thing's region resolve, through the parent chain, to
   the scope's region.
4. **Does the verb suit the style?** `DRIVE` from an `ORDERED` scope is refused.
5. **Does the ruleset permit it?** The last gate, and the only one that can say
   anything about the game. Where "it is not your turn" lives, and "you are
   paralysed", and "that is out of range". The server has no opinion on any of
   these and does not need one.

All five refuse in words. Only the decoder closes sockets, and only for things
that are not our language at all.

### Refusals are sentences, and that is the teaching mechanism

A refused command comes back as text a person can read: what was refused, and what
would have been required. Never a silent drop, never a numeric code, never a
command that appears to work and quietly does not.

This is not politeness. **Nobody reads a rules screen.** The refusal is where a
person finds out that their character cannot see round that corner, that this
goblin belongs to the forest and not to them, that the door is barred. If the
refusal is silence, the only way to learn the rules is to be told them by somebody
who already knows, and the program has failed at the one moment it was in a
position to teach.

## The stream is the replay

Every decoded instruction is recorded with the tick it arrived on. A snapshot plus
the instructions that followed reproduces the session exactly -- which is true only
because [the tick](004-the-world-and-its-tick.md) is deterministic, and the tick is
deterministic only because of the fixed-point and buffer-then-resolve decisions
made there.

Because the encoding is canonical, the log is also comparable: two runs that
should have produced the same commands can be diffed byte for byte rather than
interpreted.

## Read next

- [The rules layer](011-the-rules-layer.md) -- gate 5, and where `RULES_ACTION`
  ends up.
- [The dynamic picture](012-the-dynamic-picture.md) -- where `DRIVE` comes from.
