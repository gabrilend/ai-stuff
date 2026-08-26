# 046-two-ways-of-saying-it-is-good — info

A machine that squints at a picture, and a person who clicks a number.

For a general: `docs/007` asked, in the second phase, whether *did the illusion work* could be measured at all -- and left it open, because answering it needed generated pictures and there were none. There are now.

The machine's answer: shrink the finished picture to thumbnail size, blur it, and see how well its light and dark line up with the grey field that produced it. High agreement means the strokes really did land where they were asked to. That is the whole of it, and it works because thumbnail size is the size the illusion is specified at.

BOTH OF ITS LIMITS ARE REAL AND NEITHER IS FATAL. It measures agreement with the *field*, not legibility as a *character* -- a picture can agree closely and still be unreadable because two strokes merged. And it is blind to the other failure, where the model painted the character onto a wall in the scene and scored beautifully. A grader wrong in known ways beats no grader, because it can be measured against a person's ratings. A grader nobody has measured is not a grader, it is a rumour.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `046-two-ways-of-saying-it-is-good.lua` and
run the sweep again.*

## Invocation

```
luajit src/046-two-ways-of-saying-it-is-good.lua --calibrate
luajit src/046-two-ways-of-saying-it-is-good.lua --rate <file>=<tier> ...
```

## What it offers

| | |
|---|---|
| `M.squint(picture, field, settings)` | How much of the character survived into the picture, from zero to one. |
| `M.tier_for(agreement, settings)` | One number, as one of the five steps. |
| `M.grade(settings, picture_path, field_path)` | One picture, looked at. Returns the tier and the number behind it. |
| `M.rate_on_arrival(settings, companion_path, picture_path, field_path)` | Every picture gets a tier the moment it exists. |
| `M.apply_ratings(settings, given)` | A batch of ratings from a person, applied. |
| `M.anchored(settings)` | Whether a person's ratings are still frequent enough to mean anything. |
| `M.calibrate(settings, store)` | Where the cuts between tiers should sit. |

### `M.squint(picture, field, settings)`

How much of the character survived into the picture, from zero to one.

Both are shrunk to the size the illusion is specified at and softened, then compared value by value. The comparison is a correlation rather than a difference, because a picture that is uniformly brighter than the field has not failed at anything -- what matters is whether the light and dark move *together*, not whether they are the same numbers.

A negative correlation means the picture came out inverted with respect to the field, which is a failure and not a near miss, so it reports as nothing.

### `M.tier_for(agreement, settings)`

One number, as one of the five steps.

The cuts are in settings and are a starting position rather than a finding -- `--calibrate` is the thing that measures where they should be, kept for the reason `strategems/037` gives.

### `M.rate_on_arrival(settings, companion_path, picture_path, field_path)`

Every picture gets a tier the moment it exists.

WHY EVERYTHING, RATHER THAN WAITING FOR SOMEBODY. If everything made is kept and only a little is ever looked at, the pool is overwhelmingly unrated -- and a floor of "tier four or better" would exclude almost the whole library from the first day. Rating on arrival means floors work immediately, and a person's later correction simply wins.

### `M.apply_ratings(settings, given)`

A batch of ratings from a person, applied.

The gallery is a page on a filesystem and cannot write to the pool, which is deliberate -- it is a viewer, and a viewer that could reach back into the store would stop being one. So it collects clicks and hands back a line to run, and this is what runs it.

### `M.anchored(settings)`

Whether a person's ratings are still frequent enough to mean anything.

THE FLOOR THAT STOPS IT DRIFTING. A generator improved against a grader that is itself being tuned is a loop with no anchor. Let a person's ratings become rare and the whole apparatus converges smoothly on the *grader's* taste rather than theirs, with no error raised anywhere, and it is discovered months later by not liking the output.

### `M.calibrate(settings, store)`

Where the cuts between tiers should sit.

Two questions, and the second is the one that matters.

A field compared with itself must score at the very top, and with a different character's field near the bottom. Those need no generated pictures at all and they check the arithmetic, which is the half that can be wrong quietly.

Then, if there are real pictures in the pool, the distribution of what the machine actually scored -- because cuts chosen against no data are cuts somebody made up.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `032-a-gallery-you-can-page`, `035-test-the-machine`, `044-run-the-pictures`.
