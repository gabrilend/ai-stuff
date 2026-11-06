# Roadmap

The work is grouped into phases by what it builds, not by when it is built.
Lower phases are foundations the higher ones stand on. Each phase ends with a
demo in issues/completed/demos/, run from the project root by
`./run-phase-demo`.

## Phase 1 — The spine

Everything a run needs before there is anything to fight: configuration
defaults and overrides, named random streams, reading input/ at start and
writing the goodbye receipt at the end, the scripted-input timeline, the
headless runner and its multi-process batches, the screenshot filing into
development-history/, the house-style linter, and the test runner.

*Ends with:* a demo that runs scripted headless battles in parallel and prints
the receipts side by side, proving that a seed and a script fully decide a
run.

## Phase 2 — Bodies on the field

The catalogue of unit types and weapons, the battlefield grid and its
occupancy, the soldier record, stamina and fatigue, walking with the
occupancy rules (enemies block, allies yield at half speed, dodges never land
in an occupied cell), and tripping.

*Ends with:* a demo that marches two crowds through each other in the
terminal and counts blocked steps, ally passes, yields and trips.

## Phase 3 — The sword

The U and the lock, the swing kinds and momentum, hit resolution (parry,
flank, critical, armor), the soldier mind that fights for everyone who is not
the player, and the battle tick that runs them all in order and decides when
a contingent breaks.

*Ends with:* a demo of hundreds of headless battles across cores, reporting
parry rate by fatigue, critical share by cause, and who wins.

## Phase 4 — Seeing it

Matrix arithmetic and perspective, clay-and-brick meshes and their shader,
figures posed from the soldier records, scenery with hidden cat faces, the
first-person view with edge awareness, the third-person view, and the front
desk that joins the engine's callbacks to the modes.

*Ends with:* a demo that opens the game window on a scripted battle, flies
from third person into first person, takes screenshots and files them.

## Phase 5 — Command and the round

Volleys at their fixed arc and the shield wall, the round's sequence (command,
approach, first person, result), the command screen, and the campaign map of
regions with its push directions and home regions.

*Ends with:* a demo that plays a whole scripted match, round by round, and
shows the campaign map changing hands.

## Phase 6 — Growth

Perks, unit types (mega spearman, beastwarrior, skirmisher), the two armor
tracks and the awareness they cost, and the mod folder that overlays the
catalogue.

*Ends with:* a demo that runs matched batches with and without each perk and
charts the difference, then opens a battle with a modded unit in it.

## Phase 7 — Distance

The simulation on its own engine thread; two players over a socket, in
lockstep; the expansion arsenal (spears and hatchets, hammers, glaives,
halberds, pikes, horses, archers, and dragons, which are cannons of fire).

*Ends with:* two windows, one battle.
