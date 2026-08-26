# 076-describe

What somebody asked for, and the wall in front of it.

A description plus a seed is a few hundred bytes that name a whole dungeon
exactly — which is what lets a map be *referred to* rather than stored.

## The vocabulary, which is closed

| Word | Range | Default when absent | Means |
| --- | --- | --- | --- |
| `rooms` | 2–64 | 6 | how many rooms |
| `smallest` | 3–40 | 5 | the smallest room, in metres across |
| `largest` | 4–120 | 12 | the largest room |
| `loops` | 0–16 | 1 | connections beyond a bare tree |
| `lights` | 0–64 | 2 | how many rooms get a light |
| `name` | text | "somewhere" | what to call it |
| `require` | text, repeatable | — | a feature that must exist |

**And no others.** Not because completeness is unachievable, but because anything
generating descriptions will invent plausible neighbouring words that do not
exist, confidently and in good style. A short allowlist has nowhere for the
analogy to go.

The table in the `.c` is the **single place** a field's name, bounds, and default
live. The reader, the bounds check, the suggestions, and this documentation all
come from it — a vocabulary with two homes drifts, and the symptom is a
description one half accepts and the other rejects.

## A wall, not a net

- **Every error names the line, the word, and what was wrong.** "Invalid input"
  is not an error message, it is an apology.
- **Every error carries the nearest legal word** — but only when it is actually
  close. Suggesting `rooms` for `banana` sends somebody looking for a
  relationship that is not there.
- **All errors are reported together.** Stopping at the first turns fixing a
  description into one guess per run.
- **Nothing is quietly filled in.** An *absent* optional taking a documented
  default is vocabulary. A *malformed* field is a fault and never takes one.

That last distinction is the whole line between vocabulary and a fallback, and a
fallback is a warning, and a warning is an error.

## The parser is C, and was nearly Lua

Lua's only number type is a double, so any module touching its API needs an
exemption from the build's floating-point check. `073-rules` has one, earned. A
second exemption for a second module is how a ban stops being a ban — and what
Lua buys is expressiveness, which a closed vocabulary of scalar fields does not
want.

A description is **data**, not a program. A ruleset is a program, and that is why
it gets the exemption and this does not.
