# 002-narrator.lua

What the program says about itself.

Not the herald. The herald is phase 6 and writes prose about the game; this
writes about the program. Mixing them is how somebody listening to a story
hears a stack trace.

## Functions

| Function | Takes | Gives back |
|---|---|---|
| `open(scratch, name)` | the shared-memory directory, a run name | the log path; raises if it cannot open |
| `quiet(silent)` | a boolean | nothing; stops echoing to the terminal |
| `say(sentence)` | a string | nothing — the ordinary level |
| `worry(sentence, reason)` | a string and a **required** reason | nothing; raises if the reason is missing |
| `stop(sentence)` | a string | never returns; logs, then raises |
| `timer()` | — | a function returning elapsed seconds |
| `path()` | — | where the log is |
| `close()` | — | nothing |

## Behaviour worth knowing before changing anything

**Lines are sentences, not tagged fields.** These logs get read by somebody
trying to find out why a turn came out wrong, possibly through a screen reader,
possibly weeks later. A line that needs the codebase to interpret gets skipped.

**Every line is flushed.** The log is tailable while a session runs, and a
session killed halfway leaves everything up to that point.

**`worry` requires its reason.** Passing nothing is a programming error caught
at the call site rather than an empty string written to a file. This level
carries the house rule that makes it worth having: a fallback is a warning, and
a warning is an error. Any path that substitutes a default announces itself
here, by name, every time.

**Timing is wall clock, not processor time.** Processor time is the wrong
quantity the moment anything waits on a socket, which is most of what this
program will do once three machines are involved.

**Everything lands in RAM**, under `tmp/shared-memory/`. Logs are ephemeral and
paying disk for them buys nothing.

## Related

- [issue 108](../issues/108-the-narrator.md)
