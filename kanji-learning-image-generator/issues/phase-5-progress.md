# Phase 5 — The Museum

**Goal.** A picture can be asked for in the manner of a museum — or just one of
its halls — and the character is made of the things on display: bones,
specimens, crystals, plants, fish, working models, glowing orbs in a dark
planetarium.

It stands on phase 4's `416`, whose two routes (inside and outside) every hall
and museum is drawn through, and `415`, the kitchen that can run them.

## Issues

| | | Status |
|---|---|---|
| `501` | A museum is a place you can name | **open** — words only; which museum first is unanswered |
| `502` | What a vitrine holds | **open** — halls, including the planetarium |
| `503` | The case under the light | **open** — words first; drawn only if the pictures demand it |
| `504` | The pictures teach the look | **waiting** — no photographs yet, and no conditioning model on any kitchen |
| `505` | A visit to the museum | **open** — the capstone demo |

Counts: `luajit /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua
<project> -m`.

## Where the risk is

**The look and the shape pull against each other.** Every piece this phase adds
— a case, a backdrop, later photographs — is something the model can copy
instead of building the character. The answer chosen is to say as little as
possible, densely, and let the model express the rest.
