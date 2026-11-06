# Issue W10h: patch-W.MPQ Never Behind the Folder, and More Areas a Map

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (step 8's save, and step 4's areas), following W10g
**Priority:** High for the patch (the stock client and AzerothCore's extractors could read ground the editor had changed since), Medium for the areas
**Dependencies:** W10g (the map's own areas, the folder's forms), the W02 chain (wowbuild.output, server_stamp, install_plan), W10a (the map project's WoW layer)
**Blocks:** installing an edited WoW map (W02f step 3)

---

## Current Behavior

*As written (2026-11-05, before this issue's work):*
- **The patch lagged behind edits.** A save remade `patch-W.MPQ` only when a map's area rows changed (W10g decision 10). `patch-W.MPQ` carries every registered map's ground files (WDT, WDL, ADTs, loading screen) for the stock client and AzerothCore's extractors (W02c, W02d). So a ground, water, object or tile edit saved into a build folder left an older copy of that ground in the patch.
- **So did the server's stamp and the install plan.** The folder's `server-stamp` and `install-plan.lua` (W02f), which name the patch's CRC and the server's files, were left naming what had changed.
- **A map had at most nine areas besides its zone** (W10g decision 2).
- **A project's WoW build dropped the tables.** In a map project, the tables and patch the editor writes into `wow/` were warned about as "not under wow/World/" and left out of its WoW build (`mapfile.build_wow`).

*Now:* see Implementation Notes.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #265 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- Areas past the ninth draw explored-zone bits from one shared pool, but the "taken" check reads other maps' registrations from disk, so two open maps can each pick the same bit before saving; exploring one marks the other explored.
- If rebuilding the tables or patch fails, the tiles and registration are already written and marked clean and the area-changes flag already cleared, so the next save writes nothing and never retries; the folder stays without patch, stamp or plan.
- Several early returns in the save come after files are written but before the rebuild, leaving the old `patch-W.MPQ` and server stamp describing ground the folder no longer has.
- The project build copies the layer's patch and tables as they are, but re-adding a map never rebuilds them, so a build can ship a stale patch; an old `patch-W.MPQ` left in the output folder is never removed.
- WC3 validation and export still warn about every `wow/` table and patch file on each save (validate_wow was fixed, the WC3 gatherer wasn't).
- With stock tables unset, the player's whole AzerothCore stock tables are merged into the project's `wow/` and packed into the shareable `.wex`.
- Writing the server stamp isn't protected, so a disk error is raised through the editor's save after the old stamp was removed.
- Every save, even a one-chunk raise, rebuilds every table and the whole patch from every map, once per opened map in the folder.
- A taken own bit and a missing slot (falling back to slot 0's id block) are both handled silently.

## Intended Behavior

- **A save never leaves `patch-W.MPQ` holding what the folder no longer holds.** It is made again, or removed when it can't be.
- **The stamp and plan follow.** The folder's server-stamp and install plan are written again after the patch, or removed.
- **A map can have up to 99 areas besides its zone**, every id and explored bit its own across the folder.
- **A project's WoW build carries the tables and the patch.**

## Suggested Implementation Steps

1. `editor/wowareas.lua`: `ar.forms(m)` makes the folder's forms again after a save. When the patch can't be made it removes it, then writes the plan and stamp again. `ar.save` writes only the registration.
2. `editor/wowterrain.lua`: `wt.save` calls `ar.forms` after anything written. `E:wow_save` says its warnings.
3. `wowbuild/registration.lua`: a second area block (`area_more`), the bit pool's floor, and `in_scheme` covering both blocks.
4. `editor/wowareas.lua`: `create` takes ids from both blocks and pooled bits.
5. `editor/mapfile.lua`: the forms are part of the WoW layer and of its build.
6. Tests: `test_wow_patch_and_areas.lua` (new), with a stand-in for StormLib.

## Acceptance Criteria

- [x] **Every edit kind:** after a save of ground, water, an object, a tile added or a tile taken off, `patch-W.MPQ` carries every map file of the folder byte for byte, and only those. The stamp is the folder's, and the plan is written again.
- [x] Nothing edited: nothing written, and the patch is not made again.
- [x] **No StormLib:** the save goes through, the old patch is removed, and a warning says so (the converter's own warning). The stamp is written again without the patch, and `E:wow_save` says it.
- [x] **A failure while making the patch:** the save says so. The old patch, the stamp and the plan are removed, and the tile itself is written.
- [x] `patch = false`: the old patch is removed, said.
- [x] A map W02c didn't register: no patch carries it, so nothing is made for it.
- [x] **Projects:** a project's WoW layer validates with its tables and patch, and its WoW build carries them.
- [x] **More areas:**
  - 99 areas besides the zone, then refused;
  - the first nine as before, the rest from the slot's second block with the bit block's lowest free bits;
  - painted, saved and named;
  - a second map converted into the folder: its own first bits, its tenth area the next free bit, and no id or bit twice in the folder's AreaTable;
  - the patch made again with both maps.
- [ ] **On the owner's machine** (decision 7):
  - the real StormLib archive, read back by the stock client and AzerothCore's extractors after an edit;
  - an area past the first nine, named in the stock client.

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. Rebuild `patch-W.MPQ` at every save, or mark it stale for Test Map's launch check to refuse or rebuild?
2. What happens when it can't be made?
3. Which saves make it again, and what else follows it?
4. What of a map W02c didn't register, and of a map project's `wow/`?
5. Lift the nine-areas cap: how, keeping ids and bits collision-free?
6. Which bits do pooled areas take?
7. What is checked here, and what on the owner's machine?

## Decisions (2026-11-05; each the owner's to overturn)

1. **Made again at every save that wrote a file it carries, not marked stale.**
   - A marker only protects readers that check it. The stock client and AzerothCore's extractors read `patch-W.MPQ` itself and check nothing, so a marked but stale patch would still be read stale.
   - Test Map's launch check (`check_launch`, #249) could refuse on a marker, but Test Map converts into a build folder of its own (under the project's `tmp/`) and starts the W client on that. The editor never saves into it, so that folder's patch is always the converter's own, fresh.
   - So the editor's save makes the patch again from the folder (`wowbuild.output.write`, as the converter does) whenever it wrote any file of a registered map. When it can't, it removes the patch (decision 2). Either way, no reader can find a patch that disagrees with the folder.
   - The cost is one archive per save. Making a patch is the converter's own step, and a save is a person's action, not a stroke.
2. **Can't be made: removed, and said.**
   - **No StormLib:** `output.write` already removes an older patch and warns ("patch-W.MPQ not written (an older one removed)"). The save goes on, and `E:wow_save` says the warning.
   - **`opts.patch == false`:** the old patch is removed with a warning, since `output.write` would otherwise leave it.
   - **Any failure while making the forms:** the old patch and the install plan are removed, and the save returns the error, saying the patch was removed. The tiles written before stay written; they are the edit.
3. **After any file written; the plan and stamp after it.**
   - The trigger is any save that wrote something: tiles (ground, holes, paint, water, objects), the WDT and WDL, tiles taken off, or `registration.lua`.
   - The whole folder's forms are made again as the converter makes them: the overlay's `DBFilesClient`, `server/dbc.sql`, the merged tables when stock tables are given, and `patch-W.MPQ`. The converter writes them as one, and every registered map in the folder is in each.
   - The server-stamp is removed first, so none ever names files being changed. The install plan is written again when the folder had one, then the stamp last, as the converter does. A plan that can't be written again is removed, said.
   - A save that wrote nothing makes nothing.
4. **Unregistered maps are left alone; a project's `wow/` carries its forms.**
   - **Unregistered maps:** `patch-W.MPQ` carries only maps W02c registered, so a save of any other map leaves the folder's forms as they are (`m.forms.skipped`).
   - **Projects:** in a map project, the forms the editor writes beside the maps (`DBFilesClient/*.dbc`, `server/dbc.sql`, `server/dbc/*.dbc`, `patch-W.MPQ`) are part of the WoW layer. They aren't warned about, and `mapfile.build_wow` carries them out with the maps. Before this, W10g's tables never left a project.
5. **A second id block of 90 a slot (10000-18999), and bits from a shared pool.**
   - **Ids:** a map's first nine areas keep the zone's block (W10g). Its next 90 take `area_more`: 10000 + 90 × slot, so slots 0-99 cover 10000-18999. That is under 65536 (the server's 16-bit areas) and above the stock table's ids as remembered (about 4990, unchecked).
   - **Merging:** `registration.in_scheme("area", id)` covers both blocks, so a stock row inside either is replaced in a merge, and the stock bits are read as the stock's.
   - **Limit:** a map holds at most 100 areas with its zone (`ar.MAX`).
   - **Why ids aren't the limit:** the client keeps 4096 explored bits, the zones take 100 and the areas' block 900. A fixed share of 99 bits a slot can't fit, so the bits of areas past the ninth come from the block as a pool, shared by the folder's maps (decision 6).
   - **Collision-free:** within a folder, ids by the slot blocks (disjoint) and bits by checking every map's rows (and the stock table's, when given). A folder is what is installed together.
6. **Pooled bits: the lowest free of 3096-3995.**
   - An area past its map's ninth, or one whose own bit is taken, takes the lowest free bit of the areas' block. Those are the bits of the slots a folder fills last, since slots are taken lowest first.
   - This replaces W10g decision 3's fallback (the highest free bit, down to 0). The pool now never leaves the block, so a pooled bit never falls among the stock table's lower bits when no stock table is given.
   - When the block is full, a new area is refused, saying so.
7. **Checked by code here; StormLib and the stock readers on the owner's machine.**
   - **Here, through a stand-in for StormLib** (the tests' `package.loaded["mpq.stormlib"]`, which writes an archive as a plain list of its files), what the patch would carry is compared with the folder, file by file, after every kind of save. The no-StormLib path runs as it would here, and so do a failure and `patch = false`.
   - **Read back through the W client's reader:** the tables (`wowmap.area_names`) and the tiles.
   - **Unchecked:** the real StormLib archive (its listfile and compression) after an edit; the stock client and AzerothCore's extractors reading it; areas past the ninth in the stock client.

## Implementation Notes

*(2026-11-05)*

- **`src/editor/wowareas.lua`:**
  - `ar.forms(m)` (new): `output.write` over the map's root; on failure the patch and plan are removed; on `patch = false` the patch is removed; the plan and stamp are written again. Its result is kept as `m.forms`: files, warnings, patch, skipped.
  - `ar.save(m)` now writes only `registration.lua`.
  - `ar.create`: both id blocks, pooled bits, `ar.MAX`.
- **`src/editor/wowterrain.lua`:**
  - `wt.save` calls `ar.forms` after anything written;
  - `E:wow_save` says the forms' warnings, and says a failed save's reason.
- **`src/wowbuild/registration.lua`:** `SCHEME.area_more`, `SUBAREA_BIT_FLOOR`, `ALSO`, and `in_scheme` covering a kind's other blocks.
- **`src/editor/mapfile.lua`:** `mapfile.wow_form(path)`; `validate_wow` accepts the forms; `build_wow` copies them.
- **Tests:**
  - `src/tests/test_wow_patch_and_areas.lua` (new): 38 with the library, 1 skipped without.
  - `test_wow_area_rows.lua`: the nine-area cap and the stock-bit fallback follow decisions 5 and 6.
  - The other tests are unchanged; see the PR for counts.

**Still open:**
- decision 7's checks on the owner's machine;
- installing an edited folder (W02f step 3), which now finds its patch, plan and stamp current or absent.
