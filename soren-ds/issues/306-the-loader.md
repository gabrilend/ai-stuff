# 306 — The loader

## Current behavior

**A map file can be read into a description and nothing builds from
it.**

## Intended behavior

**The loader is a caller, not a mechanism.**

Phase 2 built one way to place a station, one way to configure a port,
and one way to draw a wire. The loader turns each line of a file into
one of those calls. It has no construction path of its own, which means
there is no state a file can reach that a person editing a running
program cannot, and no state a person can reach that a file cannot.

```
   1  every station line  ──→  place
   2  every arrow line    ──→  wire
   3  every port line     ──→  configure
   4  say the program is finished  ──→  bring up
                                          │
                                          └─→ ✦ running
```

**Order matters, and only in one way.** An arrow may point at a station
declared further down the file, so no arrow can resolve until every
station exists. That is the whole reason placing and wiring are
separate, and the reason survives even though the machinery around it
is small: create everything, then connect everything.

**The port lines are what actually starts things.** Writing a fixed value
into a port runs the ordinary readiness check on its station (phase 2's
209). A station whose inputs are all fixed values is ready the moment the
last one lands, so the writes that finish building the program are the
writes that set it going. There is no entry-station list and nothing that
has to be told which stations go first.

### The fourth step, which an earlier draft of this issue said did not exist

**A caller says when it has finished assembling, and that is a separate
act from loading.** An earlier draft of this issue ended at step 3 and
said so proudly. Two things in the design since then need a moment when
the whole program exists, and neither can be answered a line at a time:

- **The `$` numbering** (309). A gap or a repeat in the argument numbers,
  or in the result numbers, is only visible once every line has been
  read. Argument two with no argument one is a refusal, and nothing
  reading one line can see it.
- **Whatever can only be said about a whole program**: a station with
  queued inputs that no arrow feeds and no `$` mark, which will never run;
  a port with no source at all. These are **reported, not refused** —
  being able to sit in that state is what lets somebody at the touchscreen
  build a program a piece at a time.

**It is repeatable, and that is the point rather than a convenience.** A
station added to a running program is checked and started by the next
call; one already started is not started twice. So the same act serves
loading a file, finishing a hand-built program, and resuming after
somebody has edited a running one — which is the same reason the loader
has no construction path of its own.

**A caller that assembles by any route uses it.** Reading a file, calling
the operations by hand, or both in one program. The privileged
*still loading* state that only a loader could be in does not exist: there
is one repeatable call anybody may make.

### What the file supplies, and what it does not

| about a station | comes from |
|---|---|
| its name | the file |
| which box it runs | the file (as a file-and-function address, 305) |
| how it picks an exit | the file (the keyword starting the line) |
| how many inputs it has | **the catalogue** |
| how many bytes each input is | **the catalogue** |
| what type each input is | **the catalogue** |
| which call site to use | **the catalogue** |

The file cannot disagree with the C, because the file is never asked.

**What the file supplies is now an address rather than a bare name**, so
between the file and the catalogue sits one function that turns
`boxes/text.c:say` into the path of the file holding `say` — the
shortcuts applied to the first segment, the rest joined to the directory
the description lives in. There is exactly one of these because every
caller resolving an address has to agree with every other; the parent
project had two, and the symptom was a description that one accepted and
the other refused, naming a file it could not find.

**A misspelled box name is the most common error a map will have**, and
its message should be the best one in the system: the name as written,
and where box sources live.

**Wires are checked as they are drawn**, at the first moment both ends
are known, rather than in a sweep at the end. That is per arrow rather
than per program — which is what lets somebody drawing a wire on a
running device get the same check, from the same code, with the same
message.

The check is **one number against another**: both sides must count the
same bytes (303). Both type names go into the refusal, because the
widths alone do not tell anybody why they disagree.

## Suggested implementation steps

1. Pass one: each station line becomes a place call. Look the box up in
   the catalogue; refuse an unknown name with the message above.
2. A name table, built as stations are placed, used by pass two.
3. Pass two: each arrow resolves both ends by name, refuses a station
   that does not exist or a port the box does not have, type-checks,
   and draws the wire.
4. Pass three: each port line configures its port — a value read from
   text through its type's field table, a `$` mark, a starting depth, or
   no source at all.
5. **Bring-up**: the repeatable call that checks the `$` numbering,
   reports what can only be seen about a whole program, and starts
   everything that can start.
6. A test that a map whose arrows point at stations declared later
   loads correctly, since that is the only reason the passes exist.
7. A test that the same program built by calling the operations
   directly and by reading a file produces identical results.
8. A test that bringing up a program twice starts nothing twice, and that
   a station added between the two calls is started by the second.
9. A test that the two ends of every wire are compared, and that a file
   whose ends disagree is refused with all four kinds of disagreement
   collected rather than only the first.

## Open questions

- *Does the name table survive loading?* Writing a running program back
  out as a file needs names, and error messages need them more. Phase 2
  left this open at placement; it has to be answered here, and the
  answer is almost certainly yes at the cost of one pointer per
  station.
- *What happens to a load that fails halfway?* **The question changed
  shape**, because a station can now be removed and its place reused
  (207). It used to be a matter of wording — stations placed before the
  failure stayed in the table forever, unwired and harmless, and the
  honest phrasing was *the load left stations behind that will never
  run*. Now a failed load can genuinely undo itself: remove what it
  placed, in one act rather than a loop, and the table is as it was. The
  open part is whether it **should** — a half-loaded program is
  sometimes exactly what somebody editing at the touchscreen wants to
  look at, and an undo would take it away before they saw it. Undecided,
  and it is a question about what a person wants rather than about what
  the table can do.
- *Can two maps be loaded at once with the same station names?* There
  is one station table and one name table, so either names are unique
  across everything running, or the name table is scoped to something.
  This is the same question 213's parking asked from the other side,
  and both want one answer.

## Blocked by

302, 303, 305, and phase 2's construction operations.

## Blocks

307, 309, 312.

## Related

- [212 — Maps built by hand](212-maps-built-by-hand.md), the operations
  this calls
- [307 — Everything wrong with a map, said at once](307-everything-wrong-with-a-map-said-at-once.md)
- [305 — The map file](305-the-map-file.md), the input
