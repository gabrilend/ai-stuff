# datapath — the record

What a reading leaves behind, and why it is shaped the way it is.

## Why append-only

A reading is expensive — thousands of small inferences across several
machines — and it is not reproducible. The same model at the same
temperature will not return the same mirror twice, and the cluster will not
be in the same state. Whatever a reading produced is the only copy of that
reading there will ever be.

That makes the record the valuable artifact, not the program. It is
therefore written in the one way that cannot lose work: **appended, one
line at a time, flushed, never rewritten**. A reading that dies halfway
leaves a valid record of the half that finished. Nothing is held in memory
waiting for a clean finish, because there might not be one.

## Why checksum-chained

Append-only protects against losing work. The chain protects against
*silently altered* work — a truncated write, an edited line, two runs
interleaved into one file.

Each line carries a hash of its own content joined to the hash of the line
before it. Changing any line changes its hash, which changes every hash
after it, so tampering cannot be local. Verifying the whole file is one
pass, and it either matches to the last line or names the first line where
it stopped matching.

The hash is FNV-1a, 64-bit, written as 16 hex digits. It is chosen for
being about twenty lines of LuaJIT integer arithmetic with no dependency
and no C module to build. It is **not** cryptographic and the design does
not need it to be — the threat is corruption and confusion, not a forger.
This limit is stated in the format header so nobody later mistakes it for
a signature.

## The file

Plain text, one record per line, `.reading` extension, in
`output/readings/`. Line-oriented so it can be tailed while it is being
written, and so a partial last line is obviously partial.

Each line is:

    <hash> <kind> <json>

| Part | Type | Meaning |
|---|---|---|
| `hash` | 16 hex chars | FNV-1a of `previous_hash .. kind .. json` |
| `kind` | string, no spaces | what sort of line this is |
| `json` | one JSON object, no newlines | the payload |

Three kinds:

| Kind | Written when | Payload |
|---|---|---|
| `head` | once, first | the original text's own hash, its byte length, the depth budget, the roster of doors, the model names, the wall-clock start |
| `unit` | each time a unit finishes, on the way up | the unit's `id`, `rung`, `from`, `to`, `mirror`, `angle`, `by`, and how many milliseconds it took |
| `foot` | once, last | counts, total elapsed, and the hash of the last `unit` line |

The `head` line does **not** contain the original text. It contains the
text's hash and length. The text lives in `input/` where the person put it,
and the record points at it. Copying it in would double the storage of the
one thing that is already safe, and would let the two copies disagree.

A unit line carries `from` and `to` but not `text`, for the same reason:
the bytes are recoverable with `string.sub` on the original, and a record
that restates them can contradict them. The mirror *is* stored, because it
exists nowhere else.

## Reading it back

    verify(path) → true, count  |  nil, line_number, why

One pass, recomputing the chain. It does not load the original text and
does not need it, so a record can be checked on a machine that no longer
has the input.

    load(path, original_text) → reading

Rebuilds the tree of units in memory, filling each unit's `text` back in
from the original by its offsets. This is the only place text and record
are joined, and it checks the original's hash against the `head` line
first. A mismatched original is an **error**, not a warning — showing
mirrors beside the wrong text would be worse than showing nothing.

## What this buys downstream

- Views are cheap and infinitely re-runnable. Changing the HTML costs
  nothing; changing it today does not require the cluster.
- A reading can be tailed live. The terminal view can attach to a running
  reading and show pairs as they land, because a half-written record is a
  valid record.
- Two readings of the same text are diffable. Same offsets, same unit ids,
  different mirrors — so "what did the bigger model do differently" is a
  join on `id`, and that comparison is the point of having a cluster with
  unlike machines in it.

## Related

- `docs/datapath-the-ladder.md` — where units come from
- `docs/architecture.md` — the generation/viewing split this format is the seam of
