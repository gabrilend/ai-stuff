# 034-the-rules

The match's rules that are not a unit's: the beat, the claim, the sizes of the
queues.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

A catalogue table, read once when a world is allocated and copied into it as
`world.rule`. Seconds are written here because a person tunes in seconds, and
become ticks once through the tick's `ticks_of`. A change here is a balance
change and goes in the balance ledger with its reason.

## Exports

The file returns one table.

| Field | Type | Meaning |
| --- | --- | --- |
| `ticks_per_second` | integer | the beat (open question B4's working ruling) |
| `claim_seconds` | double | the claim counter's period |
| `claim_increments` | integer | claim increments of uninterrupted presence a claim takes (B6) |
| `commands` | integer | how many commands may wait in the queue at once |
| `refusals` | integer | how many refusals the ring keeps for a viewer |
| `units` | integer | the unit capacity of a world the headless runner allocates |
| `fingerprint_every` | integer | how often, in ticks, the snapshot row fingerprints the world; the replay log writes every fingerprint |

## Data structures it owns

Only the table above.
