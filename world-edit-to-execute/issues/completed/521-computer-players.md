# Issue 521: Computer Players, the AI Editor's Way

**Phase:** 7 (gameplay), pulled forward
**Type:** Implementation
**Priority:** High
**Dependencies:** 519 (combat), 520 (a map's script runs)

---

## Current Behavior

Computer players stand still. `StartMeleeAI`, `StartCampaignAI`,
`CommandAI` and Blizzard.j's `MeleeStartingAI` do nothing (counted
no-ops in 520). Buildings can't train: the command card says "not
simulated".

## Intended Behavior

An AI for computer players built the way WC3 builds one, so maps that
use WC3's AI mechanisms get the same features:

- **Scripts:** the AI natives a map's `.ai` script runs on.
- **Profiles:** the AI Editor's model (its tabs as data) and a runner that plays it.
- **Melee:** a default melee AI per race.
- **Custom maps:** for maps that start no AI (DAoW among them), one AI profile per faction, derived from what the faction owns, written as editable files.

Training units, which every AI needs.

| Part | What | Where |
|------|------|-------|
| 521a | Production: train queues, costs, food, requirements, rally points | `src/demo/wc3map/production.lua`, `game.lua`, `ui/wc3/hud.lua` |
| 521b | The mechanism (captains, counts, targets, fleeing, defending, commands) and the AI natives | `src/ai/player.lua`, `src/ai/natives.lua`, `src/jass/natives/ai_host.lua` |
| 521c | The AI Editor's model and its runner | `src/ai/profile.lua`, `src/ai/editor_ai.lua` |
| 521d | Melee profiles, faction profiles, profile files and the tool | `src/ai/melee.lua`, `src/ai/faction.lua`, `src/ai/tool.lua`, `ai-profiles/` |
| 521e | The manager, the game, the viewer | `src/ai/init.lua`, `game.lua`, `demo/wc3map/main.lua` |

## Acceptance Criteria

- [x] Buildings train with the map's costs, times, food and tech limits; cancel refunds; the script sees train events
- [x] `StartMeleeAI` / `StartCampaignAI` run the map's own `.ai` file when it has one, else our melee profile for the race
- [x] `CommandAI` reaches the AI (`CommandsWaiting` / `GetLastCommand` in a `.ai`, `{ "command", n }` in a profile)
- [x] The AI Editor's tabs as a profile: General (options, target priorities), Heroes, Build Priorities, Attack Groups, Attack Waves, Conditions
- [x] One editable profile file per DAoW 5.4b faction, used in place of deriving
- [x] DAoW 5.4b: all 11 computer factions train and send waves
- [x] `test_ai.lua`: 27 tests; full suite passes

## Implementation Notes

**Date:** 2026-09-29

### What the test maps have

No AI in any of the 16. No `.ai` file in any archive: every stored file
was read, named or not. No call to `StartMeleeAI` or `StartCampaignAI`.

The older DAoW versions carry the AMAI Commander:

- **Versions:** 2.1, 4.4, 4.7.3 and 6.2.
- **What it is:** the chat and dialog half of AMAI, the community "Advanced Melee AI". It sends numbered commands through `CommandAI`: 12 attack player, 70 change strategy, and so on.
- **The gap:** the AI scripts it talks to were never inside the map. They come from installing AMAI.
- **Later versions:** the 5.x versions dropped it.

AMAI is open source (github.com/SMUnlimited/AMAI), but its licence asks
projects to request permission before using its code. Nothing of it is
used here; only its list of native names was read, to confirm the
interface.

### How WC3 does it, and the layers here

WC3's pipeline, and the part of this issue that stands for each step:

| WC3 | Here |
|-----|------|
| AI Editor → `.wai` file | a profile: a Lua table, one file per player (`ai/profile.lua`) |
| `.wai` compiled → `.ai` JASS on `common.ai` | the profile played by `ai/editor_ai.lua` |
| `.ai` scripts run on the AI natives, one thread per player | `ai/natives.lua` on `ai/player.lua`; a map's `.ai` runs as a VM thread |
| Melee AI = the game's `human.ai` etc. | `ai/melee.lua`, our own, one per race |
| `StartMeleeAI` / `StartCampaignAI` / `CommandAI` from triggers | `jass/natives/ai_host.lua` → `ai/init.lua` |

The AI Editor's tabs are described from memory and modding guides. The
guides' sites (Hive Workshop, thehelper.net) are blocked from this
environment, so the parity table is a best recollection, to be checked
against the editor.

| AI Editor | Profile | Played? |
|-----------|---------|---------|
| General: name, race | `name`, `race` | yes |
| General: options (melee, defend users, random paths, target heroes, repair, heroes/units/groups flee, have no mercy, ignore injured, take/buy items, slow harvesting, smart artillery) | `options` | Flee options and defending: yes. The rest: kept |
| General: harvest (workers on gold / lumber) | `harvest` | kept: no gathering yet |
| General: target priorities | `targets` | yes: enemy near home, enemy base (optionally a player's), nearest enemy, creeps, a point |
| Heroes: picks and skill orders | `heroes` | Picks: yes. Skill orders: kept (heroes don't learn skills yet) |
| Build Priorities, with conditions | `build` | Units and heroes: yes. Buildings, upgrades, expansions: kept (no construction or research yet) |
| Attack groups | `groups` | yes |
| Attack waves: initial delay, delay, repeat | `waves` | yes; `max_wait` / `min_fraction` are ours |
| Conditions (difficulty, game time, wave, unit counts, towns, …) | `conditions`, with and/or/not | yes |

"Kept" means the profile holds it and the file keeps it; the runner notes
it once in the AI's log and goes on.

### 521a: production

A queue of up to seven per building:

- **Payment:** paid when queued, refunded when cancelled; a fallen building loses its queue.
- **The trained unit:** steps out toward the rally point (default south) and walks there.

What a unit costs:

- **From the map:** gold, lumber, time, food and requirements come from the map's object data. DAoW 5.4b sets gold for 289 of its 291 trainable types, time for 285, food for 263 and requirements for 49.
- **Stand-ins:** the rest use stand-ins by archetype, marked in the file.
- **Tech limits:** the script's `SetPlayerTechMaxAllowed` holds ("not allowed").

Purses are the script's player state when a script runs. The HUD's Train
and Rally buttons work for the local player. The VM gets `TRAIN_START` and
`TRAIN_FINISH`.

### 521b: the mechanism and the natives

`ai/player.lua`:

- **Captains:** an attack captain and a defense captain. An assault is asked for by type and number; `form_group` fills it from free units.
- **Counts:** `count` includes units in training; `count_done` doesn't.
- **Production:** `produce` trains at the owned building with the shortest queue.
- **Targets:** enemy base (the alliance target, else the enemy with buildings nearest home), nearest enemy, creep camp.
- **Its own behaviour:**
  - A wave that takes its target moves to the next enemy nearby, else comes home.
  - The badly hurt flee (heroes, units, whole groups, by option).
  - Anything struck near home calls the defense captain and every free fighter at home.

`ai/natives.lua`:

- **The AI-only natives:** threads, options, counts and costs, `SetProduce`, the assault and captain natives, targets and the `CommandAI` queue.
- **Our versions of common.ai's build list:** `SetBuildUnit` and the Campaign* helpers.
- **What the game can't do yet:** harvest control, upgrades, expansions, guard posts and the like are counted no-ops.
- **Anything else:** a counted stub, as in 520.
- **Environment:** a map's `.ai` gets its own environment per player: common.j natives and these, not the map's globals.

### 521c/d: profiles, melee, factions

- **Profile files:** in the editor's tab order, one record a line, each unit id followed by its name in a comment.
- **`profile.check`:** finds waves naming missing groups and unknown conditions.
- **Melee profiles:** workers, farm, barracks, altar, heroes, army by tier, three waves that grow.
  - Stock ids are from memory.
  - On a melee map they can only train what the starting buildings train (workers), since nothing can be built yet. The shape is right for when construction comes.

A faction profile is derived from what the faction owns:

- **Build:**
  - The army's own types, up to their starting numbers (at most 12), for those its buildings train and the map allows.
  - Then the cheapest other allowed types.
- **Heroes:** its starting heroes, by slot.
- **Groups:** "main", about half the starting army.
- **Waves:** main ×3, repeating: first at 4:00, then every 2:00.
- **Targets:** enemies near home, then the nearest enemy base.

`luajit src/ai/tool.lua write MAP` writes one file per faction into
`ai-profiles/<map>/`, never over an existing file. `check DIR` validates
a folder. The game uses a faction's file instead of deriving while one
exists.

### 521e: running

`game.run_script` takes the AI options:

- **`ai`:**
  - `"auto"` (default in the viewer): every computer player the map leaves idle gets an AI.
  - `"script"`: only what the map starts, as WC3.
  - `"none"`: no AI.
- **`ai_dir`:** the profiles folder.
- **`read_file`:** reads a named `.ai` from the map.

The lobby (520) makes every non-local slot a computer, so on DAoW 5.4b all 11 other factions get one.

In the viewer, `WC3_AI` sets the mode. The profiles folder is
`ai-profiles/<map>/` under the project. The chosen AI of each player is
printed at start.

### Checked on DAoW 5.4b

Headless, seven game minutes, 11 derived profiles:

- 33 units trained and 196 units died.
- Every faction sent its first wave at about 4:00, mostly at the nearest enemy base. The Scourge fought enemies at its own door first.
- The Illidari lost their whole wave of 26.
- No VM errors. The whole simulation ran at about 3.6× real time.

In the viewer, the Scourge's file was edited to send its first wave at
0:20. Its wave of 41 fights at the Scarlet Crusade's front door.

### Not yet

- **Construction and gathering:** without them, melee AI can't grow, and harvest settings, expansions and building entries are kept, not played.
- **Hero growth:** no research or hero skills, so upgrade entries and skill orders are kept, not played.
- **Items and difficulty:** shops, and difficulty affecting anything beyond conditions.
- **AMAI Commander command numbers:** they arrive in the AI's queue, but no profile gives them meaning. A profile can, with `{ "command", n }` conditions.
- **Tuning:** derived factions don't use DAoW's control-point goal. They attack bases, not points, and nobody has tuned them.
- **No `.wai` reader:** the AI Editor's own file format isn't read. A `.wai` → profile converter needs sample files to be written against.
