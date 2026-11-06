# 002 — The org map

The data model, exactly. Everything else in this project — the validator, the
blocked board, the proposal tool, any view anybody builds — is a reader of what
this page defines, and **where a tool and this page disagree, this page is
right and the tool has a bug.**

Each rule has a code (`L3`, `M12`, `S2`, `P4`). The validator names the code
when it refuses a line, so a refusal can be looked up here.

## An org is a directory

```
corner-bakery/
├── org.map                      the structure; changes only by proposal
├── org.state                    what is fed and what is done; changes daily
└── proposals/
    ├── cy-takes-cleaning.proposal
    └── oven-money-from-takings.proposal
```

Three kinds of file, one grammar. `org.map` is required. `org.state` may be
absent, which means nothing is fed and nothing is done. `proposals/` may be
absent or empty.

**Why three files and not one.** The map and the state change at different
speeds and under different authority. Moving a wire changes who owes what to
whom, and needs the consent [the acceptance rules](003-how-a-change-is-accepted.md)
describe. Saying "the flour arrived" changes nothing about the organisation;
the person who was waiting for the flour just says so. Keeping them apart means
a diff of `org.map` is always a change to the organisation and never noise.

**Why plain text, line by line.** A change to the org *is* a diff. A format in
which one decision is one line means one decision is one line of a diff, which
a person can read in a pull request, in an email, or in a terminal, with tools
that already exist.

## The grammar every file shares

| Code | Rule |
| --- | --- |
| L1 | A file is UTF-8 text. Every line, the last included, ends with `\n`. |
| L2 | No tab and no carriage return anywhere. |
| L3 | No trailing space on any line. Whitespace nobody can see in a diff does not get to mean anything. |
| L4 | A line is exactly one of: **blank** (empty); a **comment** (optional spaces, then `#`, then anything); a **head** (a keyword at column 0); a **body line** (exactly two spaces, then a keyword). Any other indentation is refused. |
| L5 | A body line belongs to the nearest head line above it. A body line with no head above it is refused. Blank lines and comments do not end a block. |
| L6 | Fields are separated by one or more spaces. A **quoted** field begins and ends with `"`; inside it `\"` is a quote and `\\` a backslash, and nothing else is an escape. Quoted fields may hold spaces and `#`. An unterminated quote is refused. |
| L7 | A **name** matches `[a-z0-9][a-z0-9-]*` and is at most 64 characters. |
| L8 | A **date** is `YYYY-MM-DD` and a real calendar date. |
| L9 | A comment is a whole line. A `#` after a line's fields is a stray field like any other and is refused. |

**The first word of a line is always a keyword and, on a head, the second is
always a name.** That is soramech's rule and it is kept for soramech's reason:
no word is reserved, so a later version can add a keyword without taking a name
away from an org somebody already wrote. A box may be called `role` or `says`.

## `org.map`

### Heads

| Head | Means |
| --- | --- |
| `org NAME` | The organisation. Exactly one, and it is the first head in the file (M1). |
| `person NAME` | Somebody in the org. |
| `outside NAME` | A party outside the org that a door leads to or from: customers, a supplier, a river, the public. |
| `role NAME` | A box that is ongoing. |
| `work NAME` | A box that is finite and can be finished. |
| `rule KIND` | The acceptance rule for one kind of change. See [acceptance](003-how-a-change-is-accepted.md). |

### Body lines

| Under | Line | Means |
| --- | --- | --- |
| any but `rule` | `says "TEXT"` | One line of plain description. At most one per block. |
| `role`, `work` | `held-by PERSON` | PERSON answers for this box. One person per line, so adding a holder is one line of diff. |
| `role`, `work` | `in PORT - BOX.PORT ["NOTE"]` | This box needs PORT, and it comes from BOX's `out` port. A wire, from the consuming end. |
| `role`, `work` | `in PORT = "VALUE"` | This box needs PORT, and it is always satisfied by VALUE: a recipe, a standing agreement, a policy. A **fixed value**. |
| `role`, `work` | `in PORT $OUTSIDE ["NOTE"]` | This box needs PORT, and it comes from outside the org. A **door in**. |
| `role`, `work` | `out PORT - BOX.PORT ["NOTE"]` | This box produces PORT, and BOX's `in` port takes it. A wire, from the producing end. |
| `role`, `work` | `out PORT $OUTSIDE ["NOTE"]` | This box produces PORT, and it leaves the org to OUTSIDE. A **door out**. This is where an externality is written down. |
| `role`, `work` | `inside PATH` | This box's inside is another org, in the directory PATH. A map is a box. |
| `outside` | `spoken-for-by PERSON` | PERSON speaks for this outside party when a door to it changes. |
| `rule` | `approve affected all`, `approve affected N`, `approve affected P/Q` | How many of the people a change affects must approve it. |
| `rule` | `approve everyone all`, `approve everyone N`, `approve everyone P/Q` | How many of all the org's people must approve it. |
| `rule` | `approve others N` | At least N approvals from people the change does **not** affect. An outside eye. |
| `rule` | `waits DAYS` | The change may not be applied until DAYS whole days after it was opened. |

The NOTE on a wire or door is a description of what flows. It is free text and
is not compared between the two ends of a wire.

### Rules of the map

| Code | Rule |
| --- | --- |
| M1 | The first head is `org NAME`, and there is exactly one `org` head. |
| M2 | Heads are `org`, `person`, `outside`, `role`, `work`, `rule`. Nothing else. |
| M3 | A head is exactly two fields: the keyword and a name. |
| M4 | Org, person, outside, role and work names share **one namespace** and are unique in it. A person and a box with one name would make every line that names either one ambiguous to a reader. Rule names are unique among rules and are one of the seven [kinds of change](003-how-a-change-is-accepted.md#kinds-of-change). |
| M5 | A body line's keyword is one the table above allows under its head. |
| M6 | At most one `says` per block, holding exactly one quoted field. |
| M7 | `held-by` names a declared person, at most once per box. |
| M8 | `spoken-for-by` names a declared person, at most once per outside. |
| M9 | A box's `in` port names are unique within the box: **every need has exactly one source.** Two producers that could each satisfy a need are two ports, or a choice somebody makes by proposal. Otherwise "is this box blocked?" has no single answer. |
| M10 | An `out` port name may repeat with different destinations — that is fan-out, and it is free. An exact repeat of an `out` line is refused. |
| M11 | A wire names a declared `role` or `work` box. A box may wire to itself: a loop is not an error. |
| M12 | **Both ends.** For every `out P - B.Q` on box A, box B has exactly `in Q - A.P`; for every `in Q - A.P` on B, box A has `out P - B.Q`. Reading one box tells the whole truth about it, and a change to a wire is always two changed lines, one on each party's box. |
| M13 | A door names a declared `outside`. |
| M14 | `inside PATH` is a relative path, resolved from the directory holding the map, to a directory holding an `org.map`. At most one per box. |
| M15 | A rule's lines are well-formed: N is a whole number, `P/Q` has `0 < P ≤ Q`, at most one `approve` line per subject (`affected`, `everyone`, `others`), at most one `waits`. `approve others` takes a number only. |

These are **warnings**, which the validator prints and does not refuse:

| Code | Warns about |
| --- | --- |
| W1 | A vacant box: a `role` or `work` with no `held-by`. Legal — it is a job nobody holds yet — but it is the first thing anybody should see. |
| W2 | A box with no ports at all. It needs nothing and gives nothing, so nothing on the map can tell whether it is happening. |
| W3 | An `outside` no door uses. |

## `org.state`

Head lines only; no bodies.

| Line | Means |
| --- | --- |
| `fed BOX.PORT DATE ["NOTE"]` | BOX's `in` port PORT has what it needs, as of DATE. |
| `done BOX DATE ["NOTE"]` | The work box BOX is finished, as of DATE. |

| Code | Rule |
| --- | --- |
| S1 | Heads are `fed` and `done`, and there are no body lines. |
| S2 | `fed` names an existing `in` port that is a wire or a door. A fixed-value port is always fed, and a second line saying so would be a second source of truth able to disagree with the first. |
| S3 | `done` names a `work` box. A role is never done. |
| S4 | No port is fed twice and no box is done twice. |

**Who writes a state line.** A `fed` line is written by a holder of the box that
was waiting: the one who is blocked is the one who knows whether the block has
lifted. A `done` line is written by a holder of the work box. The file format
cannot enforce authorship; the repository it lives in records who wrote each
line, and that is the enforcement.

Removing a `fed` line is how a port goes back to waiting: this week's flour is
used up. State is meant to churn.

## What the files mean

These are the definitions every tool computes the same way.

**Holders.** The holders of a box are the people its `held-by` lines name. A
box with none is **vacant**.

**Fed.** An `in` port is fed when any of these holds:

1. it is a fixed value;
2. `org.state` has a `fed` line for it;
3. it is a wire from a `work` box that `org.state` marks `done` — a finished
   piece of work has delivered everything it was going to deliver.

**Ready, blocked, done.** A `work` box marked done is **done**, and is neither
ready nor blocked. Otherwise a box is **ready** when every `in` port is fed, and
**blocked** when at least one is not. A box with no `in` ports is always ready.
A ready box is not necessarily *producing* — a vacant ready box has nobody to
act — which is exactly why [the board](004-what-blocked-means.md) shows both.

**The source of a waiting port.** Every `in` port that is not fed has exactly
one source (M9): the box at the other end of its wire, or the outside party
behind its door. There are no holes: a port with no source cannot be written.

## The bakery, read

[`examples/bakery/`](../examples/bakery/org.map) is the worked example.
Reading it with the definitions above:

- `cleaning` is **vacant** and has no `in` ports, so it is ready with nobody to
  act. Its one output feeds `baking.clean-bench`, which is not fed.
- So `baking` is **blocked**, though its flour arrived and its recipe is fixed.
- So `delivery` is **blocked** too: its loaves come from `baking`. `selling`
  is not, because yesterday's loaves are still on the shelf and somebody said so.
- `new-oven` is **blocked** on `books`, which is ready and has not delivered.
- `baking` washes flour paste into the city drain, a door to `drain`, and Dee
  speaks for the drain.

None of that was written as a status. All of it was read off ports.
