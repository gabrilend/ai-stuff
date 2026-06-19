# Issue 016: Extract Palette to Data File

## Current Behavior
Color data is scattered throughout `compile-pdf-ai.lua` in three different forms,
all hardcoded inside Lua source:

1. The 40-entry Tier 3 background color table sits inside `generate_poem_color_from_theme`
   as a large literal table of `{r, g, b}` triples mapped by theme name.
2. Per-theme stroke and fill colors are inlined directly in each generator
   function as raw `hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.0, 1.0)` calls,
   with no name or central reference.
3. The `BACKGROUND_COLOR = {0.9, 0.7, 1.0}` mask color and similar one-off
   constants live near the top of the script.

This means rebalancing the visual language requires editing the script in
many places, with no single place to compare or audit the full color
inventory. Designers cannot tweak the palette without reading code, and
two themes that should share an accent color cannot easily do so.

## Intended Behavior
A standalone `themes/palette.lua` file holds the full color inventory as data:
- The 40 Tier 3 background colors keyed by theme name
- A set of named "accent" colors used by generators (e.g. `magenta`, `forest_green`,
  `dreamy_purple`) so generators reference colors by meaning rather than RGB triples
- The top-level mask color and similar one-off constants

`compile-pdf-ai.lua` requires the palette module once at startup and reads all
colors through it. No RGB triples remain inline in the script. Tweaking a color
becomes a single data edit, not a code edit, and the same accent color used in
multiple places stays consistent because it has one source of truth.

## Suggested Implementation Steps
1. Inventory every RGB triple currently inside `compile-pdf-ai.lua` (the Tier 3
   table, every `Page_SetRGBStroke` / `Page_SetRGBFill` call inside generators,
   and any top-level color constants). Group by semantic purpose.
2. Create `themes/palette.lua` that returns a table with two sub-tables:
   `tier3_backgrounds` (theme name → `{r, g, b}`) and `accents` (color name →
   `{r, g, b}`). Module returns the combined table.
3. In `compile-pdf-ai.lua`, replace `generate_poem_color_from_theme`'s inline
   table with a lookup into `palette.tier3_backgrounds`.
4. In each generator function, replace inline RGB calls with `palette.accents.X`
   lookups. Name the accents by what they evoke (`fish_blue`, `circuit_green`,
   `dreamy_purple`), not by code identifiers.
5. Add a top-of-file `palette = require "themes/palette"` to compile-pdf-ai.lua.
6. Confirm a full render produces visually identical output to before the move
   (this is purely a refactor — no color values should change in this issue).

## Related Documents
- `compile-pdf-ai.lua` — current host of all the inlined color data
- Source for the 40 Tier 3 entries: `generate_poem_color_from_theme` function
- Source for accent colors: every generator function in the
  "Art generation functions" section

## Metadata
- Priority: High (blocks Issue 019 which needs a coherent palette to work from)
- Complexity: Low
- Dependencies: none
- Estimated Effort: Small — pure refactor, no new behavior

## Implementation Notes
This is the foundational data-extraction pass that lets Issue 019 (new Tier 1
generators) and any future visual tuning work happen against a single auditable
file. The palette file should be readable as a color document, not as code —
each accent should have a short comment explaining what it's meant to evoke so
that future passes can substitute alternatives without losing intent.

If the same `{r, g, b}` triple appears twice in the source with the same
meaning, collapse it to a single accent. If it appears with different meanings,
keep both as distinct names — meaning is what the palette tracks, not raw color
identity.
