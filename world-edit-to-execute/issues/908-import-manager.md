# Issue 908: Import Manager

**Phase:** 9
**Type:** Implementation
**Priority:** High
**Dependencies:** 901 (Editor core), Phase 6 (Asset system)

---

## Current Behavior

Assets can be loaded from maps but not imported, organized, or managed within the editor.

## Intended Behavior

Full import management with feature parity to WC3 Import Manager, integrated with the Asset Browser (Phase 6B):

### Import Manager Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ IMPORT MANAGER                                      [x] Close       │
├─────────────────────────────────────────────────────────────────────┤
│ ┌───────────────────────────────┬───────────────────────────────┐   │
│ │ IMPORTED FILES                │ FILE DETAILS                  │   │
│ │                               │                               │   │
│ │ ▶ Models (3)                  │ Custom Hero.mdx               │   │
│ │   ├─ 🎭 Custom Hero.mdx      │ ─────────────────────────────  │   │
│ │   ├─ 🎭 Boss Monster.mdx     │ Path: war3mapImported\        │   │
│ │   └─ 🎭 Special Effect.mdx   │       CustomHero.mdx          │   │
│ │ ▶ Textures (5)                │                               │   │
│ │   ├─ 🖼️ HeroPortrait.tga     │ Type: Model (MDX)             │   │
│ │   ├─ 🖼️ CustomTerrain.blp    │ Size: 245 KB                  │   │
│ │   ├─ 🖼️ ItemIcon.blp         │ Status: ✓ Valid               │   │
│ │   ├─ 🖼️ AbilityIcon.blp      │                               │   │
│ │   └─ 🖼️ UI_Frame.tga         │ Used By:                      │   │
│ │ ▶ Sounds (2)                  │   ├─ Custom Footman (x001)   │   │
│ │   ├─ 🔊 CustomSpell.wav      │   └─ Boss Fight (trigger)    │   │
│ │   └─ 🔊 VictoryMusic.mp3     │                               │   │
│ │ ▶ Scripts (1)                 │ [Preview] [Replace] [Delete]  │   │
│ │   └─ 📜 CustomLib.lua        │                               │   │
│ │                               │ ┌─────────────────────────┐   │   │
│ │ Total: 11 files (1.2 MB)     │ │                         │   │   │
│ │                               │ │   [Model Preview]       │   │   │
│ │ [+ Import...] [Export...]    │ │                         │   │   │
│ │ [Validate All]               │ └─────────────────────────┘   │   │
│ └───────────────────────────────┴───────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Import Dialog

```
IMPORT FILES
┌────────────────────────────────────────────────────────────┐
│ Select files to import:                                    │
│                                                            │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ [Browse...] /home/user/assets/                         │ │
│ ├────────────────────────────────────────────────────────┤ │
│ │ [x] CustomHero.mdx                    245 KB           │ │
│ │ [x] HeroPortrait.tga                   64 KB           │ │
│ │ [ ] OldVersion.mdx                    312 KB           │ │
│ │ [x] SpellEffect.mdx                    89 KB           │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ Import as:                                                 │
│   ○ Full path: war3mapImported\CustomHero.mdx             │
│   ● Custom path: [Units\Hero\CustomHero.mdx____]          │
│                                                            │
│ Options:                                                   │
│   [x] Overwrite existing                                  │
│   [ ] Convert textures to BLP                             │
│   [ ] Optimize models                                      │
│                                                            │
│                              [Import] [Cancel]             │
└────────────────────────────────────────────────────────────┘
```

### File Types

| Category | Extensions | Description |
|----------|------------|-------------|
| **Models** | .mdx, .mdl, .m2 | 3D models |
| **Textures** | .blp, .tga, .png, .dds | Images |
| **Sounds** | .wav, .mp3, .ogg | Audio |
| **Icons** | .blp, .tga | UI icons |
| **Scripts** | .lua, .j, .ai | Code files |
| **Fonts** | .ttf, .otf | Custom fonts |
| **Data** | .txt, .slk | Data tables |

### Path Management

```
PATH EDITOR
┌────────────────────────────────────────────────────────────┐
│ Import Path Mapping                                        │
├────────────────────────────────────────────────────────────┤
│ Original Path        → Map Path                           │
├────────────────────────────────────────────────────────────┤
│ Units/Footman.mdx    → war3mapImported\Footman.mdx       │
│ Textures/Grass.blp   → war3mapImported\Grass.blp         │
│ Sound/Spell.wav      → war3mapImported\Spell.wav         │
│                                                            │
│ [Edit Path] [Auto-Path] [Reset to Default]                │
└────────────────────────────────────────────────────────────┘
```

### Validation

```
VALIDATION RESULTS
┌────────────────────────────────────────────────────────────┐
│ ✓ CustomHero.mdx        Valid MDX, 3 animations          │
│ ✓ HeroPortrait.tga      Valid TGA, 256x256               │
│ ⚠ CustomTerrain.blp     Non-power-of-2 size (300x300)    │
│ ✗ BrokenModel.mdx       Parse error at offset 0x4F20     │
│ ✓ SpellSound.wav        Valid WAV, 2.3 sec, 44.1kHz      │
│                                                            │
│ 4 valid, 1 warning, 1 error                               │
│                                                            │
│ [Fix Issues] [Remove Invalid] [Ignore]                    │
└────────────────────────────────────────────────────────────┘
```

### API Design

```lua
local imports = require("editor.imports")

-- Import files
imports.import_files({
    "/path/to/model.mdx",
    "/path/to/texture.tga",
}, {
    base_path = "war3mapImported",
    overwrite = true,
})

-- Import with custom path
imports.import_file("/path/to/hero.mdx", "Units/Hero/CustomHero.mdx")

-- List imports
local all = imports.list()
local models = imports.list_by_type("model")

-- Get import info
local info = imports.get_info("war3mapImported/hero.mdx")
-- { path, type, size, valid, used_by, preview }

-- Validate imports
local results = imports.validate_all()
for _, result in ipairs(results) do
    print(result.path, result.status, result.message)
end

-- Find unused imports
local unused = imports.find_unused()

-- Export imports
imports.export_file("war3mapImported/hero.mdx", "/output/path/")
imports.export_all("/output/folder/")

-- Delete import
imports.delete("war3mapImported/old_model.mdx")

-- Preview
imports.preview("war3mapImported/hero.mdx")  -- Opens in appropriate viewer
```

### Integration with Asset Browser

```
ASSET BROWSER INTEGRATION
┌────────────────────────────────────────────────────────────┐
│ The Import Manager is a subset of the Asset Browser:      │
│                                                            │
│ ASSET BROWSER (Phase 6B)                                  │
│   ├─ Browse all assets in map/server                      │
│   ├─ Import new assets ← Import Manager                   │
│   ├─ Preview assets                                        │
│   ├─ Edit assets (texture paint, model tweak)             │
│   └─ Export/share assets                                   │
│                                                            │
│ For Phase 9, Import Manager provides:                     │
│   ├─ File import functionality                            │
│   ├─ Path management                                       │
│   ├─ Validation                                            │
│   └─ Basic preview                                         │
│                                                            │
│ Full editing deferred to Asset Browser phase              │
└────────────────────────────────────────────────────────────┘
```

## Suggested Implementation Steps

1. Create `src/editor/imports/` module structure
2. Implement import file list view
3. Implement import dialog with file browser
4. Implement path management
5. Implement file type detection
6. Implement validation for each file type
7. Implement preview for each file type
8. Implement "used by" tracking
9. Implement export functionality
10. Implement unused file detection
11. Integrate with Asset Browser (Phase 6B) hooks
12. Integrate with undo/redo
13. Create tests

## Acceptance Criteria

- [ ] Files importable via browse dialog
- [ ] Multiple files importable at once
- [ ] Custom import paths configurable
- [ ] File type auto-detected
- [ ] All file types validated
- [ ] Preview works for models, textures, sounds
- [ ] "Used by" shows which objects reference import
- [ ] Unused imports identifiable
- [ ] Export individual or all imports
- [ ] Delete with orphan warning
- [ ] All operations support undo/redo

## Related Documents

- Phase 6 - Asset system
- Phase 6B - Asset Browser (future)
- `src/assets/loader.lua` - Asset loading

## Notes

- Consider drag-and-drop import from file manager
- Large file import should show progress
- May want "batch rename" for path changes
- Texture format conversion (TGA→BLP) useful but complex
- Model optimization could reduce file size
- Consider "import history" for recently imported files
