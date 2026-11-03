# Issue 040c: Draw the Match with Plain Shapes

## Current Behavior
The game state runs a match (issue 040a), but draws only its test
pattern, so bases, shields, the turret, the reset and the winner can't be
seen.

## Intended Behavior
Once the tutorial ends, the match is drawn in plain shapes on black, with
shape as well as colour telling things apart, as the vision asks.

## Suggested Implementation Steps
1. Add a renderer that takes the graphics object to draw with, so its
   calls can be checked without a window.
2. Draw bases, shields, turret, shots, units, a reset banner and a victory
   message from the match's own state.
3. Have the game state draw the match instead of the test pattern once
   play starts.
4. Look at it in LÖVE, adjust, and only then move this issue to completed.

## Related Issues
- 040a-run-the-base-systems-in-a-match.md (completed)
- 045-add-mana-bar-ui-rendering.md (drawing done the same way)

## What Happened (so far; not yet seen on screen)

Built as `src/systems/match_renderer.lua` and called from
`GameState:draw` once the tutorial has ended (during the tutorial the test
pattern it explains is still drawn). `tests/test_match_renderer.lua`
checks the calls made to a recording stand-in for `love.graphics`: which
shapes, where, and which text. That shows the right things are asked for,
not how they look. LÖVE was not available, so **nobody has looked at this
yet**. This issue stays open until Ritz has run it and is happy with how it
looks.

### Decisions
- **Shapes:**
  - team 1's base is a square, team 2's a diamond;
  - standing shields are rings filled by health, and they flash yellow
    while vulnerable;
  - a fallen shield is an "x";
  - units are circles, triangles or squares by type, as `Unit.get_unit_shape`
    says.
- **Damage** dims the base's colour and is also written as its stage name
  under the base, so it doesn't rely on colour.
- **The turret's range** is a faint ring; its aim is a white barrel line
  with a yellow dot just after firing.
- **The reset** is a yellow banner naming the phase and the defending
  team, with one progress bar across all three phases. Units being
  removed are drawn faded.
- **Victory** is a dark band across the middle with the winner and
  "Press R for a new match".
