# 801 - The change set

| | |
|---|---|
| Phase | 8 - emission to the server |
| Blocked by | phase 3, which produces the facts being emitted |
| Blocks | every other emission issue |

## Current behaviour

The archive can be read and looked at. Nothing comes out of it in a form another
program can act on.

## Intended behaviour

The unit of emission: a description of what would change on a server, computed
before anything is written and readable on its own.

A change set answers one question - *what is the difference between what this
server currently believes and what the archive says was true at a chosen build*
- and it is computed for a chosen target era, not for the archive's newest
knowledge.

One entry per value that would move:

| Field | Type | Meaning |
|---|---|---|
| `entity_kind` | string | ability, item, creature, statistic |
| `entity_id` | integer | the identifier, valid in the target's era |
| `field` | string | which value moves |
| `from` | number or string | what the server has now |
| `to` | number or string | what it would become |
| `evidence_build` | integer | the build the new value was observed at |
| `evidence_source` | string | which registry entry claimed it |
| `dating` | string | stated, derived, or unknown - from issue 105 |
| `tier` | string | which application time this belongs to |

The `from` field is why a change set has to be computed against a live server
rather than generated blind. An emission that does not know the current value
cannot be reverted, cannot be reviewed, and cannot tell the difference between a
change and a no-op.

An entry whose `dating` is unknown is carried in the change set and marked, not
silently dropped. Whether to apply it is a judgement for the person reading it,
and hiding it would make that judgement impossible.

## Suggested implementation steps

1. Read the server's current values through its database, read-only, as a
   separate step from computing anything.
2. Walk the archive's fact records to the chosen build, applying each history
   entry in order, to get the archive's belief at that build.
3. Difference the two. Produce no entry where the values already agree - an
   emission that rewrites a value to itself makes every review harder and every
   diff longer.
4. Test on a server with a known hand-made deviation: the change set must
   contain exactly that deviation and nothing else.
