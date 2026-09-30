# Issue 1002: Convention Demo Menu

**Phase:** 10 - Polish, Tools and UX
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** the map viewer and game (517-542), the model
gallery (522e, 523), the fort (516e), the threaded renderer (512, 513), the
World Editor (901-912a), the phase demos (0-5, 9)

---

## Current Behavior

`run-demo.sh` is a phase selector written when phases 0-5 were the whole
project: ten phase entries (6-9 "pending"), a statistics page and the tests.
The graphical work since (a map played with its script and computer players,
heroes, spell art, fog, models and their animations, the World Editor and
its panels) is reached only through `src/render/run-map`, `run-fort`,
`run-editor` and environment variables read in the scene scripts, which a
presenter would have to know by heart.

## Intended Behavior

The owner (2026-09-30): "make all of the demos you can think of with the
built functionality accessible through the run-demo.sh script. A little main
menu where you can select them by category (with number of demos per
category, dynamically parsed) and run one per run-demo.sh run. Each one
should be a single line of bash (internally) that sets up the environment
and runs the demo. Emphasize graphical demos over the data model, which can
be made apparent through the demos. They are not tests, but rather 'tech
demos' for wow-ing audiences at conventions and such."

- A registry in `run-demo.sh`: one line per demo (id, category, title, what
  the audience sees, one line of bash).
- A menu: categories with their demo counts, read from the registry; then the
  category's demos; the chosen one runs and the script ends.
- Graphical demos first; the data-model demos kept in one category at the end.
- Where a demo needs work on the owner's machine (the install's art, model
  parsing, client file extraction), a comment marking it.

## Suggested Implementation Steps

1. Helpers the demo lines share: build the scene viewer once into a cache and
   run a scene (`viewer`), the threaded renderer (`threaded`), LuaJIT from the
   project root (`lj`), a new map made from nothing (`newmap`), a scripted
   input string with one action every N seconds (`every`).
2. The registry, by category: playing maps, hands-free attract-mode runs
   (SCENE_ACTIONS), rendering switches (WC3_MODELS, WC3_TILES, WC3_FOG,
   WC3_ANIMATE, WC3_SCRIPT), the model gallery, the editor and its panels,
   engine internals, and the text demos.
3. The menu, direct runs by id or category.number, a list, and a check mode
   that runs demos unattended with screenshots.

## Acceptance Criteria

- [x] `./run-demo.sh` shows the categories with the number of demos in each,
      counted from the registry
- [x] Choosing a category lists its demos with what each shows; choosing one
      runs it, and the script ends after it
- [x] Each demo is one line of bash in the registry
- [x] Graphical demos make up most of the list
- [x] `./run-demo.sh ID` and `./run-demo.sh CAT.N` run one demo directly;
      `-l` lists them; the old `./run-demo.sh 3` still runs phase 3
- [x] `./run-demo.sh -c` checks the graphical demos unattended (screenshots)
- [x] Comments marked `ATTENTION(local)` where the owner's machine has work
      to do
- [ ] Every demo checked on the owner's machine with the install linked

## Implementation Notes

**2026-09-30.** `run-demo.sh` rewritten around a registry (`DEMOS`, a
heredoc of `id | category | title | blurb | command` lines). 48 demos in
seven categories: Play a Map (8), Attract Mode (5), Rendering (6), Models &
Animation (7), World Editor (8), Engine Internals (4), Under the Hood (10).

- The viewer is built into `~/.cache/world-edit-to-execute/scene_viewer`
  (`DEMO_CACHE`), again only when a file in `src/render` is newer; the
  threaded renderer beside it. `RAYLIB_PATH` defaults to the owner's usual
  place, as in `src/render/run-*`.
- `DIR` defaults to the script's own folder (was the hardcoded `/mnt/mtwo`
  path); a folder as the first argument still overrides it.
- Attract mode uses the map scene's scripted input (`SCENE_ACTIONS`); while
  it is set the scene takes no mouse input (arrows still pan, Esc quits).
  The kingdom tour's coordinates are DAoW 5.4b's start locations.
- `-n` sets `SCENE_QUIT_AT` (DEMO_SECONDS, default 40) so graphical demos
  end on their own; `threaded` is stopped with `timeout`, having no timer.
- `-c` runs demos with `-n` under `xvfb-run` when there is no display,
  screenshots at a third and two thirds of the run into
  `~/.cache/world-edit-to-execute/check/<id>/`.
- Checked here (a cloud container: no install, raylib 5.0 built from
  source, Xvfb + Mesa): see the results appended below.

`ATTENTION(local)` comments in `run-demo.sh` mark:

- raylib's version (5.0's API; 6.x removed `GetMouseRay`, used by
  `src/render/input.c`);
- the art: without `wc3-installs/frozen-throne` and the patch layers the
  demos draw the maps' imported models and stand-ins; with them, the stock
  models, ground tiles and unit stats;
- `src/render/main.c`'s inline Lua loading the map from the hardcoded
  `/mnt/mtwo` root;
- demos to add when their code exists: Phase W (the WoW client's archives
  read and extracted, M2 models with WC3 behaviour) and a check that the
  install's models cover most units in play-daow.

The phase 1-4 text demos and `phase4_love` still name the `/mnt/mtwo` root
themselves; they run on the owner's machine as before.

**Check results, 2026-09-30 (cloud container).** `./run-demo.sh -c` with
`DEMO_SECONDS=6`: 35 of 35 graphical demos ran and quit cleanly, with
screenshots (the threaded renderer has no screenshot hook; it ran until
stopped). Longer runs of the scripted ones, screenshots read by eye:
tour-heroes (hero to level 10, bolts across the capital), tour-battle (12
units attack-moving on the Scourge), tour-interface (the quest log open),
editor-sculpt (hill, cliff, water, smoothing on a new map), editor-triggers
(637 map triggers listed). The ground was stand-ins and most models geometry
designs throughout, there being no install here. Not run here: models-glb
(no .glb files), engine-ecs (no LOVE), editor-roundtrip and the phase text
demos that name the `/mnt/mtwo` root.
