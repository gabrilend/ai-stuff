# 906 — Phase 9 capstone demo: the packaging path, shown

> **Phase:** 9 — Platform & Packaging · **Capstone.**
> **Role in phase:** the deliverable demo that shows the whole platform-&-packaging
> path working, recombining earlier phases' tools with this phase's new ones. Per
> the roadmap's demo discipline, it lives in `issues/completed/demos/` and the
> project-root demo launcher gains one more selectable number.
> **Blocked by (within phase):** 901, 902, 903 (903a+903b), 904; **905 is
> explicitly optional** to the demo (experimental — shown only if it exists).

## Current Behavior

None of this exists yet. There is no Phase-9 demo and no project-root launcher
entry for it. A reader could not see the packaging path end to end, nor watch the
dual-mouse aim fall back to a gamepad, without reading source.

## Intended Behavior

A runnable demo (a simple bash script, `${DIR}`-honoring, in
`issues/completed/demos/`) shows the **platform & packaging** capability as a
visible, statistics-forward artifact — per the discipline that demos are part of
the deliverable, favor real datapoints over prose, and recombine prior phases'
tools with the new ones. It demonstrates, as concrete outputs rather than
descriptions:

- **The target profile & budget (901)** — run the hardware probe against a real
  Anbernic model (or its spec record) and show the derived performance budget as
  live numbers, so no figure in the demo is hardcoded.
- **The packaging pipeline (903a → 903b)** — run the bundler, show the bundle
  manifest, cross-build, and produce the installable artifact; show the **budget
  validator verdict** (fit / over-budget with reason) as the gate it is.
- **The input fallback (902)** — visibly demonstrate the signature two-mouse aim
  **degrading to a gamepad**: feed the same aim intent through Phase 2's layer from
  a two-mouse source and from a gamepad source, and show they drive the same
  in-game aim (ideally as a small visual, e.g. the boomstick hands moving under
  both). This is the recombination of Phase 1 (world), Phase 2 (input), Phase 3
  (a spell to aim) with Phase 9's new gamepad source.
- **The distribution spirit (904)** — display the gift/anti-commercial note that
  travels with the artifact.
- **The experimental branch (905)** — *if and only if* it has produced anything,
  show its software round-trip (bytes → tones → bytes) as a curiosity, clearly
  labelled experimental. If 905 is absent, the demo simply omits it.

The project-root demo launcher (the "pick a number 1–y" script) gains **9** as a
selectable entry that runs this demo. The demo should be re-runnable and should
prefer showing produced outputs (the artifact, the manifest, the budget numbers,
the two input sources driving one aim) over narration.

## Suggested Implementation Steps

1. Write the demo script in `issues/completed/demos/` (bash, hard-coded `${DIR}` +
   argument override, all paths relative; create the RAM-backed `tmp/` target if
   absent).
2. Have it run the **probe + budget derivation (901)** and print the live numbers.
3. Have it run the **pipeline (903)** end to end and surface the manifest, the
   artifact, and the **budget-validator verdict**.
4. Have it demonstrate the **input fallback (902)** by driving one aim intent from
   both a two-mouse source and a gamepad source through Phase 2's layer — visual if
   feasible.
5. Have it display the **distribution note (904)**.
6. Have it conditionally show the **905** round-trip only if that experiment exists.
7. Add **9** to the project-root demo launcher so `run` → 9 plays this demo.
8. Keep the demo statistics-forward and output-showing, not prose-heavy.

## Stats / Meta

- **Kind:** capstone demo (part of the deliverable, not just an artifact).
- **Recombines:** Phase 1 world + Phase 2 input + Phase 3 aim + Phase 9 gamepad/
  packaging tools.
- **Optional element:** 905 (shown only if the experiment produced something).
- **Launcher:** adds selectable entry **9**.

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — the
  whole path this demo makes visible.
- [roadmap.md](../docs/roadmap.md) — Bucket E; the demo-per-phase discipline and
  the project-root launcher.
- Issues **901, 902, 903 (903a/903b), 904, 905** — the tools this demo recombines.
