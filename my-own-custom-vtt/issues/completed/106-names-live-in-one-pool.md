# 106 -- Names live in one pool

**Phase:** 1, the world holds still
**Blocked by:** [102](102-the-world-is-flat-arrays.md)
**Blocks:** anything that has to be shown to a person by name.
**Documents:** [the world and its tick](../../docs/004-the-world-and-its-tick.md)

## Current behaviour

Nothing exists.

## Intended behaviour

One contiguous pool of bytes holding every string in the world, and a `uint32_t`
offset wherever a name is needed.

Strings in the world are rare and they never change: a region is called "The
Tavern" for the whole session, a scope is called "Aelfwine". So the pool is
append-only, has no free list, and needs no reference counting. Two records
naming the same string share an offset.

The pool exists rather than a `char *` in each record for the same reason
everything else is an index: a pointer cannot be written to a snapshot without
translation, and a snapshot that needs translation is a snapshot format that
knows the shape of every record type.

Strings are length-prefixed rather than null-terminated. A length is one read; a
null terminator is a scan, and a scan over attacker-influenced bytes is a scan
that can run off the end.

### What is and is not in here

**In:** region names, scope names, participant display names.

**Not in:** anything a ruleset owns. A ruleset's strings are the ruleset's
business, held in Lua, and never enter the world. A creature's name is not a
world concept -- see [a thing in the world](../../docs/005-a-thing-in-the-world.md),
which has no name field on purpose.

**Not in:** chat text. That travels as a command payload and is never stored in
the world. See [010](../../docs/010-commands-enter-through-one-door.md).

## Suggested implementation steps

1. Write the pool: append a string, get an offset; read a string at an offset,
   get a length and a pointer valid until the next append.
2. Make that last clause impossible to get wrong. A caller who holds the pointer
   across an append has a use-after-free when the pool grows. Either the read
   copies into a caller-supplied buffer, or the pool is preallocated to a hard
   maximum and refuses to grow. The second is simpler and fits the actual usage,
   since the number of names in a world is known at load.
3. Refuse rather than truncate. A name past the maximum length is an error that
   names the maximum, not a name silently cut short.
4. Write the companion `.info.md`.
5. Test: append, read back, two records sharing an offset, a name at exactly the
   maximum length, and a name one byte over.

## A note on why this is its own file

It is small enough to be folded into [102](102-the-world-is-flat-arrays.md) and it
is kept separate because the pool's rules are different from every other block's:
append-only, no index 0 sentinel, no destruction. Mixing two sets of rules in one
file is how the wrong one gets applied.
