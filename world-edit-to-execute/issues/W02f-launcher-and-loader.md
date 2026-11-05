# Issue W02f: Launcher and Loader

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W02
**Priority:** High (the editor's Test Map starts the server; the server has to load what W02 built)
**Dependencies:** W02c (the build's server files and `patch-W.MPQ`), W02d (the server's map files for new maps)
**Blocks:** W02's acceptance line 4 (the map loads and the character stands on it); issue 913's acceptance line 1 (F5 opens the W client against a local AzerothCore)

---

## Current Behavior

*As written (2026-11-05, before this issue's work):* W02's converter
(`src/cli/wow-convert.lua`, `src/wowbuild/`) writes a build folder: the W
client's files (`map.lua`, `DBFilesClient/`, the ground), the server's
(`server/world.sql`, `server/dbc.sql`, `server/dbc/`, `server/triggers/`)
and `patch-W.MPQ`. The editor's Test Map (issue 913) starts AzerothCore's
programs from its settings, hands them the build folder (`{build}` in a
command, `$WETE_TEST_MAP_BUILD`) and nothing more: nothing installs the
build into the server, and the editor decides whether the running server
can be reused by a checksum of the build's files with the reports left
out (913's `test_map.STAMP_LEAVES_OUT`), since the server reads its tables
only at start.

*Now:* see Implementation Notes. Step 1 is built: the converter writes
`server-stamp`, and the editor reuses the server by it. Step 2 is built
as data (2026-11-05): the converter copies the shim into the build and
writes `install-plan.lua`, what an install would do, checked against a
stand-in for the empty world database; nothing installs it yet.

## Intended Behavior

From W02's table (2026-09-23): **Launcher:** start authserver and
worldserver, install `patch-W.MPQ` in the client's `Data/`, write
`realmlist.wtf`, clear the client's creature and object cache
(`Cache/WDB`), start the client. **Loader:** pick a `.w3x`, run W02a-e,
restart the worldserver (it reads map tables only at start), and put the
character at the WC3 start location.

Since 2026-11-04 the editor's Test Map is the launcher for the W client
(issue 913: the editor starts and keeps the server, and opens the W client
on the build); what is left here is the server's side of it and the stock
client's.

## Suggested Implementation Steps

1. **The server's stamp.** The converter names exactly the files of the
   build the server reads, each with a checksum, so the server is started
   again exactly when they change.
2. Install the build into the server: the rows of `server/world.sql` and
   `server/dbc.sql` into the world database, `server/dbc/` where the
   worldserver reads its tables, the shim and `server/triggers/` where ALE
   reads scripts, and W02d's map files.
3. Restart the worldserver when the stamp changes (913's server keeper
   does the stopping and starting; this step gives it the install to run
   between).
4. The stock client: `patch-W.MPQ` into its `Data/`, `realmlist.wtf`,
   `Cache/WDB` cleared.
5. The character at the map's start (`map.lua`'s start, the server's
   teleport).

## Acceptance Criteria

- [x] The converter writes `server-stamp`, naming the server's files of
      the build and their checksums; two conversions of the same map give
      the same stamp, byte for byte.
- [x] The editor reuses the running server while the stamp is the same,
      and starts it again when it changes.
- [x] The converter writes `install-plan.lua`: which rows go into which
      database and table, which files (the shim's among them) go to which
      of the server's folders; it fits a stand-in for the empty world
      database, its build folder and its stamp. *(Added 2026-11-05, step
      2 in data form.)*
- [ ] A converted map's rows, tables and scripts are installed into a
      local AzerothCore, which starts with them.
- [ ] The stock client opens a converted map with `patch-W.MPQ` installed.

## Notes

- Written by hand from W02's table (2026-11-05), as W02a was, not by the
  issue-splitter.
- AzerothCore is installed by the user, not bundled
  (`docs/licensing-and-boundaries.md`).

## Decisions (2026-11-05, step 1; each the owner's to overturn)

- **The stamp names what the server reads, by kind, for every map in the
  folder:** `server/world.sql`, `server/dbc.sql`, `server/dbc/*.dbc`,
  `server/triggers/<dir>/war3map.lua` and `map-data.lua`, and
  `patch-W.MPQ` (the extractors read it for W02d's map files). The list is
  `wowbuild.server_stamp.READS`, beside the converter that writes those
  files, so a new server file is added where it is written. Left out: the
  W client's files and the reports (`conversion-report.lua`,
  `placements.lua`, `registration.lua`, `natives-report.lua`), which hold
  when they were written or how long that took.
- **The shim's own folder (`server-side/ale/wc3shim/`) isn't in the stamp
  yet.** It is in this repository, not the build, and nothing installs
  it into a server until step 2; when step 2 copies it, its files join
  the stamp.
- **Format:** a text file, `server-stamp`: a `#` comment, `format 1`, then
  one line a file, `<CRC-32, 8 hex digits> <size> <path>`, sorted by path,
  with nothing that changes from one conversion to the next. The CRC-32
  is zlib's, as `src/gamedata/bsd0.lua` already uses it; it is a change
  check, not a guard against tampering. Written last, whole (another
  name, then renamed), and removed at the start of each conversion once
  it is past its refusals, so a stamp never names files a stopped
  conversion left half written.
- **The editor reads it as the build's stamp, and has no fallback.** The
  whole-build checksum with reports left out (913's
  `test_map.STAMP_LEAVES_OUT`) is retired: it had to know every report the
  converter writes, and missed each new one (two had already been found).
  A build with no readable stamp (a converter that writes none) counts as
  new each time: the server is started again, and the editor says why. That
  is slower, never wrong; the project's habit is to refuse or say, not to
  guess (913's strict receipts, the W client's "fallbacks are warnings").
  The editor also removes the old stamp before converting, as it does an
  old receipt before launching, so a converter that writes none can't reuse
  a server on an earlier build's stamp.

## Implementation Notes

*(2026-11-05, step 1: the server's stamp)*

- `src/wowbuild/server_stamp.lua`: `READS`, `files`, `text`, `write`,
  `remove`, `read`.
- `src/wowbuild/init.lua`: `wowbuild.convert` removes the old stamp before
  it touches the folder and writes the new one after every other file;
  the report lists it (`server_stamp.files`) and `STAGES_NOT_BUILT` names
  W02f's later steps.
- The editor's side is issue 913's (`src/editor/test_map.lua`: `T:stamp`).
- **Tests:** `src/tests/test_wow_server_stamp.lua` (23): exactly the
  server's files, every map's, sorted, and none of the reports, the
  client's files, a non-table in `server/dbc/` or a folder named like a
  table; the line format and zlib's CRC-32; reports and client files
  written anew give the same stamp, a changed or missing server file
  another; written whole and read back; refused with no format line,
  format 2 or a bad line; W02's converter on Daow 4.4 writing it, naming
  only server files, the same byte for byte when converted again (while
  its report changed), and a refused conversion leaving the folder as it
  was. `test_wow_placements` and `test_wow_terrain` allow the new file in
  their lists of what a build holds.

**Still open:** steps 2-5, all of which need AzerothCore on the owner's
machine.

## Decisions (2026-11-05, step 2 in data form; each the owner's to overturn)

- **The install is written down before anything installs it.** The
  converter writes `<build>/install-plan.lua` (data, read in an empty
  environment): `sql` (the build's SQL files in the order they run, and
  their database), `tables` (each statement: database, table, what it
  does, its columns or its width, its rows; a delete with its `WHERE`),
  `files` (each file from the build to a *place* and a path under it),
  `kept` (server files nothing installs, with why), `places` (what each
  place is, all `checked = false`) and `waiting` (what an install needs
  that isn't built). Step 3 runs it; the plan says what it will do, so
  it can be read and checked first.
- **Places are names, not paths.** `world` (a database), `dbc`,
  `ale_scripts`, `ale_maps` (folders). The owner's machine says where
  each is (step 3's settings), so a build folder holds no machine's
  paths and the same build installs into any server.
- **The shim is copied into the build** (`server/ale/wc3shim/*.lua` and
  `server/ale/LICENSE`), as bytes, every module but `fake_ale.lua`; the
  plan installs it from there. So the build holds everything the server
  gets, the stamp can name the shim beside the map's files, and an
  install never reads this repository. The converter still runs none of
  the shim's code (`server-side/README.md`).
- **The shim's modules join the stamp** (`server_stamp.READS`:
  `server/ale/wc3shim/*.lua`): a changed shim starts the server again.
  Not its licence (the server doesn't read it) and not
  `install-plan.lua` (the install reads it; the server reads what it
  installs, which the stamp names already).
- **A map's script and data go to `ale_maps`, not `ale_scripts`:** ALE
  runs every `.lua` in its scripts folder (from memory, W02e's left open
  5), and a map's transpiled script runs only inside the shim. The shim
  goes to `ale_scripts/wc3shim/`; step 3's loader, also there, reads a
  map's files from `ale_maps`.
- **SQL order:** `server/dbc.sql` (the client tables' rows) before
  `server/world.sql` (the creatures that name those factions and display
  ids). Both into `world`.
- **A merged table replaces the stock one** in `dbc`, and the plan says
  so (`replaces`): the install keeps the stock file to put back (step 3).
- **`patch-W.MPQ` is kept**, not installed: it is the stock client's (step
  4) and the extractors' (W02d), not the server's.
- **Checked against a stand-in, by a check step 3 reuses.**
  `install_plan.check(plan, schema, build_dir)`: every table and column
  exists, every row has as many values as its table wants (its columns,
  or its width for a table filled by position), no statement it can't
  place, every file is in the build, goes to a named folder place and a
  path inside it, no two files go to one path, the stamp names every
  file installed (but the licence), and every file the stamp names is
  installed, run or kept. The stand-in
  (`src/tests/fixtures/install-plan/empty-world-schema.lua`) is the
  converter's own tables and columns, copied by hand: it shows the plan,
  the SQL and one declared schema agree, not that AzerothCore's does.
  Step 3 reads the owner's real schema and runs the same check before
  installing anything.
- **The plan is removed at the start of each conversion** with the stamp,
  and written before it, so a stopped conversion leaves neither.

### Unchecked: what step 2 relies on from memory

Nothing here was read from AzerothCore or ALE; this repository has no
copy of either. Each needs checking on the owner's machine before step 3
installs anything:

1. The world database's name: the worldserver's settings name it; this
   repository's archived notes (`docs/archive/azerothcore-2026-01-07/`)
   call it `acore_world`.
2. The world tables and their columns as the converter writes them
   (`creature`, `creature_template`, `creature_template_model`,
   `creature_model_info`: `src/wowbuild/creatures.lua`), and the
   `<table>_dbc` copies with the DBC files' columns in order
   (`src/wowbuild/dbc.lua`, every layout `checked = false`), including
   whether the server reads those copies over its DBC files.
3. Where the worldserver reads its DBC files: the owner's extracted data
   has `dbc/` (`docs/wow-client-bridge.md`); that the worldserver reads it
   through its data folder setting, and only at start, is from memory.
4. ALE's scripts folder (`lua_scripts/`), that it runs every `.lua`
   under it, and how `require("wc3shim")` finds the shim there (W02e's
   left open 5; the local checkout is still `mod-eluna`).
5. That the worldserver starts with W02h's empty tables plus a map's
   rows (W02h's first step: measure what it refuses to start without).

## Implementation Notes (continued)

*(2026-11-05, step 2 in data form: the install plan)*

How it was before: the build held the server's files and a stamp naming
them, and nothing said where any of them would go; the shim lived only in
this repository.

- `src/wowbuild/install_plan.lua`: `SHIM`, `SQL`, `PLACES`, `copy_shim`,
  `statements` (the converter's own SQL, statement by statement: quoted
  text, `''` and `\` escapes, comments, line breaks inside text), `make`,
  `write`, `remove`, `read`, `check`.
- `src/wowbuild/init.lua`: `convert` removes the old plan with the old
  stamp, copies the shim after the triggers, writes the plan, then the
  stamp; the report has `install_plan` (counts), and `STAGES_NOT_BUILT`
  says steps 1-2 are built.
- `src/wowbuild/server_stamp.lua`: `READS` names
  `server/ale/wc3shim/*.lua`.
- `src/tests/fixtures/install-plan/empty-world-schema.lua`: the stand-in.
- **Tests:** `src/tests/test_wow_install_plan.lua` (68, new): the SQL
  reader; the shim copied byte for byte without `fake_ale.lua`, with its
  licence, an old module removed on the next copy, a missing shim
  refused; the plan of a folder made by hand (order, tables, rows and
  values, each file's place and path, the reports and `map.lua` left out,
  `patch-W.MPQ` kept, the waiting list, four unchecked places), written
  the same byte for byte; read in an empty environment, refused at format
  2; the check passing on the stand-in and failing, with its reason, on
  a missing table, column or database, a wrong width, rows of uneven
  width, a statement it can't place, a path leaving its place or
  absolute, two files to one path, an unnamed place, a stamped file not
  accounted for, a file the stamp doesn't name, a file the build lacks;
  the stamp naming the shim, changing with it, not with the plan; W02's
  converter on Daow 4.4 writing a plan that fits the stand-in, its folder
  and its stamp, the same byte for byte when converted again, left as it
  was by a refused conversion. `test_wow_server_stamp` 23 unchanged;
  `test_wow_placements` and `test_wow_terrain` allow `install-plan.lua`
  and `server/ale/` in a build.

**Still open:** step 3 (read the owner's schema and places, check, install,
restart), steps 4-5, and the unchecked list above.
