# Issue 101: Progressive Smelter — Melt the Lowest First

**Phase**: 1 (the smelter ladder, which every hotter forge is built on)
**Status**: Open
**Created**: 2026-09-23
**Blocks**: `201-grow-a-gold-bar-sized-ruby.md`
**Related documents**: `notes/vision`

---

## Current Behavior

Nothing exists yet. The project is a vision and a skeleton.

## Intended Behavior

A smelter takes in scrap made of any mix of metals. It separates the scrap
by heating it in steps, from the lowest temperature to the highest. At each
step it lets out only what has just turned liquid and pours that off. The
solid remainder stays in the chamber and goes on to the next, hotter step.
No component is ever heated much past the point where it runs liquid, so
nothing is burned into slag that could have been recovered. Everything that
goes in comes out as something reusable: "never lost but fully
reconstituted."

Metalworkers have long done this on purpose. It is called **liquation**, or
**sweating**. Aluminium recyclers run "sweat furnaces" that hold scrap just
above aluminium's melting point, so the aluminium runs off and the iron
bolts and steel inserts stay behind, still solid. This issue generalises the
sweat furnace into a ladder of steps.

The ladder, approximately (pure metals, at normal air pressure):

| Step | Melts out | Melting point |
|---|---|---|
| 1 | tin, solders | ~183–232 °C |
| 2 | lead | 327 °C |
| 3 | zinc | 420 °C |
| 4 | aluminium, magnesium | ~650–660 °C |
| 5 | silver | 962 °C |
| 6 | gold | 1064 °C |
| 7 | copper | 1085 °C |
| 8 | iron and steel | ~1370–1538 °C |

The **first model** is the ladder itself. Each step is described by:

- **Hold temperature** — how hot the chamber stays during the step.
- **Hold time** — how long it stays there.
- **How liquid leaves** — for example a tilted hearth that drains out
  through a tap.
- **Where each output goes** — the named cup, mould or bin that receives it.

Each later model climbs higher and holds its temperature more tightly. The
ladder's top rung is a forge hot enough to fuse gemstone. The vision's
namesake, ruby, is aluminium oxide, which melts near 2050 °C. Synthetic ruby
has been grown by dripping molten aluminium oxide onto a seed crystal in an
oxygen-hydrogen flame since 1902 (the Verneuil process). So the ladder has a
real destination.

## Suggested Implementation Steps

1. **Material table.** Write a data file of materials: melting point,
   boiling point, whether the material oxidises in air, and what it is
   recovered as. Plastics, paint and coatings go in too, because they burn
   before any metal melts.
2. **Scrap description.** Define a data format for one piece of scrap: the
   materials in it, their proportions, and how they are joined (bolted,
   soldered, plated or alloyed).
3. **Simulated ladder.** Write the program that walks a piece of scrap up the
   ladder. At each step it reports what ran out, what stayed solid, and
   anything lost to burning or fumes. Keep the program that computes the
   ladder separate from the program that displays it, per house rules.
4. **Report losses loudly.** Any material heated far past its own step is
   flagged. That is the "1000 degrees damages the weaker materials" case
   from the vision.
5. **Phase 1 demo.** Feed a few real scrap mixes through the ladder, for
   example a copper-wound motor with an iron core and an aluminium housing.
   Show the recovery percentage for each material at each step.

## Things the model must not get wrong

- **Alloys do not separate by melting.** Brass (copper and zinc) and solder
  (tin and lead) melt across a range of temperatures, and the metals come
  out still mixed. The ladder separates materials that are *joined*, not
  materials that are *dissolved* in each other. Pulling an alloy apart is a
  later rung that needs chemistry, not just heat.
- **Zinc boils at 907 °C.** Heating brass or galvanised steel past that
  point releases zinc vapour. Zinc fumes cause metal fume fever. Lead and
  cadmium fumes are worse.
- **Copper does not melt at 1000 °C** (it melts at 1085 °C). In the vision's
  iron-with-copper-inside example, what 1000 °C damages is everything with
  a lower melting point that is still in the chamber: tin, lead, zinc,
  aluminium, plastics. That is exactly why those must already have been
  drained off at their own steps.

## Answered questions (2026-09-23)

- **Simulation, physical build, or both?** "ideally, blueprint". The
  deliverable is a buildable blueprint, in the manner of
  six-sided-dice-layer-cake. The ladder program in step 3 serves the
  blueprint: it computes the hold temperatures, times and recoveries the
  drawings state, so no figure in them is typed by hand. The later goals
  are issues 201 (a ruby the size and shape of a gold bar) and 301 (ruby
  bricks).

## Open questions

- **What happens to what cannot be recovered?** Slag, oxides, and the ash of
  burned coatings are all inputs to some other process. Where on the ladder,
  or outside it, do they go?
- **Is a gem the only goal at the top of the ladder?** "Forge gemstones"
  could mean growing synthetic crystals (heat alone is enough for ruby and
  sapphire), or also diamond. Diamond needs enormous pressure as well as
  heat, which is a different machine.
- **Is ruby-castle related?** It is the other ruby project in the
  repository, whose vision is a castle of coloured ruby brick. Could its
  bricks be this forge's product?
