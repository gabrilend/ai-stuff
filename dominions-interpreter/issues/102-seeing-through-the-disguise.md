# 102 — Seeing through the disguise

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | every part of the project that opens a savegame |
| Blocked by | [101](101-the-input-gate.md) |
| Related docs | [file formats](../docs/dominions-file-formats.md) |

## Current behavior

Nothing in this project can read a Dominions file.

The scheme is already established, twice: by the **chronicler** project, which
lives inside the Dominions folder and version-controls savegames, and again
independently here against the same collection. Every byte of a save or
configuration file is exclusive-or-ed with a single constant. There is no key,
no rotation, no compression, and no variation between files or versions.

## Intended behavior

One module knows the constant. Nothing else in the project learns it, so that
if the game ever changes it the fix is one line and the phase 1 tests say so on
the next run.

### What it offers

| Question | Returns |
|---|---|
| What is the constant? | the number, for tests that want to assert it rather than trust a round trip |
| What do these bytes say? | the revealed bytes |
| What strings are in this region? | the readable ones, in order, with their offsets |

Revealing is its own inverse — the same operation hides — so there is one
function for both directions and round-tripping is a meaningful test.

### The two consequences, which are the whole difficulty

**A zero byte reveals as the constant.** Dominions stores strings
null-terminated, so after revealing, the constant is the separator between
every string. The string walk is therefore structural — split on the separator
— rather than a search for readable-looking runs. This matters: a search for
readable runs finds fragments of binary that happen to look like words, and a
fragment that looks like a name is worse than a name that was missed, because
the caller cannot tell it is wrong.

**A raw zero reveals as the capital letter `O`.** Padding and the letter O are
the same byte, and this is a genuine ambiguity rather than an untidiness. It
has already cost this project one wrong measurement: a scan for name-shaped
text swallowed three bytes of padding into every name and reported a record
stride three bytes short.

The module must resolve the ambiguity **explicitly**, must document which way,
and must be checkable. Resolving towards padding is right overwhelmingly often,
because the padding is always there and capital O's are not, at the cost of
clipping a name that genuinely contains one. That cost is bounded and checked
rather than hoped about: the game name read out of a savegame is compared
against the folder it was found in, across the whole collection, and a
disagreement is reported rather than believed.

Resolving the other way — treating only runs of two or more zeros as padding —
was tried in chronicler and is worse. It preserves capital O's and lets
stretches of binary through, which arrive silently attached to the front of
real names. That corrupts every name a little instead of one name a lot, and
does it invisibly.

### Offsets come back with the strings

Chronicler returned strings alone, because it only needed names. This project
needs to know **where** each string was found, because the record arrays are
located by measuring the distance between the names inside them, and because
the hand will later need to edit the bytes around one.

## Suggested implementation steps

1. Write the reveal as a lookup table built once at load, not a computation per
   byte — the survey runs this over a hundred files.
2. Comment the constant with what it is and how it was established. This is the
   most load-bearing dozen lines in the project.
3. Write the structural string walk: split on the separator, strip each chunk's
   leading binary and padding, reveal what remains, drop anything not wholly
   printable.
4. Return `{offset, text}` rather than text.
5. Take a starting offset. The header holds numeric fields and a plaintext
   signature that are not obfuscated, and walking them produces nonsense.
6. Take a minimum length. One-character fragments are never names.
7. Tests: the constant is what it is claimed to be; revealing twice is the
   identity; every started savegame in the collection yields a game name equal
   to its folder name; a file that is not a Dominions file is refused rather
   than revealed into noise.
8. Write the accompanying information file.

## Relevant files

- the local savegame collection, which is the test corpus
- chronicler's obfuscation module, as prior art worth reading before writing

## Notes

Credit where due: chronicler established this first, and its comments explaining
the padding ambiguity are better than most documentation. This project needs
offsets and record walking that chronicler deliberately never needed, which is
why the module is rewritten rather than borrowed.
