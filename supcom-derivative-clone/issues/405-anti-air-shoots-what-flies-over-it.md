# 405 — Anti-air shoots what flies over it

| | |
| --- | --- |
| Phase | 4 — The Cloud |
| Blocked by | 205, 404 |
| Blocks | — |
| Reads | [the cloud](../docs/007-the-cloud.md) |
| Open questions | E2 |

## Current behavior

Nothing shoots a plane. The aim pass from issue 205 picks targets for every
reloaded unit among the enemies it can see, but which domains a weapon reaches
is not yet a fact the catalogue carries, so tanks would fire at helicopters and
guns at frigates. `tests/022-the-cloud.lua` asserts that an interceptor over
enemy ground is shot by a gun that has a sightline to it, and that a plane in
the cloud is not shot by anything.

## Intended behavior

An anti-air gun is a land unit whose weapon reaches the air. It shoots at any
plane it can **see**: an interceptor over its ground, a bomber on its run, a
scout passing over, a plane on its first flight to the cloud. It does not shoot
into the cloud, because the cloud is above every gun's sight — the working
ruling for E2 — and it does not shoot tanks, because its weapon does not reach
the ground.

**Reach is a catalogue fact.** Every kind carries a `reaches` field: an integer
bitmask over the domains, land, sea, and air as three bits. A tank reaches land
and sea; a frigate reaches land and sea; an anti-air gun reaches air only. The
aim pass filters candidates by testing the target's domain bit against the
shooter's reach, before it asks the sightline question, because the bit test is
cheaper than the walk.

**The cloud is out of sight by rule, not by geometry.** A plane whose mission is
`in-cloud` is excluded from every shooter's candidates. That is the cheap,
testable form of E2's ruling; if E2 is answered the other way, the exclusion
becomes a sightline test against `cloud_altitude` and nothing else moves.

Everything else is issue 205 unchanged: the sightline from the gun's eye to the
plane's profile at ground plus flight height, damage that falls with distance
along the gun's curve, a shot buffered to land later. A plane over a dune is
hidden from a gun in the next trough exactly as a tank would be, which is why
issue 404's defensive stations matter: friendly ground with guns on the crests
is a different thing from friendly ground with guns in the hollows.

## Suggested implementation steps

1. Add `reaches` (integer bitmask) to every row of the unit catalogue (issue
   202), and constants for the three bits beside the domain constants in
   `domains` (issue 203). The catalogue validator refuses a row whose reach is
   zero: a unit that reaches nothing is a unit with no weapon, and that is a
   different field.
2. In `targeting` (issue 205), give `aim_pass` a candidate filter: skip a row
   whose domain bit is not in the shooter's reach; skip a row whose mission is
   `in-cloud`. Comment both skips with what each path means.
3. Give the anti-air kind a falloff curve of its own in the catalogue; the
   vision says nothing about it, so it starts as the tank's.
4. Confirm the shot's arrival tick uses the three-dimensional distance — ground
   distance and the altitude difference — so a plane directly overhead is not
   at distance zero.
5. Write the two assertions in the test: seen over enemy ground and shot; in
   the cloud and not.
6. Update the companions of `targeting` and the catalogue.

## Related documents and tools

- [The cloud](../docs/007-the-cloud.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — nothing is out of range, choosing what to shoot
- [The dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md)
- `tests/022-the-cloud.lua`

## Still open

- E2: whether the cloud can be shot from below. Excluded by rule for now; a
  cloud that can be shelled is a different air war, because a team with the
  ground under it wins the sky.
- Whether a gun's reach should be one bitmask or two — what it can see and what
  it can hit are the same set today and may not stay so.
