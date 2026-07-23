# 002 — Grid as graph

**Shape.** When two or more configurations of a system solve the same
underlying problems differently, render the problems as rows and the
configurations as columns. Each cell is a technique. An extra rightmost
column captures the intended re-convergence path. The grid is a tiny
graph; the table is its rendering.

**Origin in this project.** `docs/005-divergence-grid.md`. The grid
exists *before* the divergent code does, so a new divergence requires a
new row before a new branch.

**Where else it fits.**

- API contract design across clients: rows are operations, columns are
  client versions, cells are encoding choices.
- Migration plans across services: rows are data shapes, columns are
  service versions, cells are storage strategies.
- Test coverage maps: rows are features, columns are platforms, cells
  are test names.
- Cooking: rows are dish components, columns are dietary constraints
  (vegan, gluten-free, halal), cells are substitutions.

**Why it works.** A small grid is small enough to read at a glance.
Fractal expansion is visible as a row count climbing past a page. A
graph's edges are implicit when its vertices are arranged on a grid;
re-convergence is one of those edges.

**Where it breaks.** When configurations are not orthogonal — when one
column depends on another column's choices — the grid stops being a
grid. At that point, draw it as a real graph.
