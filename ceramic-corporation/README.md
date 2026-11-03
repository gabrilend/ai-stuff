# ceramic-corporation

An organisation written down as a map of boxes and wires that everybody in it
can read. Anybody can see what is blocking. Anybody can propose a change to how
the organisation works, as a diff, the way a change to a program is a diff.
There is no executive, because a rule here cannot name a person.

Where it came from is in [the vision](notes/vision), in the author's own
words. How it works is in [the documents](docs/table-of-contents.md).

---

## The idea in one example

```
role baking
  says "turns flour into loaves"
  held-by ana
  in flour - buying.flour
  in recipe = "the house sourdough, seventy percent water"
  in clean-bench - cleaning.bench
  out loaves - selling.loaves
  out wash-water $drain "flour paste down the sink"
```

A **box** (here a role) is held by people, needs things through its `in`
ports, and produces things through its `out` ports. A **wire** joins an `out`
to an `in`, and is written at both ends. A `$` marks a **door** to somebody
outside the organisation — which is where externalities are written down.

A box is **blocked** when one of its `in` ports is not fed. Nobody sets that as
a status; it is read off the ports. The **blocked board** ranks every source of
waiting by how much depends on it, so the most useful next delivery is the top
line.

A change to the organisation is a **proposal**: lines removed from the map and
lines added. Who has to agree is computed from those lines — the holders of
every box the change touches — never from seniority, titles or who shouts.
Nobody can change your box without you; nobody has to keep depending on you
either.

## What is here

| | |
| --- | --- |
| [The org map](docs/002-the-org-map.md) | The data model, exactly. |
| [How a change is accepted](docs/003-how-a-change-is-accepted.md) | Proposals, and the vision's hard questions answered. |
| [What blocked means](docs/004-what-blocked-means.md) | The board. |
| [The bakery](examples/bakery/org.map) | A worked example. |

## Status

Phase 1 is under way: the model is written down; the tools that read it are
next. See [the roadmap](docs/006-roadmap.md) and
[phase 1's progress](issues/phase-1-progress.md).
