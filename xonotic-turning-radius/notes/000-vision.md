# Vision — Xonotic Turning Radius

A laptop cannot play a first-person shooter the way a desktop can, and the reason
is not the screen or the processor. It is the hands.

On a desktop the mouse carries the whole burden of aiming: two axes, continuous,
with as much travel as the desk allows. Take the mouse away and the trackpad
substitutes badly — a trackpad has a hard edge, so every turn is a sequence of
strokes with a lift between them, and the lift is the moment you die. The obvious
repair is "put turning on the arrow keys," and that repair has been available in
every Quake-derived engine since 1996. It is not enough, and the reason it is not
enough is the shape of a laptop keyboard.

## The complaint, stated exactly

> "main problem is, there's no buttons for the thumb and pinky."

On a laptop the arrow cluster sits in the bottom-right corner, often
half-height, often crammed against the shift key. To reach it the right hand
leaves the home row entirely. Once it has left, the thumb has nothing under it
but the corner of the deck, and the pinky is doing the reaching rather than
resting. Two of the strongest and most independent digits on the hand go idle at
exactly the moment the hand needs the most from them.

So the project is not "bind turning to keys." It is: **give both hands a resting
position where all five digits have work, and make the keys behave enough like a
mouse that the loss is bearable.**

## The layout

The layout is mirrored. Each hand's middle finger owns one axis of a pair; the
index and ring fingers flank it with the other axis; the pinky takes a floor
action; the thumb takes the trigger.

```
        [e]                                  [i]
    [a][s][d][f]                  [h] [j] [k] [l] [;]
     ^   ^   ^  ^                  ^       ^   ^   ^
   pinky |   |  index            index   mid ring pinky
       ring  middle

                    [ space ]
                     thumb
```

| Key | Finger | Action |
|-----|--------|--------|
| `e` | left middle (up) | pan view up |
| `d` | left middle (home) | pan view down |
| `s` | left ring | strafe left |
| `f` | left index | strafe right |
| `a` | left pinky | crouch |
| `i` | right middle (up) | move forward |
| `k` | right middle (home) | move backward |
| `h` | right index | turn left |
| `l` | right ring | turn right |
| `;` | right pinky | jump |
| `space` | thumb | shoot |

The symmetry is the point. Left hand handles the body's *lateral* motion (strafe)
and the view's *vertical* motion (pitch). Right hand handles the body's
*longitudinal* motion (forward/back) and the view's *horizontal* motion (yaw).
Each middle finger rocks between two adjacent rows; each pinky rests on an outer
key it never has to leave home to reach.

`j` is deliberately skipped. It sits under the right index finger's home
position, which makes it the easiest key on that hand to hit by accident while
rocking between `h` and `k`. Leaving it unbound means a slip costs nothing.

## The turning mechanic

Keys are binary and a mouse is continuous, so a key-turn has to invent the
continuity the mouse gives for free. Three behaviors do that:

1. **Hold accelerates.** The longer a turn key is held, the faster the view
   sweeps. A brief hold is a small correction; a long hold is a full sweep. This
   is the key-equivalent of mouse acceleration — the same input, held longer,
   covers disproportionately more ground.

2. **Tap quantizes.** A press released before the acceleration ramp begins is a
   quarter turn — ninety degrees, snapped. This gives a laptop player something
   a mouse player does not have: an exact, repeatable turn. Corners and corridors
   in an arena shooter are largely right-angled, so a quarter turn is a genuinely
   useful primitive.

3. **Double-tap gestures.** Two taps within a short window mean something else
   entirely. The original intent, from the arrow-key sketch:
   - double *up* → a one-hundred-eighty degree turn (the "check behind me")
   - double *down* → crouch, latched, until the next jump

   Those gestures were specified against the arrow cluster and have not yet been
   re-assigned to the layout above. See the open questions.

## The mode switch

None of this should be the default. Xonotic's stock binds stay exactly as
shipped; the layout is an *option the player chooses*, expressed as a config
patch and as a single button in the input settings menu.

The button is a one-slot undo, and its label reports what it will do next:

- The button reads **"laptop mode."** Pressing it saves the current binds into a
  slot and writes the layout above. The label becomes **"return keybinds."**
- Pressing **"return keybinds"** restores the saved slot. The label goes back to
  **"laptop mode."**
- If the player edits *any* individual bind by hand, the label reverts to
  **"laptop mode"** — the saved slot is no longer a place they want to return to,
  because they have started building something of their own. Pressing the button
  then re-saves and re-applies.

The virtue of the one-slot design is that it never accumulates state a player has
to reason about. There is exactly one thing behind the button, and the label
always names it.

## What is not being forked

The Xonotic source is not being forked. The cloned tree is a disposable build
artifact, regenerated on demand; what is versioned here is a set of small,
reversible, anchored patch scripts that stamp the customization into a fresh
clone and peel it back off afterward. See the patch-system documentation for the
machinery.

## The words this started from

Preserved because they are the specification, and because the shape of the
thinking is worth keeping:

> "The patch should allow the user to pan the camera using the arrow keys, to
> enable laptop based play. with 'mouse acceleration' the longer they hold it, or
> if they tap it to quarter turn. double up is a 180, double down is toggle
> crouch until next jump. main problem is, there's no buttons for the thumb and
> pinky. better I think to put it on hjkl. or better, jikl! ah double spacebar...
> good enough?"

> "we should also configure the left hand to sit on fsed with the pinky on a."

## Open questions

This document is not finished, and neither is the design. The unanswered
questions are gathered in the open-questions document under `docs/` and are
worked through one at a time. A vision with stale questions in it is worse than
one with none, because the staleness reads as agreement.
