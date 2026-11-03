# 006 — Roadmap

Two phases. They are **clusters of functionality**, not a schedule: lower
numbers are more foundational, not earlier in time.

The vision says the data model matters most and the interface least, so the
order is: write the model down precisely, build the small tools that prove it
can be read the same way twice, try it on something real, and only then draw
pictures of it.

---

## Phase 1 — The model, and the tools that read it

The org map, the state file and the proposal written down exactly; a reader
that refuses a malformed file by naming the rule it breaks; the blocked board;
a proposal applied to a map as a diff, with acceptance computed from its lines;
and the monorepo this project lives in, written as an org map, so the board has
something real to rank.

Ends with: the blocked board run over the monorepo's own queue of pull
requests, naming which merge frees the most waiting work.

| Issue | |
| --- | --- |
| 101 | The model is written down |
| 102 | The map is read, and refused by name |
| 103 | The blocked board |
| 104 | A proposal is applied as a diff |
| 105 | The monorepo, mapped |
| 106 | A page anybody can open |

## Phase 2 — Maps of maps, and history

| Issue | |
| --- | --- |
| 201 | A map inside a box: an inner map's doors line up with its box's ports |
| 202 | The org's history, replayed: applied proposals in order rebuild the map |
| 203 | The trainstation picture: the vision's boxes-and-wires view, once the prototype is available |
| 204 | State crosses the wall: a fed port is fed inside, a finished inside makes its box done |

## Deliberately absent

- **A server, accounts, or a database.** The files live in a git repository;
  git already does identity, history and distribution.
- **JavaScript.** Views are generated pages. See [open questions](005-open-questions.md#q2--what-the-interface-looks-like).
- **Anything that compels a person.** The model shows; people decide.
