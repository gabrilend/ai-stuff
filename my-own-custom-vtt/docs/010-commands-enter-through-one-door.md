# Commands enter through one door

Everything a participant does arrives as a command, and every command travels the
same path into the world. There is one entry point, one validator, and one place
where a command becomes a change. This document describes that path.

The outbound direction had one rule. This direction has one too:

> **A command is a request. The server decides, and may refuse. A refusal is a
> sentence.**

## The command record

Commands arrive on the participant's private socket. The identity question is
therefore already answered before parsing begins -- see
[the door and the private port](003-the-door-and-the-private-port.md).

| Field | Type | Meaning |
| --- | --- | --- |
| `verb` | `uint16_t` | Which command. An index into the verb dispatch table; a value past its end is refused. |
| `scope` | `uint32_t` | Which of the sender's scopes this is issued under. |
| `subject` | `uint32_t` | Which thing it is about. `0` where the verb is not about a thing. |
| `ax`, `ay` | `int32_t` | Two general-purpose fixed-point arguments. A destination, a direction, a facing. What they mean is the verb's business. |
| `payload_length` | `uint16_t` | Bytes of variable payload following. Bounded; a length past the bound closes the socket rather than being clamped, because a length past the bound is not a mistake. |
| `payload` | `uint8_t[]` | Chat text, a ruleset action's arguments. Opaque to the intake pass. |

## The verbs

A dispatch table, not a switch. Adding a command is adding a row: a verb name, a
validator, and a handler.

| Verb | Style | What it does |
| --- | --- | --- |
| `DRIVE` | `DRIVEN` | Set a body's intended movement direction and facing. This is what a key held down becomes -- not "move one step", but "I am pushing this way", cleared when the key lifts. |
| `ORDER_MOVE` | `ORDERED` | Send a body toward a point. It walks there over subsequent ticks. |
| `ORDER_FACE` | `ORDERED` | Turn a body to look at a point. |
| `ORDER_STOP` | `ORDERED` | Cancel standing orders. |
| `INTERACT` | both | Act on a thing within reach -- open the door, pick up the cup. What "act on" means is the ruleset's. |
| `RULES_ACTION` | both | Wholly opaque to the server. Forwarded to the ruleset with the sender's scope attached. Every game-specific thing in the entire system arrives through this one verb. |
| `EDIT_WORLD` | -- | Move a wall, place a thing, redraw a region. Requires `MAY_EDIT_WORLD`. |
| `SAY` | -- | Text. Routed by the same visibility rules as everything else, which is why it is a command and not a side channel. |

## The gauntlet

Every command runs the same checks in the same order, cheapest and most
fundamental first, so that a malformed or malicious message is discarded before
anything expensive touches it.

1. **Well-formed?** Verb in range, payload length within bounds, record complete.
   A failure here closes the socket -- these are not user errors.
2. **Is the scope yours?** The scope's `viewer` field must be the participant this
   socket belongs to. This is a single integer comparison and it is the load-bearing
   permission check in the entire system.
3. **Is the subject inside that scope?** A list-membership scope: is the index in
   the slice. A region scope: does the thing's `region` field resolve, through the
   parent chain, to the scope's region.
4. **Does the verb suit the style?** `DRIVE` from an `ORDERED` scope is refused.
5. **Does the ruleset permit it?** The last gate, and the only one that can say
   anything about the game. It is where "it is not your turn" lives, and "you are
   paralysed", and "that is out of range". The server has no opinion on any of
   these and does not need one.

Gates 2 through 5 refuse in words. Gate 1 does not, because there is nobody
honest on the other end to explain anything to.

### Refusals are sentences, and that is the teaching mechanism

A refused command comes back as text a person can read: what was refused, and
what would have been required. Never a silent drop, never a numeric code, never a
command that appears to work and quietly does not.

This is not politeness. **Nobody reads a rules screen.** The refusal is where a
person finds out that their character cannot see around that corner, that this
goblin belongs to the forest and not to them, that the door is barred. If the
refusal is silence, the only way to learn the rules is to be told them by
somebody who already knows, and the program has failed at the one moment it was
in a position to teach.

The same standard applies to every validator in the project: name what was
missing and where, and never substitute a default.

## Commands are the replay

Every accepted command is written to a log with the tick number it was accepted
on. A snapshot of the world plus the commands that followed it reproduces the
session exactly -- which is true only because
[the tick](004-the-world-and-its-tick.md) is deterministic, and the tick is
deterministic only because of the fixed-point and buffer-then-resolve decisions
made there.

Refused commands are logged too, separately. A log of what people *tried* to do
and were told they could not is the most direct evidence available about where
the interface is confusing.

## Read next

- [The rules layer](011-the-rules-layer.md) -- gate 5, and where `RULES_ACTION`
  ends up.
- [The dynamic picture](012-the-dynamic-picture.md) -- where `DRIVE` comes from.
