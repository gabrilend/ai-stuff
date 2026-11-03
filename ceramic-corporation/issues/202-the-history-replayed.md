# 202 — The org's history, replayed

| | |
| --- | --- |
| Phase | 2 — Maps of maps, and history |
| Blocked by | 104 |
| Blocks | — |
| Reads | [how a change is accepted](../docs/003-how-a-change-is-accepted.md) |

## Current behavior

Applied proposals keep an `applied` line, and nothing checks that they explain
the map.

## Intended behavior

Starting from a first map, applying every applied proposal in date order
reproduces today's `org.map` exactly. A map edited by hand, outside any
proposal, is then detectable — which is the point of an organisation where
every change is a diff somebody agreed to.
