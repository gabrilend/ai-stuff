# 1001 — Where the beat comes from

Produces `src/070-clock-generation.md`.

## Current behavior

Nothing. One point four gigahertz for the faces and one point two for the core are
used everywhere and generated nowhere.

## Intended behavior

**The reference, the multipliers, and the domains** — how many clocks this machine
has and where each is made.

### The domains

| domain | frequency | why not the same as its neighbour |
|---|---|---|
| face logic and engines | 1.4 GHz | set by `1005`'s critical path in the multiplier |
| core array | 1.2 GHz | set by `502`'s access time |
| radial link | derived from the face clock | source-synchronous; `702` forwards its own |
| port field | its own, from the standard adopted in `802` | must interoperate |
| auxiliary | slow, free-running | must tick when everything else is off |

Five, and the blueprint should argue whether the first two can be one. Running the
core at the face clock would need `502` to close a hundred and sixty-seven
picoseconds faster; running the faces at the core clock costs fourteen per cent of
the arithmetic. **Neither is obviously right** and the answer is `1005`'s to
supply, but the question belongs here.

### One reference or seven

A single crystal on the external loop's controller board, distributed to the cube,
and multiplied per domain inside — versus a reference per face.

One is right, and the reason is `1003`: six faces have to agree what cycle it is,
and six independent references would drift apart. But it makes the single
distribution path from outside the cube a single point of failure, so the
blueprint must say what happens when it stops, and `309`'s interlock is the model
to follow.

### Where the multipliers sit

Per face, on the interposer, close to what they feed. Their jitter adds directly to
`1005`'s budget, and their power is small but their **supply sensitivity is not**:
a multiplier on a rail that droops twenty-two millivolts under `404`'s load step
shifts frequency, which shows up as jitter exactly when the machine is busiest.
The blueprint must give them their own filtered supply and say why.

## Symbols this must publish

Reference frequency and stability. Multiplier ratio and output frequency per
domain. Jitter per domain, cycle-to-cycle and long-term. Multiplier supply
rejection requirement. Distribution path from outside the cube. Behaviour on
reference loss. Power per domain.

## Constraints this must assert

- Every domain frequency times its critical path from `1005` leaves the stated
  setup margin.
- Total jitter is within `1005`'s allocation.
- Multiplier supply rejection is sufficient at `404`'s worst droop.
- Reference loss is detected within a stated time and produces the same response
  as a coolant fault in `308`.

## Suggested implementation steps

1. List the domains and argue the face-versus-core merge with `1005`'s numbers.
2. Choose one reference and state the failure consequence.
3. Place the multipliers and specify their supply rejection against `404`.
4. Budget jitter and hand it to `1005`.

## Blocks

`1002`, `1003`, `1005`.

## Blocked by

`404`, `502`, `605`, `802`.

## Related documents

`006` for the droop this must reject.
