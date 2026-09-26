# 008 — Datapath: the update

> Feel free to request updates anytime, it can solve them instantly.
>
> yes yes that describes it almost completely, we will offer update grades as
> we go along

A person changes the design by writing a request into the case's `input/`.
The request is never applied to the code. It is located in the blueprint,
graded by how far its effect reaches, written into the blueprint as an
amendment, and then the part of the design it reaches is rebuilt.

```
  input/<request>  ──read first, every run──►  request-received
        │
        ▼
  locate turn: which issues does this request touch?  →  turns/…/touched (ids, one per line)
        │                                                  (or `new <phase>`: needs an issue that
        │                                                   does not exist yet)
        ▼
  the machine: reach = touched ∪ everything built on them       ◄── the graph (006)
               grade = surface | middle | foundation
        │
        ▼
  output/<request>.grade  — the grade, the touched issues, the reach, before anything is rebuilt
        │
        ├── grade at or above the case's hold setting → stop; the person runs `update` again with `--go`
        ▼
  amend turn: edit the touched issue files (and write new ones) — blueprint only
        │
        ▼
  re-check the blueprint (006): sections, graph, no cycles
        │
        ▼
  rebuild the reach, in waves (007)  →  request-done
```

## The grade

Decided by the machine from the graph, never by a model, so the same
request against the same blueprint always gets the same grade.

| Grade | When | Rebuilt |
|---|---|---|
| `surface` | every touched issue has nothing built on it | the touched issues |
| `middle` | some touched issue has others built on it, and the reach is under half the blueprint | the reach |
| `foundation` | some touched issue is in level 0, or the reach is half the blueprint or more | the reach, which is most of the design |

A request that needs a new issue (the locate turn answers `new`) is graded
by where the new issue will sit: an issue nothing builds on yet is surface.

The grades are the first draft of *update grades as we go along*. The rule
is kept in one table in the source so that when real updates show the lines
are in the wrong places, moving them is a one-row change, recorded in
`docs/balance-updates.md` with the reason.

## Holding

`case.lua` may carry `hold = "foundation"` (or `"middle"`, or `"none"`). A
request whose grade is at or above the hold stops after grading, with the
grade written to `output/`, until the person runs `update` with `--go`.
The default is `foundation`: the one grade that rebuilds most of the
design is shown before it starts.

## Order

When several requests are waiting, they are handled one at a time, never
merged, in the order [the center](009-datapath-the-center.md) puts them. Each
request's rebuild finishes before the next is located, because the next one
must be located against the blueprint as the last one left it.

| Decision | What each path leads to |
|---|---|
| The locate turn names an id that is not in the blueprint | A new locate turn, told which ids exist. Three failures stop the request, with the reason in `output/` |
| The amend turn writes outside `blueprint/issues/` | Breach ([005](005-datapath-the-hands.md)); the request stops |
| The amended blueprint fails its checks | A new amend turn, given the findings. Three failures stop the request, and the blueprint is put back as it was before the amend — the machine keeps a copy of each touched issue file in the turn folder before the amend turn starts |
| The rebuild fails | As for any build ([007](007-datapath-the-design.md)); the request is left open, not done |
