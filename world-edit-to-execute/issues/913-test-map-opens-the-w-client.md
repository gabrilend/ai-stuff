# Issue 913: Test Map Opens the W Client

**Phase:** 9 - Editor
**Type:** Implementation
**Priority:** High
**Dependencies:** W02 (converts a WC3 map into WoW's files), W client issue 1109 (opens a handed-in map)
**Builds on:** 901 (the editor's F5 key), 911 (saving maps)
**Blocks:** W10 step 9

---

## Current Behavior

F5 in the editor plays the map being edited inside this project's own
viewer, with the game's rules run by this project's Lua simulation
(`src/runtime/`, `src/demo/wc3map/`). Nothing starts an AzerothCore or the
W client.

*2026-11-04, after the first pass (Implementation Notes below):* F5 and
the toolbar's Test button run Test Map (`src/editor/test_map.lua`): the
map is saved, handed to W02's converter, a local AzerothCore is started or
reused and waited on, and the W client is opened on the build with the
options below; its receipt is read and shown in the status line, a
missing one reported as a crash. Where the converter, the servers and the
W client live comes from the editor's settings (`editor-settings.lua`).
The old play in this project's viewer is gone from the editor: there is
one F5 (open question 1, the owner's answer). Every step is checked with fake programs only: W02's converter
isn't built yet, so on a real machine Test Map stops at step 2 and says
so, and the W client's side (1109) is being built at the same time.

## Intended Behavior

The owner, 2026-11-04: "there should be a button to test the map that
opens the w-client." Asked who starts the local AzerothCore: "the editor."

F5 (and a Test Map button) does, in order:

1. Saves the map being edited.
2. Converts it through W02 into a build folder: terrain tiles, the map's
   registration, server rows and scripts, the map's own imported files.
   No Blizzard file is copied in; the W client finds those in the player's
   own install or draws a wire-frame.
3. Starts a local AzerothCore with that build, or reuses the one it
   already started, and waits until it accepts logins.
4. Launches the W client with the option that opens a handed-in map (W
   client issue 1109), straight into the map.
5. Waits for the W client to exit, reads its goodbye receipt (when it
   ended, frames drawn, seconds run), and shows it; a missing receipt is
   reported as a crash.

The editor owns the server it started: it stops it when the editor
closes, and restarts it when the next Test Map needs a new build.

## Suggested Implementation Steps

1. Settings: where AzerothCore and the W client live (paths read from the
   editor's settings, never hard-coded).
   *Done 2026-11-04:* `src/editor/settings.lua`, reading
   `editor-settings.lua` (fields in `editor-settings.example.lua`).
2. The server keeper: start, wait for its login port, reuse, stop.
   *Done 2026-11-04:* `src/editor/server_keeper.lua`, through the seam
   `src/editor/proc.lua`.
3. The conversion call (W02) into a build folder under the project's
   `tmp/`.
   *The call is done 2026-11-04 (`tmp/test-map/build`); W02's converter
   itself isn't built, so it is named in the settings once it is.*
4. Launch the W client with the map option; wait; read the receipt.
   *Done 2026-11-04:* `src/editor/test_map.lua`, `src/editor/receipt.lua`.
5. F5 and the toolbar button run steps 2-4; a log of each step goes to
   `tmp/shared-memory/`.
   *Done 2026-11-04:* `src/editor/ui.lua`; the log is
   `tmp/shared-memory/test-map/test-map.log`.

## Acceptance Criteria

- [ ] F5 on Daow 4.4 opens the W client on that map, against a local
      AzerothCore the editor started.
      *(Done with fake programs standing in for the converter, the servers
      and the W client; waits for W02's converter and the W client's 1109.)*
- [x] A second F5 reuses the running server.
      *(Checked against fake servers, from the editor's interface on
      Daow 4.4.)*
- [ ] Closing the editor stops the server it started.
      *(Checked when a LuaJIT state closes, as the editor's window closes
      its own, and through `ui:close()`; not yet in the window itself,
      which needs raylib.)*
- [x] The receipt is shown after the W client closes; a crash is reported.
      *(Checked with a fake W client: every reason shown, a crash, a
      malformed and a too-new receipt refused.)*

*2026-11-05, against the W client as built (custom-client PR #19, its
1109 step 1m):* criterion 2 now holds with W02's own converter too (a
second F5 on unchanged Daow 4.4 reuses the server; before, the
converter's report changed the build's checksum every time). Criterion 4
is also checked against the W client's own receipt writer (its
`068-goodbye.c`, compiled in the test when its sources are found).
Criterion 1 still needs a real run: an AzerothCore and the W client on
the owner's machine, and W02c's `map.lua` (draft PR #243), which the W
client reads to know which map it is and which this branch's converter
(W02a only) doesn't write yet. Criterion 3 still needs the real window.

*2026-11-05, with the W02 chain merged in:* the build now holds W02c's
`map.lua`, and Test Map checks it and turns the camera by its rule.
Criterion 1 still needs the real run: an AzerothCore and the W client
on the owner's machine (and W02d/W02f for the server's side of the map).

## Open Questions

1. ~~**The old in-editor play.**~~ Answered 2026-11-04: they are one
   thing. The owner: "I think these are the same?" F5 has always meant
   "test the map"; only where it plays changes. So there is one F5, and it
   opens the W client; the run in this project's own viewer is what this
   issue replaces, not a second mode kept beside it. The Lua simulation
   itself stays, as the reference AzerothCore's rules are checked against.
   The question as asked: does F5's current run in this project's own
   viewer stay as an offline quick preview (no server needed), or retire
   once Test Map works?

## The Contract with the W Client

Agreed 2026-11-04 with the session building the W client's side
(custom-client issue 1109, branch `claude/test-map-launch`); both sides
are built to it:

```
w-client --test-map <folder> --receipt <file> [--camera <x>,<y>]
         [--realm <host>:<port>] [--account <name>]
```

- The password is in the environment variable `W_CLIENT_PASSWORD`, never
  on the command line.
- The receipt is a Lua data file, written whole by the client (to another
  name, then renamed):

  ```lua
  return { format = 1, map = "<folder as given>",
           started = "<UTC, 2026-11-04T20:31:07Z form>", ended = "<same form>",
           seconds = <number>, frames = <integer>,
           reason = "closed" | "lost-connection" | "error",
           why = "<sentence, only when reason is error>" }
  ```

- The editor reads it with the file's text loaded in an empty
  environment, checks every field and refuses format numbers above 1. No
  receipt after the client exits means a crash.

What the editor sends, on its side of it: `<folder>` is the build folder
as an absolute path, and `map` must come back as exactly that;
`<file>` is `tmp/shared-memory/test-map/receipt.lua` (absolute), removed
before each launch so an old receipt never counts; `--camera` is where the
editor's view was looking, in the W client's own world: x north and y
west, in yards, two decimals (`981.52,1959.82`), turned from the view's
WC3 units through the converter's placement of the map (*2026-11-04,
camera pass:* below; the first pass sent WC3 units, which the client
read as yards somewhere else entirely); `--realm` is the settings' host and login port (the authserver's);
`--account` is given when the settings or `W_CLIENT_ACCOUNT` name one, the
password then in the environment when there is one (an empty one counts
as none, on both sides).

**The W client's side, as built (its note, 2026-11-04).** The client
binary also needs its own `--maps DIR` and `--client DIR` on every run, so
the editor's `test_map.w_client` setting points at the client's
`scripts/run` (or a program taking the same arguments), not the binary:
`scripts/run` adds `--maps`, `--client`, `--settings`, `--world` and
`--assets` and passes the options above through unchanged. The editor runs
it from the client's folder (the one above `scripts/`) unless
`w_client_dir` names another. What the editor relies on from that side:

- Exit status 0 after a `closed` receipt, 2 for option errors, 1 for
  other failures. With no receipt, the crash the editor reports names
  exit code 2 as an option refused.
- `--realm` defaults to `127.0.0.1:3724` there; the editor always sends
  it.
- An empty `W_CLIENT_PASSWORD` counts as missing and gives an `error`
  receipt; the editor sends none rather than an empty one.
  *2026-11-05:* the W client as built needs a password in every
  test-map run (its decision 6), so a run with none would only start the
  server for an error receipt; the editor now stops before saving and
  says to set `W_CLIENT_PASSWORD` (decisions of 2026-11-05, below).
- **A failure inside `scripts/run` before the client starts** (a failed
  build, no data) leaves no receipt, so it reads as a crash; the crash
  message names `w-client.log`, where `scripts/run`'s own output is.
- **A kill or Ctrl-C leaves no receipt** for now. So the editor never
  stops the W client during a run; it is always left to close itself.
  The one exception is the editor closing, when it stops the client with
  the server and there is nobody left to read a receipt.

### The call into W02

`<convert...> <map.w3x> <build folder>`, where `<convert...>` is the
settings' `test_map.convert`; exit code 0 is success, anything else stops
the run with the converter's log named. The converter owns what is in the
build folder (the editor never empties it). It may write
`<build folder>/server-stamp`, a line naming what the server reads, so the
server is started again only when that changes; without it, a checksum of
every file in the build decides.

The converter also writes `<build folder>/conversion-report.lua` (W02a),
whose `placement.client` says where it put the map in the W client's
world (*2026-11-04, camera pass*):

```lua
placement = { client = { scale = 0.0325520833..., x0 = <yards>, y0 = <yards>,
                         wc3_min = { <x>, <y> }, wc3_max = { <x>, <y> } }, ... }
-- client x = x0 + scale * wc3 y      client y = y0 - scale * wc3 x
```

`wc3_min` and `wc3_max` bound the map's tile points. Test Map reads it
after converting, as data (an empty environment, a count of
instructions, as the receipt), and turns the view's point through it
(`wowbuild.coords.wc3_to_client`). A report it can't read, of a format
above 1, or with no good placement gives no `--camera`; the status line
and the log say why, and the W client starts at the map's own start.

## Decisions (2026-11-04, background work; each the owner's to overturn)

- **Open question 1:** the owner's answer, above. The first pass had kept
  the old run as an offline quick preview on Shift+F5; that is taken out.
  `E:playtest` and the Lua simulation it runs stay (`test_editor` uses
  it, and the simulation is the reference AzerothCore's rules are checked
  against), but no key or button reaches it.
- **Settings in `editor-settings.lua`, not committed.** It names this
  machine's folders and a test account, so it is ignored by git;
  `editor-settings.example.lua` lists every field, and
  `$WETE_EDITOR_SETTINGS` names another file. It is read as data only (an
  empty environment). Nothing in the code names a place on a machine; a
  missing program is reported when Test Map gets to it.
- **The test account:** `$W_CLIENT_ACCOUNT` and `$W_CLIENT_PASSWORD`
  first, the settings after. The password is set in the editor's own
  environment only around the W client's start and put back at once, so
  it reaches the client and nothing else, and it is on no command line,
  in no log and in no file the editor writes (the tests check all three).
- **Ready means every port accepts.** The settings list the server's
  programs (authserver, worldserver) with their ports; the server is
  ready when each of them and the login port accept a TCP connection.
  The login port alone would let the client log in to a realm whose world
  isn't up yet. The longest wait is `start_seconds` (180); then what was
  started is stopped and the run says which ports never opened.
- **Started again for a new build.** The worldserver reads map tables
  only at start (W02f), so a different build (by its stamp, above) stops
  the running server and starts it again; the same build reuses it.
- **A server the editor didn't start** already on the login port is used
  as it is and never stopped, and the editor says so: it isn't the
  editor's to stop, and it can't be started again for a new build.
- **Nothing waits in place.** `start()` begins a run and each frame of the
  window moves it on (`step()`), so the editor keeps drawing while the
  converter, the server and the W client run. What still blocks the window
  briefly: saving, the build's checksum, and stopping a server (TERM, then
  KILL after `stop_seconds`).
- **F5 during a run** says Test Map is already running and starts
  nothing. A W client that never exits is waited on (it isn't a crash);
  closing the editor stops it.
- **The editor closing.** The viewer (`src/render/scene_viewer.c`) has no
  call for the window closing, and `src/render` was left alone; but it
  closes the Lua state when the window closes, which runs every
  finalizer, so the Test Map session stops the W client and the server
  from its own finalizer. `ui:close()` does the same when called.
- **Strict receipts.** A field the format doesn't have, `why` without an
  error, an `ended` before `started`, compiled code, more than 64 KB, or
  a file that runs too long is refused, as is a receipt for another
  folder. A new field means a new format number.
- **The toolbar button keeps its label, Test.** The toolbar's commands
  already overlap its tools by 5 pixels at 1280 wide; a wider "Test Map"
  would cover a tool. So the button is Test Map under its old label.
- **The camera in the W client's world** (*camera pass*). The W client's
  `--camera` is its own world in yards (its 067-test-map.c and 043-main.c:
  where she starts, the ground under it from the server's maps), not WC3
  units, so the editor turns the view's point through the placement the
  converter reports, rather than the W client learning WC3's units: the
  converter is the one that chose the placement (W02a), and the report is
  already the contract between them. The convention was checked against
  the client's own code, not from memory: `src/018-maps.h` (x north, y
  west, tile = floor(32 - x / 533.33)), `src/033-ground-prep.c` (it opens
  `<map>_<y tile>_<x tile>.adt`), and `src/020-adt.h` (MCNK's position);
  built from the client's sources, its `maps_tile_of` and
  `maps_corner_position` gave the same tile and corner for every tile
  point sampled on six shapes and two real maps, and its ADT reader the
  same ground under the camera.
- **A view off the map** is moved just inside its edge (32 WC3 units,
  about a yard), and logged: the W client refuses a start with no ground
  under it, and a point exactly on an edge that is also an ADT's edge
  belongs, by the client's floor, to the tile beyond, which isn't written
  (a 129 x 129 map's south and east edges are).
- **No placement, no camera.** A converter that writes no placement gets
  no `--camera`, said and logged, rather than WC3 units sent as yards.
- **The log** is `tmp/shared-memory/test-map/test-map.log`, each step with
  its UTC time; beside it each program's output (`convert.log`,
  `authserver.log`, `worldserver.log`, `w-client.log`), the receipt, and
  `server.pids` while the editor's server runs (for cleaning up after an
  editor that was killed before it could stop it).

## Decisions (2026-11-05, held to the W client as built; each the owner's to overturn)

Checked against the W client's own code, custom-client branch
`claude/resolver-prefetch-character` (draft PR #19 there, at 00ed34d):
`src/067-test-map.c` (the options), `src/068-goodbye.c` (the receipt),
`src/043-main.c` (exit statuses), `scripts/run`, and its issue 1109's
contract and decisions 1 to 101. What already matched and is unchanged:
the five option names (their order is free on the client's side), `--camera` as
`x,y` in yards (its `read_camera` takes the editor's two decimals,
negative too), `--realm host:port`, the receipt's fields, layout and
format number, `map` coming back as the folder given, the escapes in its
strings, the exit statuses, and `scripts/run` passing the options
through. Four things didn't:

- **No password: stopped before anything starts.** The W client refuses
  every test-map run without `W_CLIENT_PASSWORD` (an error receipt, exit
  2), so the editor no longer launches without one. `test_map.check_launch`
  runs before the map is saved and stops the run, saying where to put the
  password, rather than converting, starting AzerothCore and then showing
  the client's error. With it go the client's other refusals the editor
  can see coming: an account outside 1 to 63 characters or holding a
  space or control byte (or starting with `--`, which the client reads as
  a missing value), a realm host that is empty, holds a space or a colon
  (the client takes the host up to the last colon; no IPv6), a port
  outside 1 to 65535, a build folder path of 600 bytes or more, a receipt
  path of 580 or more. The client still checks them all; this only says
  so sooner.
- **The build's stamp leaves out `conversion-report.lua`.** W02's
  converter writes when the report was written and how long it took, so
  the checksum of the whole build changed on every F5 and the server was
  started again each time ("Every F5 a new server" above). The server
  never reads the report; leaving it out is enough here (two conversions
  of Daow 4.4 by this branch's converter differ in that file alone).
  A converter `server-stamp` (W02f) still wins when there is one.
- **`scripts/run` named alone gets its client's folder.** `scripts/run`
  takes the client's folder as its first word and otherwise runs a fixed
  default folder (the owner's), wherever the script itself is; running it
  from the folder, as the editor did, doesn't change that. So when
  `test_map.w_client` is the one word `<folder>/scripts/run`, the editor
  passes `<folder>` first. With more words, the words are the user's and
  nothing is added.
- **`WETE` for `scripts/run`.** `scripts/run` makes the baseline set from
  this project's converter tables (`src/wowbuild/ground_textures.lua`,
  `models.lua`), found through `$WETE`, which defaults to the owner's
  checkout. The editor is that project, so it gives the W client `WETE`
  as its own folder, unless `WETE` is already set (then the user's stands).
  It is logged.

Not changed, though the W client has it: the client still leaves no
receipt when it is stopped (its open question 5), so the editor still
never stops it during a run. The fake W client in the tests now refuses
what the real one does (no password, a bad account or realm) with the
real one's sentence, an error receipt and exit 2, and writes receipts in
the real one's layout.

## Decisions (2026-11-05, Test Map through W02c; each the owner's to overturn)

The W02 chain (W02a, W02b, W02c, W02e and the ground and info files beside
`map.lua`, draft PRs #240 and #242 to #247) is merged into the Test Map
branch, so the converter Test Map runs writes `map.lua`. `src/wowbuild/init.lua`
merged on its own: the report keeps W02c's `placement` fields (`rule`,
`first_tile`, `wc3_offset`) and #241's `placement.client`, and the
numbers keep #241's shortest exact form (which `map.lua` now gets too).

- **The camera goes by `map.lua`'s `wc3_to_wow`; if it and the report's
  `placement.client` ever disagree, `map.lua` wins.** `map.lua` is what
  the W client itself reads: its start, its placements and the ground
  under them are placed by that rule (its 073-converted-map.c), so a
  camera turned by any other rule would land somewhere the client didn't
  put the map. Today both are made by the same arithmetic
  (`L:to_wow(0, 0)` and `coords.YARDS_PER_UNIT`), and on Daow 4.4 they are
  equal to the last bit. They count as agreeing within 1e-12 of the scale
  and a millimetre (0.001 yards) of x0 and y0. When they disagree, the
  camera takes `map.lua`'s scale, x0 and y0 with the report's bounds
  (`wc3_min`, `wc3_max`; `map.lua` has none), and the status line and
  log say both rules: a disagreement is a converter bug to see, not one
  to hide. A report without a placement still means no `--camera`, since
  the edge can't be kept to without bounds; a build with no `map.lua`
  doesn't get that far (next).
- **A build without a good `map.lua` stops before the server starts.** The
  W client opens a test map by it and stops with an error receipt
  without it, so Test Map reads it after converting (format 1, a
  `wc3_to_wow` with a scale above 0) and says what is wrong, naming
  W02c and the converter's log. Only what the editor relies on is
  checked; the rest is the W client's to check.
- **The stamp leaves out each report that holds a time.** With the whole
  converter, two conversions of unchanged Daow 4.4 differ in three files:
  `conversion-report.lua`, `World/Maps/<dir>/registration.lua` (W02c's
  record of the slot and rows, with when it was written; the rows reach
  the server through `server/`), and `server/triggers/<dir>/natives-report.lua`
  (W02e's coverage report, with how long it took; the shim reads
  `war3map.lua` and `map-data.lua`). The server reads none of them, so
  all three are left out (`test_map.STAMP_LEAVES_OUT`); without that,
  every F5 started the server again.
- **`W_CLIENT_SRC` names the W client's folder**, as `test_wow_registration`
  already takes it, not its `src/` (this branch's 2026-11-05 note above
  said `src/`; the two tests now read it the same way).

## Decisions (2026-11-05, the server's stamp and the W client's own start; each the owner's to overturn)

- **The server is reused by the converter's `server-stamp` (W02f step 1),
  and the list of reports left out is retired.** The converter names the
  files the server reads with their checksums, so the editor compares the
  stamp it last started the server with to the new build's. `test_map.STAMP_LEAVES_OUT`
  is gone with the whole-build checksum. **No fallback:** a build with no
  readable stamp counts as new, so the server is started again and the
  status line says why. The editor removes the old stamp before
  converting, as it does an old receipt before launching. W02f's
  decisions give the reasons and the format.
- **The W client's own start runs in the tests.** When `$W_CLIENT_SRC`
  names the W client's folder, `test_test_map` builds the client's start
  from its sources and uses it as the W client of a Test Map run on W02's
  real conversion of Daow 4.4. The start covers the options (067), the
  receipt (068), `map.lua` (073) and the world's start (087: the tables,
  the map's folder, the ground under the start). It is built from every
  window-free part the client's `scripts/build` lists, less any that
  includes the drawing library's headers (only `032-sight` today).
  `src/tests/fixtures/test-map/w-client-start.c` calls those parts in
  043-main.c's order and stops where the window would open, writing a
  `closed` receipt with 0 frames. A stand-in `scripts/run` does what the
  real one does in a test map: its folder first, `--maps`, `--client` and
  `--assets` added, and the baseline set made once from `$WETE`'s tables
  with the client's own `086-make-baseline`.
- **It needs `$W_CLIENT_SRC` set; nothing is looked for at a default
  path.** That is how `test_wow_registration` already compiles from the
  client. Without it, or with no C compiler or no StormLib, the section
  says why and is skipped. (The receipt writer's section still falls back
  to the owner's checkout, as it did.)

## Related Documents

- `docs/wow-client-bridge.md` ("2026-11-04: the editor keeps its own
  renderer; Test Map opens the W client")
- W client: `/mnt/mtwo/games/azeroth-core/custom-client/issues/1109-test-map-from-the-editor.md`
- `issues/W02-build-wc3-maps-into-the-wow-client.md`

## Implementation Notes

*(2026-11-04, first pass)*

- `src/editor/settings.lua`: the editor's settings, read as data, with
  defaults and the environment's account and password.
- `src/editor/proc.lua`: the seam every outside program goes through:
  start in the background in its own process group (its pid at once, its
  output to a log, its exit code to a file, an environment for it alone),
  alive, stop (TERM to the group, KILL after a time), and whether a port
  accepts a connection (LuaJIT's FFI). The tests hand Test Map fakes
  through the settings; nothing else changes.
- `src/editor/server_keeper.lua`: the local AzerothCore started, waited
  on, reused, started again for a new build, stopped.
- `src/editor/receipt.lua`: the goodbye receipt read and checked, and the
  line shown for it.
- `src/editor/test_map.lua`: the run: save, convert, server, launch, wait,
  receipt; stepped each frame; closed with the editor.
- `test_map.w_client` is the W client's `scripts/run` (the client side's
  note above); a fake `scripts/run` in the tests checks it is run from the
  client's folder with the options passed through.
- `src/editor/ui.lua`: F5 and the Test button run Test Map, and nothing
  else plays the map; `update()` steps a run; `close()`. `main.lua`
  passes nothing new (the view's camera was already given) and no longer
  passes the viewer, which only the old run used; its header says what F5
  does now. `src/render/run-editor`'s header still says F5 plays the copy in
  the viewer (left alone with the rest of `src/render`).
- **Tests:** `src/tests/test_test_map.lua` (110 tests), with fakes in
  `src/tests/fixtures/test-map/`: a LuaJIT server that opens a port
  (or never does, or dies), a shell W client that writes each kind of
  receipt, crashes or hangs, and a shell converter that builds, fails or
  is slow. Runs through the editor's interface on Daow 4.4.

**Not done yet:**
- **The real thing:** W02's converter (named in the settings once it
  exists), the W client's `--test-map` (1109), and a run on this machine's
  AzerothCore. How the build reaches the server (rows into its database,
  ALE scripts, extracted map files) is W02f's; the keeper passes the
  build folder to the server programs (`{build}` in a command, and
  `WETE_TEST_MAP_BUILD`) and nothing more.
- **The window:** F5 in the real editor window, and its closing, are
  untested here (no raylib); the code they run is tested through
  `ui.lua`.
- **A server left by a killed editor** is not adopted or stopped by the
  next one; its pids are in `server.pids`.

*(2026-11-04, camera pass: the camera lands where the editor's view looks)*

How it was before: the editor sent `--camera` as the view's point in WC3
world units, whole numbers, and the W client takes its own world x and
y in yards; nothing turned one into the other, so the W client started
far from the map (DAoW 4.4's middle, WC3 (0, 0), was sent as world
(0, 0) by luck; any other point, a view 1000 units east, was sent 1000
*yards* off, about 30 times too far and on the wrong axis). Now:

- `src/wowbuild/coords.lua` (W02a's): `Layout:client_placement()`, the
  placement as plain numbers (a scale and a shift, WC3's axes turned a
  quarter: client x = x0 + scale * wc3 y, client y = y0 - scale * wc3 x,
  and the map's bounds); `coords.check_placement`;
  `coords.wc3_to_client(p, x, y)`, which moves a point off the map just
  inside its edge; `coords.client_adt(x, y)`, the W client's own rule for
  which ADT a world point is in (its 018-maps.c and 033-ground-prep.c,
  in 32-bit floats as it does it).
- `src/wowbuild/init.lua`: the report's `placement.client`; numbers in
  the report are written in the shortest form that reads back exactly
  (they were cut to six digits, which would put the camera up to a tenth
  of a yard off).
- `src/editor/test_map.lua`: `test_map.read_placement(build)` and
  `T:client_camera(x, y)`; `--camera` is the W client's world, two
  decimals; no placement means no `--camera`, said why.
  `src/editor/receipt.lua` lends it its reader of data files
  (`receipt.run_data`, with a larger count of instructions for a report).
- **Tests:** `src/tests/test_test_map.lua` (125): the fake converter
  writes a report (or none, none with a placement, a bad one, a too-new
  one); each is read or refused with why; a report that runs forever or
  reaches for functions is refused; the axes; a view off the map moved
  onto it and logged; a run with no placement opens the W client
  without `--camera` and says so; and a run through W02's own
  converter on Daow 4.4: the camera is its placement of the view's
  point, and the ADT the W client opens there is one it wrote. The fake
  W client now refuses a `--camera` its reader would refuse.
  `src/tests/test_wow_terrain.lua` (its camera section): the placement
  is the layout's own mapping on six shapes; the axes; off-map points;
  bad placements refused; the report's numbers read back exact; every
  sampled point, corners and off-map ones too, lands in a written ADT by
  the client's rule; and, with the client's reader library, the ground
  it reads under the camera is the WC3 ground at the point asked for.

**Still open after the camera pass:**
- **Which map the W client opens.** With `--test-map` the client still
  opens map 1 (Kalimdor) and its server-side ground (`--maps`), so the
  camera is right for the converted map, but the map registered and
  opened is W02c's and 1109's (the `Map.dbc` row, then telling the client
  which map), and the ground under the start is the server's extracted
  maps (W02d). Until then the client's "no ground at the start" check
  may stop it on a point the converted ADTs do cover.
- **The view's height** isn't sent: `--camera` is x and y only; she
  starts on the ground there.
- **Every F5 a new server:** the real converter's report carries the
  time it was written, so without a `server-stamp` from the converter the
  build's checksum changes on every run and the server is started again
  each time. W02f's server stamp is the fix.

*(2026-11-05, held to the W client as built)*

How it was before: the editor launched the W client with no password
when none was set, and the client, which needs one in every test-map run,
stopped with an error receipt after the map was converted and the server
started; every F5 started the server again, because the converter's
report (its time) changed the build's checksum; a `scripts/run` named
alone ran its own default folder, not the one it sits in; and
`scripts/run` looked for this project's tables at the owner's default
path. Now (decisions of 2026-11-05, above):

- `src/editor/test_map.lua`: `test_map.check_launch` (run in `T:start`
  before saving), `test_map.client_folder`, the stamp without
  `conversion-report.lua`, `WETE` in the W client's environment, and its
  header.
- `editor-settings.example.lua`: the password is needed; what a lone
  `scripts/run` is given; `WETE`.
- `src/tests/fixtures/test-map/fake-w-client.sh`: refuses as the real one
  does, writes the real one's layout, records its first word and `WETE`.
  `fake-convert.sh`: a `stamped` mode whose report differs each time.
- **Tests:** `src/tests/test_test_map.lua`, 125 -> 159 passed without
  the W client's sources (one section skipped), 164 with them
  (`W_CLIENT_SRC`, else `/mnt/kaun/custom-client/src`): every refusal
  `check_launch` makes and its edges (255/256-byte passwords, 63/64-character
  accounts, 599/600 and 579/580-byte paths); a run with no password or a
  bad account stopped with nothing saved, converted or started; the
  client's own refusal still shown as an error, not a crash; an error's
  `why` read back byte for byte; a converter whose report changes each
  time, and W02's own converter on Daow 4.4, reusing the server on a
  second F5 (both fail without the stamp change: 157 of 159); `WETE`; a
  lone `scripts/run` given its folder; and the W client's own
  `068-goodbye.c` built and run, its closed, error and lost-connection
  receipts read by `receipt.read`, a map path with quotes, a backslash, a
  new line, a control byte and UTF-8 coming back byte for byte.
  `test_editor` (83), `test_editor_integration` (44) and
  `test_wow_terrain` (83 passed, 17 skipped) pass unchanged.

**Still open:**
- A real run (criterion 1): AzerothCore and the W client on the owner's
  machine, with W02c's `map.lua` in the build (draft PR #243); this branch
  stacks on #241, which has W02a's converter only.
- When #241's branch and the W02 chain (#242 onward) meet, their
  `src/wowbuild/init.lua` reports both need keeping: #241's
  `placement.client` and W02c's `placement` fields and `map.lua`.
- The W client's open question 5 (a receipt when it is stopped).

*(2026-11-05, Test Map through W02c)*

How it was before: the Test Map branch had W02a's converter only, so its
builds had no `map.lua` and the W client, which opens a test map by it,
would have stopped with an error receipt; the camera went by the
report's placement alone; and with the whole converter, every F5 would
have started the server again (two more reports carry a time). Now
(decisions above):

- Merged `claude/wete-w02-w3i-copy` (#247, the W02 chain's tip) with a
  merge commit. One conflict, `src/cli/wow-convert.info.md`'s table of
  files: W02c's rows kept, with `placement.client` described on the
  report's row.
- `src/editor/test_map.lua`: `test_map.read_map_file`,
  `test_map.camera_placement` (`T:client_camera` goes by it), the build
  checked for `map.lua` before the server, `test_map.STAMP_LEAVES_OUT`.
- `src/tests/fixtures/test-map/fake-convert.sh` writes `map.lua` as W02c
  does, and has `nomap`, `badmap` and `disagree` modes.
- **Tests** (`src/tests/test_test_map.lua`): 164 -> 177 with the W
  client's sources and reader library (`W_CLIENT_SRC`, `W_CLIENT_BUILD`),
  159 -> 172 without (one section skipped): `map.lua` read, missing,
  refused (format 2, a scale of 0, one that runs forever); the rule
  agreeing, disagreeing (map.lua's used with the report's bounds, and
  said), and either file missing; runs stopped before the server for a
  missing or unreadable `map.lua`; a disagreeing build's camera by
  `map.lua`'s rule; W02's converter on Daow 4.4 writing `map.lua` whose
  rule is `placement.client`'s exactly, and reusing the server on a
  second F5 (it failed, 2 starts then 4, before the stamp list).
  The W02 chain's own tests pass unchanged on the merge:
  `test_wow_registration` 93, `test_wow_placements` 90,
  `test_wow_triggers` 138, `test_wow_config` 43, and `test_wow_terrain`
  177 (161 on the W02 tip, 177 on the Test Map branch: the camera
  section joins); `test_editor` 83, `test_editor_integration` 44.

*(2026-11-05, the server's stamp and the W client's own start)*

How it was before: the editor decided whether to reuse the server from a
checksum of the whole build, leaving out a list of the converter's
reports that hold a time, and each new report had to be added to that
list. The tests stood a shell script in for the W client, so whether the
real client takes the build's `map.lua` and finds ground under the
editor's `--camera` was only checked by the client's own tests, on
builds made by hand. Now (decisions above):

- `src/editor/test_map.lua`: `T:stamp` reads `server-stamp` through
  `wowbuild.server_stamp.read`; with none, the build counts as new and
  this is said. The old stamp is removed before converting.
  `STAMP_LEAVES_OUT` is gone.
- `src/tests/fixtures/test-map/fake-convert.sh` writes `server/world.sql`
  and the stamp with the converter's own code, and has a `nostamp` mode.
- `src/tests/fixtures/test-map/w-client-start.c`: the W client's start, up
  to its window, from its own parts.
- **Tests** (`src/tests/test_test_map.lua`): 177 -> 187 with the W client's
  sources and library (`W_CLIENT_SRC`, `W_CLIENT_BUILD`), 172 -> 174
  without (two sections skipped):
  - With no stamp, the server starts again on each F5 and the status line
    says why. An earlier build's stamp is removed and never reused.
  - The window-free parts are read from the client's `scripts/build` and
    the start is built from them.
  - Test Map on Daow 4.4 with W02's converter and the client's own start:
    - the receipt reads `closed` with 0 frames;
    - `map.lua` is accepted, with the map and folder it names;
    - there is ground under the `--camera` the editor sent;
    - the tables come from the build and from the baseline set made from
      `$WETE`'s tables, with no install.
  - Seven view points in, on the edges of and far off the map all have
    ground under them (the editor moves the off-map points inside).
  - A camera with no ground under it comes back as the client's error
    receipt.
  - The converter's side is W02f's `test_wow_server_stamp` (23).

**Acceptance criteria:** unchanged. Criterion 1 (a real AzerothCore and
the W client's window on the owner's machine) and criterion 3 (the real
editor window) are still open. Criteria 2 and 4 now also hold with the
client's own start code.
