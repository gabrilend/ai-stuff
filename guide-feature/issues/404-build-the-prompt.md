# 404 — Build the prompt

phase 4, the thinkers

## Current behavior

Nothing exists.

## Intended behavior

The prompt builder: page record (202), the voice's own previous frame, the
excerpts (403) and the voice's name in, a conversation (list of turns, the
shape the backends take, 401) out, in the order given in
`docs/datapath-thinker.md` step 3.

The instructions are written in a text file in `input/`, not in code, so the
owner can change how the voices are spoken to without touching source. The
builder fills in the voice's name, the share width and height, and the page.

## Suggested implementation steps

1. The instruction template file and its fill-in markers.
2. The builder.
3. A test that prints the full prompt for a fixed page and seed, kept as a
   reference file, so any change to the prompt shows up as a diff.

## Related documents

- `docs/datapath-thinker.md`, step 3
- `docs/display-box.md`

## Open questions

- Should the voices be told who the others are, and what they are?
  (`docs/open-questions.md`, 14)

## Blocked by

202, 403.

## Blocks

405.
