# 406 — Two ways of saying it is good

## Current behavior

Nothing has an opinion about any picture, including whether the illusion worked
at all — which is the one thing this whole project is specified on.

## Intended behavior

**A machine rates everything as it arrives. A person rates whatever they feel
like. Both write the same field, and the person wins.**

### The machine grader squints

`docs/007` Q1 asked whether *did the illusion work* can be measured, sketched an
answer, and left it open because it needed generated images to test against.
`404` produces them.

Shrink the rendering to thumbnail size, blur it, and correlate it against the
structure field that produced it. High correlation means the finished picture's
broad light and dark really did land where the strokes are.

**Both of its limits are known and neither is fatal:**

- it measures agreement with the *field*, not legibility as a *character* — a
  picture could correlate well and still be unreadable because two strokes
  merged
- it says nothing about the other failure, where the model painted the character
  onto a wall in the scene and scored beautifully

A grader wrong in known ways beats no grader, because it can be measured against
a person's ratings. A grader nobody has measured is not a grader, it is a
rumour.

### A person's grader is the gallery

Five buttons under each thumbnail. The gallery already shows every rendering at
the size the illusion is specified at, which is the size the judgement should be
made at.

**It reads finished files and nothing else.** It never reaches back into the
machinery that made them, because a grader with access to the generator's
internals is grading the intent rather than the result, and the result is the
only thing anybody else will ever see.

### They are two machines behind a dispatch key

Not a branch inside the rating code. A branch there sprouts a second branch and
then the two designs start borrowing each other's assumptions.

**Everything is machine-rated on arrival**, because if only a little is ever
looked at then the pool is overwhelmingly unrated and a floor of *tier 4 or
better* would exclude nearly all of it.

**The agreement rate is a by-product.** Wherever both a machine tier and a
person's tier exist for one rendering, that is a free measurement of how often
the machine agrees — continuously, from ordinary use, with no evaluation
exercise ever being run.

**The floor that stops it drifting.** A guaranteed fraction of renderings gets a
person's rating and the agreement rate is reported where it can be seen. Let a
person's ratings go rare and the apparatus converges smoothly on the *grader's*
taste, with nothing raised anywhere, and it is discovered months later by not
liking the output.

## Suggested implementation steps

1. **The correlation needs the rendering and the field at the same small size.**
   Both are already produced at thumbnail size; the field's thumbnail is already
   written beside every recipe.

2. **Calibrate the tiers against something.** A correlation is a number and a
   tier is one of five; where the cuts go should be set from the distribution
   over a real batch and the thing that measured it kept, as `strategems/037`
   argues.

3. **Test the grader on cases whose answer is known by construction**: the field
   correlated against itself must score at the top, and against a different
   character's field near the bottom. Those need no generated images and they
   check the arithmetic, which is the half that can be wrong quietly.

## Related

`docs/007` Q1 — the question this closes. `405` — where tiers live.
