# 508 — Player Takeover & NCP Aiming

> Phase 5's capstone, and its most visceral moment: the player reaches into an NCP
> the AI was driving a second ago, takes the wheel, and **aims** — the two-mouse
> boomstick moving the same body, Phase-3 spells firing through the same aim path.
> "Anything that needs aiming, the user can aim, when they're playing as an NCP."
>
> Depends on 507 (the driver it displaces), 501 (the body it seizes), and Phases 2
> (input abstraction) and 3 (aimed spells). NCP = New Character Person; see
> [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. Autonomous NCPs (507) can walk, fight, and attempt puzzles
on their own, but the player is a spectator — there is no way to seize a body and
aim it, so the vision's "aim when playing as an NCP" is unfulfilled.

## Intended Behavior

A clean **takeover seam** that swaps who is driving a single NCP body, without the
downstream systems (movement, spells, aim) knowing or caring which source moved:

- **Take over / release.** On the player's command, the exploration driver (507)
  for one NCP is *paused* and the **Phase-2 input abstraction** is bound to that
  same body; on release, the driver resumes from the state it was paused in. The
  swap is the *only* thing that changes — the body, its stats, inventory, memory,
  and persona are continuous across it.
- **Aim, the same aim.** Aimed spells (Phase 3) fire through the **one shared aim
  path** — the "aim once, aim everywhere" strategem. Whether the aim vector came
  from the AI driver (507) or from the two-mouse boomstick (Phase 2), the routing
  into a Phase-3 spell is identical. Taking over does not open a *second* aiming
  system; it just changes what feeds the existing one.
- **Nothing else forks.** Combat, puzzle attempts, treasure pickup, and the
  companion voice all keep working under player control — the player *can* solve a
  puzzle by hand where the weak solver would have tried, and the same capability
  signal (506b) fires for what the body accomplishes. (Design note: whether a
  player-solved puzzle should signal differently than a weak-solver-solved one is a
  Phase-6 calibration question; emit an honest signal here and let 506b/Phase 6
  decide how to weight it.)

The whole issue is a *routing swap*, deliberately thin, because the value is in
what it does **not** duplicate: no parallel movement code, no parallel aiming, no
parallel spellcasting. It is the proof that "aim once, aim everywhere" held all the
way from Phase 2 through Phase 5.

## Suggested Implementation Steps

1. Confirm the **aim source seam**: both the autonomous driver (507) and the
   Phase-2 input abstraction must already feed aim through one shared path (they
   should, by 507's design). If they do not yet, unify them here first — a single
   aim-source input that Phase-3 spells read.
2. Write the **take-over operation**: given an NCP under autonomous control, pause
   its driver (preserving exploration state, 507) and bind the Phase-2 input as its
   aim/move source. Comment the pause/resume boundary with what each path preserves.
3. Write the **release operation**: unbind the player input and resume the driver
   from its preserved state, so the AI continues as if it had been thinking all
   along. Test that a pause→control→release cycle leaves exploration state coherent.
4. Route player-driven movement and aimed spells through the *existing* Phase-1
   movement and Phase-3 spell paths — assert (in a test or a loud comment) that no
   new movement/aim/spell code is introduced by takeover.
5. Ensure continuity: stats, inventory, memory, and persona are the same objects
   before, during, and after takeover — a test that reads them across a takeover and
   asserts identity.
6. Decide and document the control handshake (which input command takes over /
   releases) as run-configuration read from `input/` (role = player | ncp), not a
   hardcoded key.
7. Write the file's `.info.md`: take-over / release operations and the aim-source
   seam, as black boxes.

## Phase demo (deliverable, not just an artifact)

This capstone is the natural centerpiece of the **Phase 5 demo** that lands in
`issues/completed/demos/` when the phase's issues complete, and adds one selectable
number to the project-root demo launcher. Per the roadmap, the demo should recombine
earlier phases' tools with this phase's: show an NCP stamped from a template (501),
narrated by a grown, summarized persona (504/505), exploring a lair (507), attempting
a puzzle with the weak solver (506) and emitting a capability signal (506b) — then
let the viewer **press takeover and aim a Phase-3 spell by hand** (this issue), and
show the accumulated memory (502) that a later run would inherit. Favor a visible,
playable demonstration over description, and report live statistics (stat levels,
success rate, persona length before/after summary) via a validator rather than
hardcoded numbers.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "Player takeover
  + aiming" branch and the Phase 2/3 seam.
- [strategems](../strategems/README) — "aim once, aim everywhere."
- [input/startup](../input/startup) — role = player | ncp is read here on launch.
- Displaces: exploration (507). Seizes: data model (501). Consumes: Phase 2 input,
  Phase 3 aimed spells. Signals through: capability signal (506b).
