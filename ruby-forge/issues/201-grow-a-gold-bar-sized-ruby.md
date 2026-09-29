# Issue 201: Grow a Ruby the Size and Shape of a Gold Bar

**Phase**: 2 (corundum growth: the ladder's top rung, where the forge makes
gemstone)
**Status**: Open
**Created**: 2026-09-23
**Blocked by**: `101-progressive-smelter-melts-lowest-first.md` (the heat
ladder, its temperature control and its crucible materials)
**Blocks**: `301-ruby-shaped-like-bricks.md`
**Related documents**: `notes/vision`

---

## Current Behavior

Nothing exists yet. The goal is in the vision: "The ability to make rubies
the size and shape of gold bars is the intended goal." The deliverable is a
blueprint: drawings and figures a builder could work from, as in
six-sided-dice-layer-cake.

## Intended Behavior

A blueprint for a furnace that grows a single crystal of ruby in the shape of
a gold bar.

**What ruby is.** Ruby is corundum (aluminium oxide, Al₂O₃) with a little
chromium oxide (Cr₂O₃) in it, commonly around 0.5–2%. The chromium makes it
red. Without chromium the same crystal is colourless sapphire. Corundum melts
near 2050 °C.

**The shape to aim for.** An ordinary hand-sized cast ingot, the familiar
trapezoid that is wider at its base than its top, and gem-clear throughout.
The blueprint's first page fixes the exact dimensions.

**Three known routes to a crystal that large.** All of them are in
industrial use for sapphire. The blueprint compares them and chooses one.

| Method | How it works | What suits it | What's hard |
|---|---|---|---|
| **Edge-defined film-fed growth (EFG)** | Molten corundum rises by capillary action up a slot in a die. A crystal is pulled from the top of the film, and its cross-section copies the shape of the die's edge. | It grows a *shaped* cross-section directly: ribbons, tubes and rods are grown this way. A bar-shaped die gives a bar. | The die sits in the melt at over 2000 °C (usually molybdenum), and bubbles and chromium unevenness along the length are common. |
| **Kyropoulos** | A seed crystal touches the melt, and the crystal grows slowly down into the crucible as it cools. | It produces the largest sapphire crystals in industry, boules of hundreds of kilograms for LED substrates. | The result is a round boule, so the bar must be cut from it, and cutting corundum is slow diamond work. |
| **Verneuil (flame fusion)** | Powder falls through an oxygen–hydrogen flame and builds up, drop by drop, on a seed. | It is the oldest (1902) and cheapest way to grow ruby, and needs no crucible. | Its boules are small, a few centimetres, and strained. It is the right first experiment, but not the bar. |

**Materials and atmosphere.** Crucibles and dies for molten corundum are
molybdenum, tungsten or iridium. The first two burn in air at these
temperatures, so growth happens in vacuum or inert gas. The smelter ladder's
temperature control (issue 101) is the starting point, extended by about
500 °C beyond iron.

## Suggested Implementation Steps

1. **Fix the target.** Choose the bar size and draw it with dimensions and
   tolerances.
2. **Choose the route.** Compare EFG, Kyropoulos and Verneuil against the
   target on crystal size, shaping, equipment, energy and failure modes.
   Write down the choice and the reasons.
3. **First rung: a Verneuil burner.** Blueprint a small flame-fusion burner
   that grows a ruby boule a few centimetres across. It proves the chemistry
   (chromium content, colour) before the large furnace is built.
4. **The bar furnace.** Blueprint the chosen method's furnace: heating
   (induction or resistance), crucible or die, atmosphere, the pulling or
   cooling mechanism, and the temperature control inherited from the ladder.
5. **Annealing and finishing.** Specify the slow cool that relieves the
   crystal's internal stress, and the cutting and polishing that turn it
   into a bar.
6. **Phase 2 demo.** Show the blueprint's figures side by side, target bar
   against growable crystal. List every dimension given or derived, with
   none left unexplained.

## Answered questions (2026-09-23)

- **Which bar?** "I dunno, just like... the size of an ingot." The target
  is an ordinary hand-sized cast ingot: the familiar trapezoid, wider at the
  base than the top. It is well short of the 25 cm, 12 kg Good Delivery
  bar. Step 1 fixes exact figures, within the size range of ordinary 1 kg
  bars.
- **Must it be gem-clear?** "yes it must be gem clear." This narrows the
  route:
  - **Verneuil is ruled out for the bar.** Its boules are small and
    strained. It stays as the first-rung experiment for colour and
    chemistry.
  - **EFG is at a disadvantage.** Its shaped growth tends to trap bubbles
    and grow unevenly along the length.
  - **The leading route becomes Kyropoulos.** A large, slowly cooled,
    low-stress crystal is grown, and the ingot is cut from its clearest
    region. Cutting corundum is slow diamond work, but the result can be
    clear throughout.
  - Step 2's comparison still has to confirm this.

## Open questions
- **Where does the feedstock come from?** Does the aluminium oxide come from
  the smelter ladder? Aluminium recovered at step 4 could be oxidised into
  alumina, which would tie phase 1 to phase 2. Or is the powder bought?
- **The crystal's growth direction.** A ruby's colour changes with the angle
  it is viewed at (pleochroism: purplish-red one way, orange-red another).
  Which face of the ingot should show the deepest red? That decides how the
  ingot is oriented when it is cut from the crystal.
