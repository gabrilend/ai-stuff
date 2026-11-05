# server-side: code that runs inside the game server

Everything in this folder runs inside AzerothCore (GNU AGPL v3) and its
Lua engine ALE (`mod-ale`, GNU GPL v3). It is licensed under the **GNU
Affero General Public License v3** (`LICENSE` here), whatever licence the
rest of world-edit-to-execute moves to. `docs/licensing-and-boundaries.md`
explains why: "Anything that runs inside the server stays under AGPL v3 or
GPL v3 ... Keep it in its own folder with its own LICENSE so a later
switch elsewhere doesn't catch it."

The boundary, kept by `src/tests/test_wow_triggers.lua`:

- Code here never `require`s anything outside this folder. The converter's
  runtime (`src/jass/vm.lua`) is the reference the shim is checked
  against, in the tests, but the server never loads it.
- The converter (`src/wowbuild/`) reads one file from here, as data:
  `ale/wc3shim/covered.lua`, the list of natives the shim implements. It
  loads it in an empty environment, as it reads `registration.lua`; it
  runs none of the shim's code.
- What the converter writes for the server (`<build>/server/triggers/`:
  the transpiled `war3map.lua` and `map-data.lua`) is program output and
  carries the map's own rights, not this folder's licence.

| Path | What it is |
|------|------------|
| `ale/wc3shim/init.lua` | the shim: `shim.new(ale, data, opts)`, threads and waits, events, the script's environment, the report of what a script called that the shim lacks |
| `ale/wc3shim/core.lua` | natives that don't touch the world: numbers, strings, triggers, boolexprs, timers, waits |
| `ale/wc3shim/world.lua` | players' gold and lumber, units made at a point, locations, rects, regions and units entering them |
| `ale/wc3shim/covered.lua` | data: every native the shim implements, by group |
| `ale/wc3shim/fake_ale.lua` | a stand-in for ALE's API in plain Lua, so the shim is tested without a server |

Issue: `issues/W02e-triggers-on-the-server.md`.
