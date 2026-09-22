# libs/transcript-repair-plan.lua

Decides what every archived transcript should be called and stamped. Carries
nothing out.

## What it is for

The shell driver `repair-transcript-timezone` knows how to find files, rename
them and talk to git. This knows which date each file deserves. Keeping the
two apart means a wrong judgement can be read in a report before it becomes a
wrong rename.

## Inputs and outputs

**Reads on standard input**, one candidate per line:

    <stored modification time, epoch seconds>  TAB  <full path>

The timestamp is supplied by the caller because Lua has no way to ask the
filesystem for one.

**Arguments:**

| flag | meaning |
| --- | --- |
| `--logs <file>` | one conversation id per line, for every session log still on disk |
| `--history <file>` | `session id`, `first prompt epoch`, `last prompt epoch`, tab separated |

**Writes on standard output**, one decision per line:

    dir  TAB  file  TAB  tier  TAB  destination  TAB  timestamp  TAB  action

| field | type | meaning |
| --- | --- | --- |
| dir | string | folder holding the file |
| file | string | its current name |
| tier | string | which evidence decided it: `rebuild`, `history`, `history-only`, `stamp`, `no-evidence` |
| destination | string | the name it should have; equal to `file` when it keeps it |
| timestamp | integer | epoch seconds to stamp onto it; `0` when nothing is to be done |
| action | string | `rename`, `stamp-only`, or `skip` |

Anything on the input list whose first line is not the transcript header is
dropped silently — those are word clouds, analytics and hand-written notes
sharing the folder, and they are not ours to move.

## The functions worth knowing

| function | takes | gives back |
| --- | --- | --- |
| `true_epoch_from_stamp` | a stored modification time | the instant the last message really happened at |
| `find_flattened_stamps` | one folder's files, the history | the set of timestamps that have been disproved |
| `decide_dates` | one file, all three lookups | its tier and its pair of instants |
| `span_basename` | two instants | `jul-3-26`, or `jul-3-26-through-jul-5-26` |
| `pick_slot` | folder, span, names already handed out | a free filename, bare or `_agent-N` |

`decide_dates` is the heart of it: the tiers are tried strongest first, and a
weaker one is only reached when every stronger one has nothing to say about
that file.

## Two details that are easy to get wrong

**Endpoints are sorted before a span is named.** Each tier draws on
independent witnesses, and two witnesses can contradict each other. A
filename reading "the 17th through the 16th" helps nobody, so the pair is put
in order first.

**Names handed out earlier in the same plan count as taken.** Nothing has
moved yet when a decision is made, so checking the filesystem alone would
hand the same name to two files. This is a situation a bulk rename creates
and a single rename never does.

## Related

- `repair-transcript-timezone` — the driver, and the fuller explanation of
  why a timestamp can be disproved
- `libs/conversation-parser.lua` — supplies the UTC-to-instant helper, so
  both the exporter and the repair reason about time identically
- `issues/018-date-range-transcript-naming.md` — the ticket
