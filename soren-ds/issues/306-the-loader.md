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
                                  │
                                  └─→ ✦ and that is the program running

   there is no fourth step.
```

**Order matters, and only in one way.** An arrow may point at a station
declared further down the file, so no arrow can resolve until every
station exists. That is the whole reason placing and wiring are
separate, and the reason survives even though the machinery around it
is small: create everything, then connect everything.

**The port lines come last, and that is what starts it.** Writing a
fixed value into a port runs the ordinary readiness check on its
station (phase 2's 209). A station whose inputs are all fixed values is
ready the moment the last one lands, so the writes that finish building
the program are the writes that set it going. There is no separate
"run" call, no entry-station list, and nothing that has to be told
which stations go first.

### What the file supplies, and what it does not

| about a station | comes from |
|---|---|
| its name | the file |
| which box it runs | the file (as a name) |
| how it picks an exit | the file |
| how many inputs it has | **the catalogue** |
| how many bytes each input is | **the catalogue** |
| what type each input is | **the catalogue** |
| which call site to use | **the catalogue** |

The file cannot disagree with the C, because the file is never asked.

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
   text through its type's field table, or no source at all.
5. A test that a map whose arrows point at stations declared later
   loads correctly, since that is the only reason the passes exist.
6. A test that the same program built by calling the operations
   directly and by reading a file produces identical results.

## Open questions

- *Does the name table survive loading?* Writing a running program back
  out as a file needs names, and error messages need them more. Phase 2
  left this open at placement; it has to be answered here, and the
  answer is almost certainly yes at the cost of one pointer per
  station.
- *What happens to a load that fails halfway?* Stations placed before
  the failure are already in the table and cannot be removed — indices
  are positions. They are also unwired, so they cost nothing and never
  run. Whether that counts as "the load left nothing behind" is a
  question of wording, but the wording matters, because somebody will
  read it and expect an empty table.
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
