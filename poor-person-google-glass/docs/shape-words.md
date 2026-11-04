<!-- Made by Claude (Opus 5.5), 2026-10-10, for issue 007a, as the contract for the describing language. src/012-the-shape-words.lua must know exactly these words; a test (src/017-the-word-tests.test.lua) checks they agree. -->
# The shape words

Every word a description may use. A description is plain sentences, one
fact each, ended by a full stop or a line end. Capitals don't matter, and
**a**, **an** and **the** are ignored (except inside "a third", "a quarter",
"a tenth", "a little", "one and a half times"). There are no measurements:
every size is said by comparing one part with another. The model comes out
measured in units where **a part of any kind with no size sentence is 1
wide** (the kinds' defaults below), so every size said is a multiple of that.

Run a description with `./describe input/descriptions/NAME.txt --view`.

## Parts and their kinds

A sentence `NAME is a KIND` (or `NAME is a COLOUR KIND`) names a part.
The name is every word before "is": "the left wheel is a disc" names "left
wheel". Afterwards a part can also be called by its kind, when it is the
only part of that kind: "the disc", "the disc shaped thing", "the
disc-shaped thing".

Every part has its own **axis** (upright unless a sentence turns it) and
three extents: **along** the axis, **across** it, and **deep** (the other
way across). Defaults, in units of the first part:

- `box` — along 1, across 1, deep 1
- `plate` — along 0.1, across 1, deep 1 (a thin box; thick means along)
- `cube` — 1 every way; all three always equal
- `cylinder` — along 1, across 1; across and deep always equal
- `disc` — along 0.2, across 1 (a short cylinder)
- `rod` — along 1, across 0.15 (a long cylinder; thick means across)
- `cone` — along 1, across 1, pointing along its axis
- `sphere` — 1 every way; all three always equal
- `ring` — across 1 (outside diameter), along 0.15 (how thick the ring
  is); its hole runs along its axis

Other words for the same kinds:

- `block` — box
- `slab` — plate
- `disk` — disc
- `ball` — sphere
- `torus` — ring
- `pole` — rod

A part with no size sentence keeps its kind's defaults (the report lists
it as an assumption).

## Colours

`NAME is COLOUR`, or the colour before the kind when naming it.

- `red`, `orange`, `yellow`, `green`, `teal`, `blue`, `purple`, `pink`
- `brown`, `black`, `grey`, `gray`, `white`, `silver`, `gold`, `metallic`

A part with no colour takes the next of: grey, teal, orange, purple,
yellow, green, pink, blue.

## Sizes

Measured words, each naming an extent:

- `tall`, `high`, `height`, `long`, `length` — along
- `wide`, `width`, `diameter` — across
- `deep`, `depth` — deep
- `thick`, `thickness` — the kind's thinnest extent (see the kinds)
- `large`, `big`, `size` — the part as a whole: its largest extent, its
  proportions kept

Sentence shapes:

- `NAME is as WIDE as OTHER` — equal
- `NAME is RATIO as WIDE as OTHER` — "twice as wide as the drum"
- `NAME is RATIO as LONG as OTHER is TALL` — comparing two different
  extents: "the handle is twice as long as the drum is tall"
- `NAME is RATIO as DEEP as it is WIDE` — one of a part's own extents
  measured by another of its own: "the lens is half as deep as it is
  wide". `it` is the part the sentence is about. The other extent is
  taken after every other size sentence about the part has been applied.
- `NAME is RATIO the size of OTHER` — the whole part
- `NAME is DEGREE COMPARATIVE than OTHER` — "slightly wider than the drum"

Ratios:

- `half` — 0.5
- `a_third` — 1/3 (written "a third")
- `a_quarter` — 0.25 (written "a quarter")
- `a_tenth` — 0.1 (written "a tenth")
- `twice` — 2
- `one_and_a_half_times` — 1.5 (written "one and a half times")
- `three_times` … `ten_times` — 3 to 10 (written "three times"):
  `four_times`, `five_times`, `six_times`, `seven_times`, `eight_times`,
  `nine_times`
- "N times", with N in digits, is also a ratio ("3 times as long as")

Comparatives, each with its extent and direction:

- `taller`, `longer`, `higher` — along, more; `shorter` — along, less
- `wider` — across, more; `narrower` — across, less
- `deeper` — deep, more; `shallower` — deep, less
- `thicker` — thinnest extent, more; `thinner` — less
- `larger`, `bigger` — whole part, more; `smaller` — less

How much more (degree words before a comparative):

- (none) — 1.5 times ("wider than" is half as wide again)
- `slightly`, `a_little` — 1.25 times (written "a little")
- `much` — 3 times
- `far` — 4 times

"Less" divides by the same amounts: "slightly narrower" is 1/1.25.

Extents that no sentence mentions keep the kind's proportions to those
that are mentioned (if two are mentioned, to their average scale). A
sentence about the whole part (`large`, `size`) and a sentence about one
extent of the same part cannot both be said: say one.

## Proportions

- `shaped_like` — "the cap is shaped like the drum": the other part's
  proportions, and its size unless a size sentence changes it
- `proportionally_scaled_to`, `scaled_to` — own proportions, with its
  largest extent equal to the other part's largest
- `same_size_as` — "the cap is the same size as the drum": the whole part,
  ratio 1

## Places

`NAME is PLACE OTHER` (or sits, rests, stands, hangs, lies). Faces touch;
the part is centred on the other in the directions not named.

- `on_top_of`, `on`, `above` — above
- `under`, `below`, `beneath`, `underneath` — below
- `to_left_of`, `left_of` — to the left
- `to_right_of`, `right_of`, `beside`, `next_to` — to the right
- `in_front_of` — toward the viewer
- `behind` — away from the viewer
- `inside`, `in_middle_of`, `at_centre_of`, `at_center_of` — the same middle
- `around` — the same middle and the same axis
- `through`, `passes_through`, `goes_through`, `runs_through` — the same
  middle and the same axis
- `at_end_of`, `at_far_end_of` — beyond the far end of the other's axis
- `at_other_end_of`, `at_near_end_of` — beyond the near end

The first part named that no sentence places sits at the middle of
everything. Every other part must be placed by a sentence; a part with no
place is refused, not put somewhere.

## Directions

- `stands_upright`, `is_upright`, `upright` — axis up and down (the default)
- `lies_left_to_right`, `lies_sideways` — axis left to right
- `lies_front_to_back`, `points_forward` — axis toward the viewer
- `faces_forward`, `faces_up`, `faces_sideways` — the same three, worded for
  flat things (plates, discs, rings), whose axis is the way they face: a
  panel that "faces forward" stands like a picture on a wall

## Aligning

- `aligned_with_rotational_axis_of`, `aligned_with_axis_of`,
  `aligned_with`, `shares_axis_with` — the same axis direction as the
  other part, and moved onto the other part's axis line (keeping its place
  along it). Can be said together with a place.

## Joining and small words

- `is`, `are`, `sits`, `rests`, `stands`, `hangs`, `lies` — join a part to
  what is said about it; all mean the same
- `as`, `than`, `of`, `there`, `called`, `shaped`, `thing` — small words
  the sentence shapes use
- `it` — the part the sentence is about (only in "as ... as it is ...")

`there is a KIND called NAME` also names a part.

## Refusals

A description that cannot be read is not drawn. Every problem is reported
at once, each with its line and, for an unknown word, the nearest known
word or part name. Two sentences fixing the same thing differently, and
parts that depend on each other in a circle, are refused with both lines.
