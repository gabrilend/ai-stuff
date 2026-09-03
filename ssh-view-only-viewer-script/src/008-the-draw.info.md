# 008-the-draw.lua

Hands out one file at a time, at random, from a folder someone decided to
lend. Knows nothing about who is asking or what happens to the answer.

Returned by `dofile` as a table of four functions.

## draw.is_under(root, path)

Answers whether `path` genuinely lives beneath `root`, after both are
resolved through the filesystem. **This is the security boundary of the
project** — everything else is convenience.

| | type | meaning |
|---|---|---|
| in `root` | string | the folder being lent; trailing slash optional |
| in `path` | string | the path being tested |
| out | boolean | true only if path is a real thing strictly inside root |

Answers **false** for: a sibling directory whose name merely starts with
the root's name; anything reached by climbing out with `..`; a symlink
whose target is outside; the root itself; and any path that does not
exist. A path is guilty until proven inside — anything that cannot be
resolved is refused rather than assumed.

## draw.build_roll(corpus_root)

Walks the corpus once and returns the candidates, plus anything that
tried to escape.

| | type | meaning |
|---|---|---|
| in `corpus_root` | string | folder to walk |
| out 1 | array of entry | the candidates |
| out 2 | array of string | paths found inside that resolve outside |

An **entry** is a table:

| field | type | meaning |
|---|---|---|
| `path` | string | absolute, resolved, guaranteed under the root |
| `size` | integer | bytes |
| `drawn` | integer | times handed out, all viewers; starts at 0 |
| `last` | integer | unix seconds of last draw; starts at 0 |

Raises an error if the corpus root does not exist. The second return
value is not an error condition — it is the list of symlinks pointing out
of the corpus, reported so a boundary being probed is visible rather than
silent.

## draw.pick(roll, held, ceiling)

Chooses one entry for one viewer, or explains why it cannot.

| | type | meaning |
|---|---|---|
| in `roll` | array of entry | from build_roll |
| in `held` | map of path→true | what this viewer already received |
| in `ceiling` | integer | max times any file may go out, all viewers |
| out 1 | entry or nil | the choice |
| out 2 | string | present only when out 1 is nil: the reason |

Returning nil is a **correct outcome**, not a failure. It means the well
ran dry, and the caller should tell the viewer so rather than retry. Two
reasons occur: `"the corpus is empty"` and `"this viewer has seen
everything the corpus will lend"`.

Randomness comes from `/dev/urandom`, not from a clock seed — two viewers
served in the same second must not receive the same file.

## draw.stamp(entry, held, now)

Records that an entry went to a viewer. Call this **before** telling the
caller which file they got, so a caller that dies mid-delivery cannot ask
again and be handed the same file.

| | type | meaning |
|---|---|---|
| in `entry` | entry | the chosen one, mutated in place |
| in `held` | map | the viewer's history, mutated in place |
| in `now` | integer | unix seconds |
| out | entry | the same entry, for chaining |

## Notes

- LuaJIT (5.1) syntax throughout.
- No fallbacks. Missing entropy, an unrunnable command, or an absent
  corpus root each raise an error rather than degrading.
- Never reads the contents of a file it names. A draw is a name.
- Tests live in `011-test-the-draw.lua`, run by `012-run-tests.sh`.
