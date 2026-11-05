# 014-blit — info

The blit (issue 106, `docs/datapath-blit.md`, steps 2 and 3): a voice's
changes, found against its base by 104, written onto the shared canvas as it
is now.

1. **Removals.** An erased word is blanked only if the canvas, as the blit
   found it, still holds exactly that word at that place. Otherwise another
   voice changed it after this voice's base; it is left alone and counted as a
   conflict.
2. **Writes, in reading order.** The word's characters go into its cells.
   Each word the write reaches is found on the canvas as it is just before
   that write. A word that lost every letter is covered. A word that lost some
   is cut, and handed to the collision rule. So is a word directly touching
   the written word with no space between: it lost nothing, but would be glued
   on as one word (`lost` 0).

## Collision rules

`RULES` is a table from rule name to `function(grid, cut, write, report)`.
It is called after the write is in place, changes the grid, and returns what
it did. `cut.cells` is the set of the cut word's columns that the write took.

| Rule | Outcome | What it does |
|---|---|---|
| `blank-whole` (default) | `blanked` | every letter the write left becomes a space; no fragment is left |
| `keep-fragments` | `kept` | nothing; the letters stay, as a terminal leaves them |

`fade-fragments`, `push-aside`, `refuse-cut` and `blank-sentence` are each
their own issue once picked. `refuse-cut` will need the write undone, so the
contract may grow then.

## The report

| Field | What |
|---|---|
| `changed` | whether any cell differs from the current canvas; no new version when false |
| `written` | every cell written: row, column, the word |
| `blanked` | every cell blanked: row, column, the word it belonged to, and why (`removed` or `cut`) |
| `covered` | every word that lost all its letters, and the word that covered it |
| `cut` | every cut word: its place and text, letters lost, the word that cut it, and the rule's outcome |
| `conflicts` | every removal not applied |
| `counts` | `words-written`, `removals-applied`, `conflicts`, `words-covered`, and `cut-<outcome>` per outcome |
| `rule` | the rule used |

Marks (201) and the cut lines told to a voice (303) are made from this. The
blit itself doesn't mark. The current canvas isn't changed: a new record
comes back, with the same headers and marks.

| Name | Type | Meaning |
|---|---|---|
| `apply(current, found, rule)` | function | the new canvas and the report |
| `RULES`, `DEFAULT_RULE` | table, text | the rules, and `blank-whole` |

Tests: `015-test-blit.lua`.
