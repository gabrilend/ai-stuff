# Phase 13 — The world becomes solid

**Goal:** the world gets a third dimension, and visibility stops being computed.

**Status: designed, not built.** Nine issues, none started.

This phase exists because a question about how coarse the fog grid should be was
asked, and the answer was a redesign of the visual engine. Every step of that
redesign made the program smaller.

## The issues

| Issue | What it establishes |
| --- | --- |
| [1301 the world is an edge graph](1301-the-world-is-an-edge-graph.md) | A vertex, its connections, and a material on each. The edges are the model. |
| [1302 structures and elevation](1302-structures-and-elevation.md) | Nested built geometry, and the ground it sits on, neither owning the other. |
| [1303 visibility is one equation](1303-visibility-is-one-equation.md) | Authored reveal, per-class thresholds, and a closed form with a cache. |
| [1304 the reveal is a distance field](1304-the-reveal-is-a-distance-field.md) | A Dijkstra map, and why going round corners is the point. |
| [1305 the unseen is a surface](1305-the-unseen-is-a-surface.md) | A doorway shrouded in shadow, rather than a hole. |
| [1306 the passes are a sequence](1306-the-passes-are-a-sequence.md) | Thue–Morse, and what a beat means afterwards. |
| [1307 the third view](1307-the-third-view.md) | LuaJIT, 3D, same wire, no server change. |
| [1308 the question window](1308-the-question-window.md) | A key, the DM as gate, and an AI holding the DM's verbs. |
| [1309 the phase 13 demo](1309-the-phase-13-demo.md) | The capstone. |

## What the design already taught, before anything was built

**A cost problem can be a noun problem.** Raycasting terrain to the horizon came
out four orders of magnitude over budget. Three structural fixes were found and
costed — a hierarchy over the occluders, a hierarchy over the targets, a shadow
map — and then none of them were needed, because the question *should the
computer decide what is visible* had never been asked. Deciding it by hand made
the fast path unnecessary rather than achievable.

**A claim about a shrinking working set was wrong, and the correction was worth
more than the claim.** Fog bits are set and never cleared, so it looked as though
the set of things left to test must shrink. It does not: in a world large enough
to explore, the unseen stays nearly everything forever, and the vertices you keep
paying for are the ones just around a corner, refused a thousand times until the
tick the answer flips. **The cost lives at the frontier**, which is small and
local and moving no matter how big the world is.

**Two things were named badly and finding the right names moved the design.**
*Ambient occlusion* was a shading effect, not a visibility test; the thing meant
was frustum culling, with occlusion culling beside it. And the half-remembered
"roll down the hill map" was not half-remembered at all — a Dijkstra map is what
roguelike developers call it, and knowing that brought distance transforms, flow
fields and fast marching along with it.

**The tick table admitted a schedule without being asked.** The passes were made
data rather than control flow so that "does X happen before Y" is answered by
reading an array. That decision, made in phase 3 for legibility, is what makes a
non-periodic pass order expressible now without touching a single pass.

**Somebody wrote down the Thue–Morse sequence from intuition.** Asked for a
pattern of motion and intent, the order given was the first eight terms exactly —
the provably fairest order for taking turns, and cube-free, offered against a
pair of passes whose entire purpose is that outcomes resolve fairly. It was
described as *three-wise* before anyone looked it up.

**Question 2.1 died twice and came back three times.** How coarse the fog grid
should be dissolved when fog went per-vertex, dissolved again when fog became
authored, and returned as a single terrain decision serving the ground, the
reveal field, and footing. It is the same question wearing a different coat, and
it now belongs to the format that actually needs it.

## What is not decided

Seven questions, all live: [17.1 through 17.7](../docs/016-open-questions.md).
The two that block building rather than polishing are **who issues the notice
that ends "static"**, which is the whole difficulty of the caching scheme, and
**what a beat means once the passes are a sequence**.
