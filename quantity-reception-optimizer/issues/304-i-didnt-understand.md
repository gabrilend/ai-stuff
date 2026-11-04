# 304 — "I didn't understand"

## Current behavior

Nothing exists. Needs `302`, `303`.

## Intended behavior

**The host's side of the re-roll.** When a `reroll` message arrives for a
hover, the kind just shown is added to that hover's shown-kinds memory (`302`)
and the analogy datapath runs again. The new analogy comes from a kind not yet
shown.

When no drawable candidate is left in an unshown kind, the host answers
`exhausted` rather than repeating a kind or offering an undrawable count. The
panel says so plainly.

The reasoning step is also told which kinds were already shown and that they
did not help, so it can lean away from their neighbours (if vehicles didn't
land, machines may not either).

How the reader *asks* for a re-roll is `502`'s concern; this issue is
everything after the message arrives.

## Suggested implementation steps

1. The host gains a `reroll` handler.
2. The prompt from `303` gains a line listing kinds already shown.
3. Tests: repeated re-rolls on one fixture walk through distinct kinds and end
   in `exhausted`; a `reroll` for an unknown or already-left `hover_id` is an
   `error`, not a fresh start.

## Related

`docs/004-datapath-the-analogy.md` · needs `302`, `303` · blocks `305`, `502`
