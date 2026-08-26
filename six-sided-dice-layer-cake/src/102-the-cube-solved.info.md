# 102-the-cube-solved — info

*Written by hand, not generated. `096` produces companions for blueprints; the
instruments have none, which is recorded in `009` as a gap.*

**The cube held as data** — phase 3 for what it answers, phase 14 for what it is.
Described by `304` and `305`.

## Why it exists

The notation in `002` holds named scalars and expressions over them. That is
enough for almost every question this project asks and not enough for three:

- **it cannot hold a list**, so the cube's twelve edges live as prose in `010`
  and as the number twelve in `023`, and nothing had ever checked the two agree
- **it cannot search**, so the question of which of the twelve coolant rails
  feeds which of the six faces — five hundred and twelve candidates — sat
  unanswered through the whole of phase 3
- **it cannot iterate**, so a cooling circuit with three flow regimes in it could
  only be estimated

This does all three, and the answers go back into `023` and `024` as `solved`
values that `095` re-runs on every pass.

## What it offers

| call | takes | gives back |
|---|---|---|
| `M.build_cube()` | nothing | the cube: eight corners with labels and parities, twelve edges with the axis each runs along, six faces with their corners, their four edges and their sieve index. All of it constructed from the definition of a cube, none of it typed in |
| `M.prove_bipartition(K)` | a cube | how many edges join corners of opposite parity, and how many join two of the same. Twelve and zero |
| `M.prove_tetrahedron(K)` | a cube | how many of the fed corners' six pairwise distances come to the face diagonal, and how many pairs there were |
| `M.check_document(K, dir)` | a cube and the project root | how many of the twelve edges written out in `010`'s prose match an edge of the built cube, and how many were written |
| `M.assignments(K)` | a cube | every arrangement of six plenum pairs onto twelve rails obeying all three rules, and how many were tried to find them |
| `M.perpendicular_pairs(K, plan)` | a cube and one arrangement | how many of the three opposite-face pairs run their channels perpendicular under it |
| `M.coefficients(L)` | a loaded ledger | the three pressure-loss coefficients of every kind of branch, worked out from the geometry the blueprints already fixed |
| `M.build_network(K, plan, C)` | a cube, an arrangement, coefficients | the hydraulic network: twenty-nine nodes, fifty branches, the injection at the inlet header |
| `M.solve_network(N, C)` | a network and its coefficients | pressure at every node, flow in every branch, how many passes it took, whether it settled, and the conservation residual as a share of the machine's flow |
| `M.solve(dir)` | the project root | all of the above, over every candidate arrangement, with the chosen one |
| `M.answers(dir)` | the project root | the fourteen values `023` and `024` declare as `solved`, as quantities with units |
| `M.report(R, out)` | a solve result | the whole thing in a page, for a person |

Run it directly — `luajit src/102-the-cube-solved.lua` — and it prints the report.

## The three coefficients

Every branch loses pressure as `dp = a*Q + b*Q^1.75 + c*Q^2`, and which of the
three terms is non-zero is what kind of thing the branch is.

| branch | `a` | `b` | `c` | why |
|---|---|---|---|---|
| microchannel field | yes | — | yes | laminar friction is linear in flow; the plenums at each end are fittings and go as the square |
| edge rail | — | yes | yes | turbulent on Blasius, whose friction factor falls as the quarter power of Reynolds, leaving one and three quarters; the rail ends are fittings |
| corner block | — | — | yes | a tee dividing three ways is a fitting and nothing else |

Nothing here is fitted to data and nothing is assumed. Narrow a rail in `016` and
the coefficient changes on the next run, the solve moves, and `095` reports the
copies in `023` and `024` as stale.

## The method, and why it is not Newton's

Newton's method was tried first and diverged, for a reason worth recording: the
tangent of a square-law branch at zero flow is zero, so its conductance is
infinite there. On the first pass every pressure in the network is still equal and
half the branches are carrying nothing, so half of them claim they will pass any
flow for no pressure at all. The first step is enormous, the pressures go
negative, and the run ends in numbers with forty digits in them.

The secant has no such singularity. Each pass computes the resistance `dp/Q` each
branch would have at its current flow, solves the resulting linear resistor
network exactly, and averages the new flows with the old. This is the linear
theory method, and it settles in about forty passes.

Two details are load-bearing and neither is obvious:

- **the flow floor.** Every branch carries the flow it was built for as a
  reference, and its resistance is evaluated at no less than a millionth of that.
  A branch carrying nothing has a small resistance rather than none.
- **convergence is measured on the pressures.** A perfectly balanced arrangement
  holds some rails at exactly zero flow, and a zero cannot be compared to itself
  in relative terms. Every pressure in the machine is a few thousand pascals and
  none of them is near zero.

## What it found that nobody expected

Sixty-four of the five hundred and twelve arrangements are legal. **Sixteen of
those distribute the coolant exactly evenly** between the six faces and the other
forty-eight leave one face five or six per cent short.

The sixteen are the ones where a single fed corner has all three of its supply
channels tapped and the other three fed corners have one each — the signature of a
hundred-and-twenty-degree rotation about a body diagonal, which is the symmetry
that carries each face of a cube onto another. The forty-eight spread the plenums
two and two, which looks more balanced and is not.

The sixteen split again on pump pressure by three and a half per cent, decided by
whether the threefold axis runs through a fed corner or a drained one. The cheaper
eight are reflections of one another and the enumeration order picks one, because
a builder needs a drawing rather than a symmetry class.

## Related

`010` for the frame and the twelve-edge list this checks. `023` for the parity
argument and the rail assignment. `024` for the network and what the solve
changed. `002` for the `solved` kind and the drift check. `1411` for why that kind
exists.
