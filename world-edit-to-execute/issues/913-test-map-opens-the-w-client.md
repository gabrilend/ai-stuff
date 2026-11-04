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
editor's view was looking, whole numbers in the map's own world units (as
the `.w3x` stores positions), which the W client may need to turn into its
own; `--realm` is the settings' host and login port (the authserver's);
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
- **The log** is `tmp/shared-memory/test-map/test-map.log`, each step with
  its UTC time; beside it each program's output (`convert.log`,
  `authserver.log`, `worldserver.log`, `w-client.log`), the receipt, and
  `server.pids` while the editor's server runs (for cleaning up after an
  editor that was killed before it could stop it).

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
