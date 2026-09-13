# 021-inflows-and-outflows

Phase 3: mass from cells, four levels, energy lost with ground, the roster,
streaming construction, the cost ratios, lines and patterns, losing ground
costs bodies, thorns, improving territory.

## What it claims

- A tick of income is held cells times the pay per cell; no ground, no income.
- The menu has exactly four levels, splitting twelve engineers as none, four,
  eight, twelve; a fifth level is refused.
- A standing energy building pays; one on a lost cell pays nothing and is gone;
  one raised after a hydrocarbon find pays more.
- An engineer costs more than a builder in every resource and takes longer; the
  roster counts what was added and starts unhurt.
- One tick of construction draws a share of the cost, not the whole; a dry
  treasury stalls the draw on every resource; build power is builders plus
  engineers off energy.
- Land pays ten-to-one mass, air the reverse, sea and anti-air equal, tier two
  ten times tier one; the ratio table is exposed as data.
- Lines are a catalogue; a land pattern through water is refused naming the
  point; a pattern not starting at the factory is refused; there is no redraw;
  a stopped line keeps its pattern.
- Losing four percent hurts four of a hundred builders and one of twenty-five
  engineers, chosen by a named stream that repeats.
- Thorns hurt the taker of a flipped cell and are spent by it.
- An improvement costs both resources, raises the cell's pay, and is lost with
  the cell.

## Subjects it loads

`economy` (301, 303, 305, 311), `energy-menu` (302), `roster` (304, 309),
`cost-table` in assets (306), `factories` (307, 308), `commands` (108),
`thorns` (310), `units` (201), `timers` (106), `unit-catalogue` (202).

## World fields it touches

`world.team.{mass,energy,thorns}`, `world.cell.{owner,hydrocarbon,improvement}`,
`world.building.alive`, `world.factory.{line,running,pattern}`,
`world.flip.{count,cell,from,to,by}`, `world.rule.mass_per_cell`,
`world.field.{height,water_line}`.
