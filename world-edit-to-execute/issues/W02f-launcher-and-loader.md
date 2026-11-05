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
`server-stamp`, and the editor reuses the server by it.

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
