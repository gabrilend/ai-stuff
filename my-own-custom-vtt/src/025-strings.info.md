# 025-strings

One append-only pool of bytes holding every name in the world. A name is a
`uint32_t` offset into it.

**What is in it:** region names, scope names, participant display names. That is
the list.

**What is not:** anything a ruleset owns. A creature has no name here — a
creature's name is the ruleset's business and never enters the world. Chat text
is not here either; it travels as a command payload and is never stored.

## The structure

| Field | Type | Meaning |
| --- | --- | --- |
| `data` | `uint8_t *` | Length-prefixed strings, back to back. |
| `used` | `uint32_t` | Bytes written, including the empty string at offset 0. |
| `capacity` | `uint32_t` | Bytes allocated. **Never changes after init.** |

Each string is a two-byte little-endian length followed by that many bytes.
Length-prefixed rather than null-terminated: a length is one read, where a
terminator is a scan, and a scan over bytes somebody else influenced is a scan
that can run off the end.

`STRING_NOTHING` is 0 and is a real, readable, zero-length string — not a special
case every reader has to know about.

## The functions

| Function | In | Out | Notes |
| --- | --- | --- | --- |
| `string_pool_init` | pool, capacity | 1 / 0 | Writes the empty string at offset 0. |
| `string_pool_release` | pool | — | |
| `string_pool_add` | pool, text, length | offset | Returns `STRING_NOTHING` when the name is too long or the pool is full. A caller must report what would not fit. |
| `string_pool_read` | pool, offset, `*length_out` | pointer | Not null-terminated. A bad offset reads as empty. |
| `string_pool_offset_is_valid` | pool, offset | 1 / 0 | For the validator, so nothing else has to ask. |

## Why it never grows

Growing would move the pool, and a caller holding a pointer from an earlier read
would be looking at freed memory. Rather than making every reader copy what it
reads, or making every caller remember a rule, the pool is simply large enough
from the start — which it can be, because the number of names in a world is known
when the world is loaded.

A full pool **refuses**. That surfaces the fact that the world claimed fewer
names than it has, which is worth knowing.

## Why nothing is ever truncated

`STRING_MAX_LENGTH` is 255, and a longer name is refused by name rather than cut
short. A silently truncated name looks right in one place and wrong in another,
and nobody ever finds out which. A fallback is a warning and a warning is an
error.
