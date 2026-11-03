# Phase 1 Progress — The model, and the tools that read it

**The goal:** the data model written down precisely enough that two tools agree,
and the small tools that prove it: a validator, the blocked board, and a
proposal applied as a diff with its acceptance computed from its lines.

**Ends with:** the blocked board run over the monorepo's own queue of pull
requests, naming which merge frees the most waiting work.

| Issue | | Status |
| --- | --- | --- |
| 101 | The model is written down | built |
| 102 | The map is read, and refused by name | built |
| 103 | The blocked board | built |
| 104 | A proposal is applied as a diff | built |
| 105 | The monorepo, mapped | built |
| 106 | A page anybody can open | built |

**Order:** 102 first (everything reads through it), then 103 and 104, then 105
and 106, which need the board.

**Blocking:** nothing outside the phase. The reading of soramech is a working
ruling (open question Q1); if the parent project differs, the format follows it.

**Demo:** `./run-phase-demo 1` — the bakery validated, its board, a proposal
judged and another applied, then the monorepo's queue ranked. In
`issues/completed/demos/phase-1-demo`.

**Phase 1 is complete.**
