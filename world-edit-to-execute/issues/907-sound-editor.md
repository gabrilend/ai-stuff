# Issue 907: Sound Editor

**Phase:** 9
**Type:** Implementation
**Priority:** High
**Dependencies:** 901 (Editor core), 205 (Sound parser)

---

## Current Behavior

Sounds can be parsed (war3map.w3s) but not created, placed, or edited.

## Intended Behavior

Full sound editing with feature parity to WC3 Sound Editor:

### Sound Types

| Type | Description |
|------|-------------|
| **3D Sound** | Positional audio with falloff |
| **2D Sound** | Non-positional (UI, music) |
| **Ambient** | Looping environmental sounds |
| **Music** | Background music tracks |
| **Speech** | Voice/dialogue clips |

### Editor Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ [Sounds] [Music] [UI Sounds]                                        │
├──────────────────────────────┬──────────────────────────────────────┤
│ SOUND LIST                   │ SOUND PROPERTIES                     │
│                              │                                      │
│ ▶ Ambient                    │ ┌──────────────────────────────────┐ │
│   ├─ 🔊 Forest Ambience     │ │ Forest Ambience                  │ │
│   ├─ 🔊 Water Stream        │ │ File: Ambient\Forest.wav         │ │
│   └─ 🔊 Wind                │ └──────────────────────────────────┘ │
│ ▶ Combat                     │                                      │
│   ├─ 🔊 Sword Hit           │ VOLUME & PITCH                       │
│   ├─ 🔊 Spell Cast          │ ┌──────────────────────────────────┐ │
│   └─ 🔊 Death Scream        │ │ Volume:     [====|=====] 80%     │ │
│ ▶ Music                      │ │ Pitch:      [=====|====] 1.0x    │ │
│   ├─ 🎵 Battle Theme        │ │ Pitch Variance: [|========] 0%   │ │
│   └─ 🎵 Victory             │ └──────────────────────────────────┘ │
│                              │                                      │
│ [+ New Sound]                │ 3D SETTINGS                          │
│ [+ Import...]                │ ┌──────────────────────────────────┐ │
│                              │ │ [x] 3D Sound                     │ │
│                              │ │ Min Distance: [300____]          │ │
│                              │ │ Max Distance: [3000___]          │ │
│                              │ │ Cutoff:       [5000___]          │ │
│                              │ └──────────────────────────────────┘ │
│                              │                                      │
│                              │ PLAYBACK                             │
│                              │ ┌──────────────────────────────────┐ │
│                              │ │ [x] Looping                      │ │
│                              │ │ [ ] Stop on Leave Range          │ │
│                              │ │ Fade In:  [0.5__] sec            │ │
│                              │ │ Fade Out: [1.0__] sec            │ │
│                              │ └──────────────────────────────────┘ │
│                              │                                      │
│                              │ [▶ Preview] [■ Stop]                 │
└──────────────────────────────┴──────────────────────────────────────┘
```

### Sound Placement (Map View)

```
SOUND REGIONS
┌────────────────────────────────────────────────────────────┐
│                                                            │
│      ┌─────────────────┐                                  │
│      │   🔊            │  ← Ambient sound region          │
│      │  Forest         │    (plays when camera in region) │
│      │  Ambience       │                                  │
│      └─────────────────┘                                  │
│                                                            │
│            🔊  ← Point sound (3D positional)               │
│         Waterfall                                          │
│                                                            │
└────────────────────────────────────────────────────────────┘

PLACED SOUNDS (VIEWPORT)
┌────────────────────────────────────┐
│ ● 🔊 Waterfall     (point)        │
│ ■ 🔊 Forest Amb    (region)       │
│ ● 🔊 Combat Zone   (point)        │
└────────────────────────────────────┘
```

### Music Manager

```
MUSIC PLAYLIST
┌────────────────────────────────────────────────────────────┐
│ Playlist: [Gameplay ▼]                                     │
├────────────────────────────────────────────────────────────┤
│ Track                          Duration    Loop           │
├────────────────────────────────────────────────────────────┤
│ 1. 🎵 Exploration Theme        3:24        [x]            │
│ 2. 🎵 Combat Tension           2:45        [ ]            │
│ 3. 🎵 Victory Fanfare          0:32        [ ]            │
│ 4. 🎵 Defeat Theme             1:15        [ ]            │
│                                                            │
│ [+ Add Track] [Remove] [Move Up] [Move Down]              │
│                                                            │
│ Shuffle: [ ]   Crossfade: [2.0] sec                       │
└────────────────────────────────────────────────────────────┘
```

### API Design

```lua
local sound_editor = require("editor.sounds")

-- Create sound definition
local sound = sound_editor.create({
    name = "Forest Ambience",
    file = "Ambient/Forest.wav",
    volume = 0.8,
    pitch = 1.0,
    is_3d = true,
    min_distance = 300,
    max_distance = 3000,
    looping = true,
})

-- Edit properties
sound_editor.set_volume(sound, 0.6)
sound_editor.set_3d_distances(sound, 200, 2500)

-- Preview
sound_editor.preview(sound)
sound_editor.stop_preview()

-- Place sound on map
local placed = sound_editor.place_point(sound, x, y)
local placed = sound_editor.place_region(sound, region)

-- Music playlist
local playlist = sound_editor.create_playlist("Gameplay")
sound_editor.add_to_playlist(playlist, "Music/Battle.mp3")
sound_editor.set_playlist_shuffle(playlist, true)

-- Sound categories
sound_editor.create_category("Combat")
sound_editor.move_to_category(sound, "Combat")
```

## Suggested Implementation Steps

1. Create `src/editor/sounds/` module structure
2. Implement sound list with categories
3. Implement sound properties panel
4. Implement volume/pitch controls with preview
5. Implement 3D sound settings
6. Implement sound preview (playback)
7. Implement sound placement in map view
8. Implement point sounds
9. Implement regional/ambient sounds
10. Implement music playlist manager
11. Integrate with import manager (new sound files)
12. Integrate with undo/redo
13. Create tests

## Acceptance Criteria

- [ ] Sound definitions creatable and editable
- [ ] All sound properties configurable
- [ ] Sound preview plays in editor
- [ ] 3D sounds placeable as points on map
- [ ] Ambient sounds placeable as regions
- [ ] Sound visualization in viewport
- [ ] Music playlist management works
- [ ] Import new sound files works
- [ ] Volume/pitch sliders work
- [ ] All operations support undo/redo

## Related Documents

- `src/parsers/w3s.lua` - Sound data structure
- Issue 205 - Sound parser
- Issue 908 - Import manager (sound imports)

## Notes

- Sound preview should respect 3D positioning if listener position available
- Consider waveform visualization for audio files
- May want "sound test mode" to hear sounds in context
- Looping sounds need seamless loop point support
- Consider "ducking" settings (reduce other sounds when playing)
