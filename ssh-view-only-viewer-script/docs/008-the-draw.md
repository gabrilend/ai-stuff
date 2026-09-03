# The draw

The component both visions depend on. It answers one question — *give me
a file, at random, that I am allowed to lend* — and it knows nothing
about who is asking or what they will do with the answer.

## What it is made of

Three pieces of state, all of them files, all of them readable by a
person with `cat`.

**The corpus root** — one absolute path. Everything the draw may ever
return lives underneath it. This is a single string in the config, and it
is the entire security boundary of the project. A draw that can be
persuaded to return something outside this path is the only bug in this
system that matters.

**The roll** — the list of candidate files, built by walking the corpus
root once at startup. Each entry carries:

| field | type | meaning |
|---|---|---|
| `path` | string | absolute path, always under the corpus root |
| `size` | integer | bytes, from `stat` |
| `drawn` | integer | how many times this file has been handed out |
| `last` | integer | unix seconds of the most recent draw, or 0 |

**The ledger** — an append-only record of every draw ever made: when,
which file, and which viewer it went to. Written to the RAM tier
(`tmp/shared-memory/`) so it evaporates on reboot, because the project
promises to keep no logs. The ledger exists to answer *has this viewer
already seen this file*, not to answer *what has this viewer been
reading*. It is the difference between a bound and a record, and the
distinction is the reason it lives in RAM.

## How a draw happens

```
  request(viewer_name)
        |
        v
  [ filter the roll ]  <- drop entries this viewer already holds
        |                 drop entries above the repeat ceiling
        v
  [ pick uniformly ]   <- one index, from the survivors
        |
        v
  [ stamp the ledger ] <- viewer, path, timestamp
        |
        v
  return path
```

The filter is where the rate exposure from
[the overview](000-what-this-project-is.md) is answered. A **repeat
ceiling** caps how many times any single file may be drawn; a viewer who
deletes forever eventually exhausts the survivors and the draw returns
nothing rather than starting the corpus over. Running dry is the correct
behaviour, not a failure — it is the corpus saying *you have seen what
there was*.

Returning nothing must be distinguishable from failing. The draw returns
two values: a path, or `nil` plus a reason string. Callers are expected
to handle `nil` by telling the viewer the well ran dry, not by retrying.

## What it deliberately does not do

- **It does not copy.** It returns a path. Whoever asked decides whether
  to hard-link it into a jail or hand it to a mail daemon.
- **It does not read file contents.** Nothing is inspected, filtered by
  type, or previewed. A draw is a name, not a payload.
- **It does not know about viewers** beyond an opaque name string used
  for the already-seen filter. It cannot tell an SSH session from a mail
  contact, and must not learn to.

## Open questions

- **Does the roll rebuild?** Walking once at startup means files added to
  the corpus mid-run are invisible until restart. Watching the corpus
  with inotify would fix that and would also mean a file deleted from the
  corpus while loaned out becomes a dangling path. Not yet decided.
- **What is the repeat ceiling's default?** One draw per file per viewer
  is the strict reading. Unlimited is the generous one. The number
  chosen is the difference between "a sampler" and "a slow full copy".
- **Should the ledger survive a restart?** It lives in RAM, so it does
  not. That means a restart lets every viewer see everything again. If
  the ceiling is meant to hold across restarts, the ledger has to move to
  disk, and then the no-logs promise needs re-reading.
