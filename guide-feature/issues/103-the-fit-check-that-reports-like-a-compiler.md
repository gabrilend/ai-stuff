# 103 — The fit check that reports like a compiler

phase 1, the fit and the fade

## Current behavior

Nothing exists. The display box and the fit check are designed in
`docs/display-box.md`.

## Intended behavior

One shared module, used both by the page keeper (on arrival) and by the
thinker (before sending):

- **in**: a list of thought lines (strings) and a share (width and height,
  whole numbers);
- **out**: either "fits", or a list of problems, each a record of kind
  (`too-wide` or `too-many-lines`), line number (whole number), measured
  size and allowed size (whole numbers);
- **report**: a function that turns the list of problems into the text the
  language model is given, in the compiler-error style shown in
  `docs/display-box.md`: one line per problem, naming the line, its length
  and how far over it is, then one closing line restating the limits.

Width is counted in UTF-8 code points. Whether to count display columns
instead (for double-width characters) is open question 7 in
`docs/open-questions.md`. The counting is one function, so changing the
answer touches one place.

The module never trims. It only measures and reports.

The module also holds the box arithmetic from `docs/display-box.md`: from a
box, a voice count and a fading fraction, compute the fading rows and the
share, and refuse a box whose share is under one row or whose width is under
eight characters.

## Suggested implementation steps

1. Code-point counting over UTF-8 bytes (count bytes that are not
   continuation bytes, `10xxxxxx`).
2. The measure, the report, and the box arithmetic, each a separate
   function.
3. Tests: a fitting frame; one line over; too many lines; both at once;
   multi-byte characters at the exact width; boxes that are too small. The
   report text for each is checked word for word, since it is what the model
   reads.

## Related documents

- `docs/display-box.md`
- `docs/frame-format.md`, "Thoughts"

## Open questions

- Characters or display columns? (`docs/open-questions.md`, 7)

## Blocked by

None.

## Blocks

106, 107, 205, 405.
