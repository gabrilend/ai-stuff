# Issue 911a: Writing Maps Back

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** Critical
**Parent:** 911 (map format export)
**Dependencies:** 114 (StormLib), the w3e / doo / unitsdoo parsers

---

## Current Behavior

Maps can only be read. No parser writes its format, and the StormLib binding opens archives read-only. An editor could change nothing that lasts.

## Intended Behavior

- **Values:** `parsers/binwrite.lua` writes little-endian values the way `compat` reads them.
- **File formats:** each writes back what its parser read, byte for byte.
  - `w3e.write`: the terrain. Heights and water come from world units, so an editor changes those; water's top bits are kept.
  - `doo.write`: the doodads, with the special-doodad section kept as read.
  - `unitsdoo.write`: placed units. Each entry is its bytes as read, with type, variation, position, angle, scale, flags, player and creation number written over. A unit made in the editor copies the bytes of a unit of its kind (`unitsdoo.template`).
- **Saving:** `mpq.save_copy(src, dst, files)` saves a copy with files changed or added.
  - **In place:** it works inside the map's own archive (`mpq/patch.lua`), so every other file stays as it was, including files nobody knows the name of. The changed bytes go at the end, stored plain; their block entries are repointed; added files get a hash slot and a block entry; the block table is written again, longer, and the header updated.
  - **Listfile:** it names the added files.
  - **Protected maps:** this works on them too. StormLib opens them only to read, and DAoW 5.4b's 199 imports have no known names.
  - **Checking:** the copy is read back through StormLib; if a given file doesn't read back as given, `mpq.rebuild_copy` builds a new archive instead. That copy carries over only files whose names are known (listfile, usual map files, war3map.imp) and keeps the map's 512-byte HM3W header in front.
  - **Safety:** the map read is never written.
- **StormLib binding:** `open_writable`, `create`, `Archive:write` (zlib, replacing), `remove` and `flush`.

## Acceptance Criteria

- [x] Terrain and doodads of all 16 test maps, and the 5 placed-unit files, write back byte for byte
- [x] An edited tilepoint and moved or added units read back as edited, the rest as it was
- [x] Saved copies of DAoW 5.4b (protected) and Daow 4.4: patched in place; the changed and added files read back; every other file present and unchanged; the copy loads as a map
- [x] Refuses to write over the map it read; the rebuilt copy carries the named files and the header
- [x] Tests: test_map_save (18)

## Notes

- **Space:** the old bytes of a replaced file aren't reclaimed, so a copy grows by what's saved each time.
- **(attributes):** checksums aren't brought up to date. WC3 doesn't check them on load, as far as known; to check.
- **Placed units in scripts:** protected maps like DAoW create their units in the script, not in war3mapUnits.doo. Changing those is the editor's job (issue 903).
