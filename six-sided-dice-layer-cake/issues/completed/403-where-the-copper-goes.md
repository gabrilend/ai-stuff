# 403 — Where the copper goes

Produces `src/030-power-delivery-network.md`.

## Current behavior

**Done.** `src/030-power-delivery-network.md` exists, opening with the rule it
enforces: no current passes through a corner or along an edge. That keeps the
plumbing purely hydraulic and makes power purely radial.

**The via islands turned out not to be a problem.** The ticket expected them to
be the awkward level; at the supply voltage they carry a few amperes through
several hundred pads each, with three orders of magnitude of headroom. They are a
sealing problem and not an electrical one, and a constraint now says so.

The hard level is the regulator output: seventy amperes at three quarters of a
volt with twenty-two millivolts to spend, which is a third of a milliohm and
therefore an area problem that reaches back into the interposer thickness.

**Five volts or twelve is still open** (`009` entry P1), and it changes the
interposer, which changes the face, which changes the cube. **And the regulator
itself is nowhere specified**, which two other blueprints need.

## Intended behavior

**The physical conductor from the forty-eight volt input to the last transistor,
level by level, with a resistance for each level and an accumulated drop.**

### The rule this blueprint exists to enforce

**No current passes through a corner or an edge.** The corners are hydraulic and
the edges are hydraulic, and mixing water with a power plane in a sealed object
that cannot be opened is a decision nobody should be able to make by accident. The
blueprint should state it as a design rule at the top and every drawing should be
checkable against it.

The consequence is that power is purely radial: in at a face, outward-to-inward
through that face's own stack, and one sixth of the core's share continuing inward
through the radial interface.

### The levels

| level | conductor | carries |
|---|---|---|
| external | busbar or cable to the port field | 48 V, 6.6 A per face |
| port field | land array | same |
| through the cold plate | via islands from `202` | same |
| interposer planes | copper, glass core | 5 V after the first stage |
| regulator output | short, dense | 0.75 V at 307 A |
| microbump array | to the dies | same, divided by pad count |
| die power grid | upper metal | to the standard cells |
| radial interface | pillar array to the cage | 0.85 V, 51 A inward |

### The two hard levels

**The via islands.** Every ampere entering a face passes through sixteen small
holes in a water-cooled plate. `202` sized them for conductor count; this
blueprint must size them for current and for the heat those conductors themselves
make, which is deposited inside a channel field — the one place in the machine
where a resistive loss is also a thermal load in the coolant path.

**The regulator output.** Three hundred and seven amperes at three quarters of a
volt over a few millimetres. The allowed drop is about twenty-two millivolts,
which is two hundredths of a milliohm, which is an area problem rather than a
routing problem. This level sets how much of the interposer is copper and
therefore how thick it is, which feeds back into `014`'s stack and `012`'s face
thickness.

### The open question that belongs here

`009` entry P1: **five volts or twelve as the intermediate?** Twelve quarters the
current in the interposer planes and therefore the copper thickness, and makes the
second conversion ratio sixteen to one instead of six and a half, which costs
efficiency. The blueprint should price both and either decide or hand the decision
up with the numbers attached. It changes `014`, which changes `012`, which changes
the cube, so it should not be left open long.

## Symbols this must publish

Resistance per level. Accumulated IR drop to the worst-placed die and to the core.
Copper cross-section and thickness at each level. Via island current and self-heating.
Interposer plane count and thickness. The five-versus-twelve comparison as derived
numbers.

## Constraints this must assert

- Accumulated drop to the worst-placed load stays inside the domain's droop
  allowance from `402`.
- No conductor path crosses an edge rail or corner block. Checkable by enumeration
  over the drawing's named regions.
- Via island self-heating stays under a stated fraction of the local channel's
  capacity from `303`.
- Interposer thickness derived here matches the thickness `014` allotted.

## Suggested implementation steps

1. State the no-current-through-corners rule and make the drawings enumerable
   against it.
2. Work each level's resistance from geometry and `011`'s resistivity.
3. Do the worst-case accumulation, not the average.
4. Size the via islands for current and compute their self-heating.
5. Price five against twelve and put both in the record.

## Blocks

`404`, `405`, `406`, `1301`.

## Blocked by

`202`, `401`, `402`.

## Related documents

`006`. `009` entry P1.
