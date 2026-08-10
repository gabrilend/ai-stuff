# 201 — The Laptop Bind File

**Phase:** 2 — The layout
**Blocked by:** 101 (needs the patch component to exist)
**Blocks:** 301 (the mode switch executes this file)

## Current behavior

Xonotic ships one keyboard layout, in a flat file of bind lines with no logic in
it. That layout assumes a mouse for aiming and puts movement on the left hand
only, leaving the right hand on the mouse and both the right thumb and right
pinky unemployed when there is no mouse to hold.

## Intended behavior

A second bind file, shipped alongside the stock one and never replacing it, that
implements the mirrored layout from the vision. Both hands rest; all ten digits
have work.

```
        [e]                                  [i]
    [a][s][d][f]                  [h] [j] [k] [l] [;]

                    [ space ]
```

Every action it needs is an existing engine command, so **this issue introduces
no code at all.** The mapping:

| Key | Action | Engine command |
|---|---|---|
| `i` / `k` | forward / backward | `+forward` / `+back` |
| `s` / `f` | strafe left / right | `+moveleft` / `+moveright` |
| `h` / `l` | turn left / right | `+left` / `+right` |
| `e` / `d` | pan view up / down | `+lookup` / `+lookdown` |
| `a` | crouch | `+crouch` |
| `;` | jump | `+jump` |
| `space` | shoot | `+fire` |

`j` is deliberately left unbound. It is the right index finger's home key and
therefore the easiest key on that hand to strike by accident while rocking
between the turn key and the movement keys, so a slip there should cost nothing.

### The displacements

Six of those keys already mean something in the stock layout, so the file cannot
merely add lines — it has to take keys away from their current commands. Five are
harmless reshuffles: strafe-left, walk-backward, strafe-right, the grappling
hook, and the server info panel all move or disappear.

The sixth is not harmless. **Stock Xonotic binds `k` to suicide**, and in this
layout `k` is the key you walk backward with. The resolution, decided rather than
defaulted: suicide fires on **three presses in a row**, so the key keeps its
meaning and gains a cost proportional to how much you should have to mean it.

That resolution has a conflict of its own — three presses of walk-backward is a
motion combat produces naturally — which is recorded in the open questions and is
not settled by this issue. **Until it is settled, this file leaves suicide
unbound**, which is the only choice that cannot kill a player by accident. The
triple-tap detector belongs to the phase that builds gesture recognition, and
wiring an unsafe intermediate state in the meantime would be worse than shipping
without the command.

### What this file must not do

It must not touch anything that is not part of the layout. Weapon selection, chat,
the scoreboard, the console and the menu keys all stay where they are. A player
switching to laptop mode is changing how they move and look, not learning a new
game.

## Suggested implementation steps

1. Generate a patch in the source tier that writes a new bind file into the game
   data tree. This patch creates a file rather than editing one, so its inverse
   is a deletion and its probe is a presence check — the simplest possible member
   of the component family, and therefore a good first exercise of the machine.
2. Begin the file by clearing every key the layout claims, so the result does not
   depend on what the player had bound before.
3. Write the layout as one line per key, grouped by hand and commented with the
   finger that rests on it, since the finger assignment is the design and the key
   name is only its consequence.
4. Leave the suicide command unbound, with a comment recording that this is
   pending the open question and not an oversight.
5. Verify the round trip: applying the patch adds the file, unapplying removes
   it, and the tree afterwards is byte-identical to upstream.

## Related documents

- `notes/000-vision.md` for the layout and the reasoning behind the mirroring.
- `docs/002-datapath-the-input-path.md` for the finding that every needed command
  already exists, and for the full list of displacements.
- `docs/001-open-questions.md` section G for the unresolved triple-tap conflict.

## Notes

This issue is worth doing early even though it is trivial, because it is the
smallest possible end-to-end exercise of the patch machine: a real change, to a
real upstream tree, that must round-trip exactly. If the machine cannot do this
one cleanly it cannot do any of the harder ones.
