# Issue 907b: The Game Heard — Sounds and Music Through the Window's Audio

**Phase:** 9 (editor; the game side)
**Type:** Implementation
**Priority:** Medium
**Parent:** 907 (sound editor)
**Dependencies:** 907a (the VM keeps sounds and logs what plays)

---

## Current Behavior

- **Nothing audible:** the VM knows what the script plays (`V.sounds_played`, `V.music`, and the world's `on_sound`), but the game's window plays nothing.
- **Preview only:** the viewer plays one sound at a time, for the sound editor's preview.

## Intended Behavior

### The viewer (`scene_viewer.c`)

- **`viewer.sound_load(bytes, ext)`:** loads a sound once and returns its id.
  - Each sound gets 4 voices (raylib's sound aliases), so repeats can overlap.
  - Up to 512 sounds.
- **`viewer.sound_play(id, volume, pitch, pan)`:** plays one.
- **`viewer.music_play(bytes, ext, loop, volume)` / `viewer.music_stop()`:**
  - streams one piece of music, updated each frame;
  - its bytes are kept, because the stream reads from them.
- **The audio device:** opened on first use, once. Without one, every call says so and nothing breaks.

### The game (`demo/wc3map/main.lua`)

- **`game.on_sound(event)`:** plays what the script plays. The files come from the map or the install (the assets reader).
- **Volume:** the sound's own volume. A 3D sound fades with its distance from the view, and pans by which side of it the sound is on.
- **Music:** a music file starts (and loops) when the script plays or sets it. A playlist label such as "Music" has no file of its own and is left alone.
- **Quiet:** `WC3_AUDIO=0` turns it all off.

### The VM

`SetMapMusic` now tells the world as well.

## Acceptance Criteria

- [x] The viewer builds with the new calls (raylib 5.5's audio)
- [x] A new map whose trigger plays an imported WAV at one second runs in the window: the game asks for the sound, the audio device is tried (none in this sandbox), and the game goes on

## Notes

- **Not heard here:** nothing is audible in this sandbox, which has no sound card. The path from the script to the audio device is exercised up to the device.
- **Tests:** the VM side (sounds kept, played sounds logged, the world hearing them) is covered by `test_sound_editor.lua`.
- **Still open:** units' own sounds (acknowledgements, attacks, deaths) come from the game's unit tables and sound files, and aren't played yet.
