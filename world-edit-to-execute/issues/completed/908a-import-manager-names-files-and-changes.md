# Issue 908a: Import Manager — the Map's Files Named, Checked, Imported, Renamed, Deleted

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** High
**Parent:** 908 (import manager)
**Dependencies:** 901 (editor core), 911a (writing maps back)

---

## Current Behavior

- **Files:** the editor saves changed map files, but can't show, add or take out the other files a map carries (models, textures, sounds).
- **No names:** none of the 16 test maps has a `war3map.imp`. The protected ones have no listfile either, so DAoW 5.4b's 201 files have no names.
- **Patcher:** the in-place patcher (`mpq/patch.lua`) can replace and add files, but can't remove them.

## Intended Behavior

### Finding the files

- **The list:** the map's files beyond its own (`war3map.*`, the listfile, `war3mapEditor.lua`, `war3mapAI\`).
- **Names:** found the way the game finds them:
  1. Every path the map refers to is gathered: its object types' string fields, its script's strings, and the textures its models name (a second round after reading the models).
  2. Each path is tried with the usual variants: `.mdl` as `.mdx`, `war3mapImported\` in front, `.blp` for `.tga`.
  3. The list is taken again through StormLib with those names (`Archive:files(names)`).
  - A file still unnamed keeps StormLib's name (`File00000041.blp`).
- **Each file shows:**
  - its kind;
  - its size;
  - what uses it (the fields, script or models that name it);
  - validation: does it read as its kind?
    - MDX: sequences, geosets, textures.
    - BLP: size, with a warning when not powers of two.
    - TGA: size and bits.
    - WAV: length and rate.
    - MP3, and text files.

### Changing files

- **Changes:** import (a new file or a replacement), rename (an unnamed file too), delete, export to disk. Each is one step to undo.
- **Saving:** writes the changes into the copy:
  - `files[name] = false` takes a file out;
  - the patcher marks its hash entries deleted and empties its block;
  - a file known only by StormLib's `FileNNNNNNNN.ext` name is taken out by its block;
  - the listfile loses the name.
  - `mpq.rebuild_copy` skips files taken out.

### The panel

- **Opening:** "Files" on the toolbar.
- **List:** the files by kind, or only the unused ones, paged to the window's height.
- **The chosen file:** name (typed to rename), what reading it says, what uses it, and a texture's picture. Export writes to a path typed; Delete takes it out.
- **Import:** a path on disk and a name in the map, both typed.

## Acceptance Criteria

- [x] DAoW 5.4b: 181 files beyond its own. 98 of them are named from what the map refers to, each with its users; the other 83 stay unnamed. 76 models and 105 textures.
- [x] Validation of models, textures, WAVs; a broken model reported
- [x] A file imported from disk, replaced, undone and redone
- [x] A named file renamed (one step to undo); an unnamed file given a name; an unnamed file deleted; a file exported
- [x] Saved in place:
  - [x] the new files there and listed
  - [x] the deleted ones gone
  - [x] every other file as it was
  - [x] the copy opens with the new names
  - [x] the game runs its script
- [x] The patcher takes files out
- [x] The panel driven headless (filter, choose, preview, rename, export, import, delete) and seen in the window

## Notes

- **Tests:** `src/tests/test_imports.lua` (42 tests).
- **No war3map.imp:** the WE's import list isn't written. The game and this engine both find files by name in the archive, so it isn't needed to play the map. The World Editor would list these files only once one is written. Writing it is left to 908.
- **Unnamed files:** DAoW's remaining 83 unnamed files are mostly things nothing refers to by a path the map holds, e.g. textures named inside models under names our variants don't produce. They stay usable by their StormLib names.
