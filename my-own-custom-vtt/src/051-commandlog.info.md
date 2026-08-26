# 051-commandlog

Everything anybody asked for, in order, **including the parts they regretted**.

A snapshot plus the commands that followed it reproduces a session exactly — true
only because the tick is deterministic.

## Not an append-only stream of bytes

Deliberately. A retcon — restore the head of a turn, change one command, replay
forward — needs a record that can be indexed by turn, read back, altered, and
replayed. So commands are stored **decoded**, as the values they became rather
than the bytes they arrived as.

| Function | Purpose |
| --- | --- |
| `log_init` / `log_release` | |
| `log_begin_turn` | Records where a turn's commands start, so finding a head is a lookup, not a scan back through hours of a session. |
| `log_record` | Called at decode time, **before** the gauntlet, so a refusal is logged with its reason rather than being absent. |
| `log_mark_refused` | |
| `log_turn_first` / `log_turn_count` | |
| `log_rewrite` | **This is what a retcon is.** |
| `command_apply` | The dispatch table. Returns a refusal reason. |
| `refusal_sentence` / `verb_name` | |
| `log_refused_count` / `log_dump` | For a demo. |

## Refusals are kept

A log that quietly drops them cannot answer "why did nothing happen when I
pressed that", which is the most direct evidence there is about where an
interface confuses people.

## The verbs

`VERB_DRIVE`, `VERB_ORDER_MOVE`, `VERB_ORDER_FACE`, `VERB_ORDER_STOP` — a
dispatch table, not a switch. Adding a command is adding a row. Phase 4 gives
these opcodes on a wire; here they arrive already decoded.

## The gauntlet, so far

Verb in range, then **subject is a real index**. A reference is the one kind of
field that *can* be wrong — every bit pattern is a legal `uint32_t` and most point
past the end of the array — so it is refused, never clamped. Clamping an index
would aim a command at whichever body happened to be last.

The scope and membership gates are missing because scopes do not exist until
phase 6. What is here is the shape they slot into.

## Every refusal is a sentence

Never a number, never silence, never a command that appears to work and quietly
does not. **Nobody reads a rules screen** — a refusal is where somebody finds out
what the rules are, at the moment they try.

Including the refusal nobody wrote a sentence for, which says so and calls itself
a bug.
