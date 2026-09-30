# Issue 907a: Sound Editor — the Script's Sounds and Music, New Sounds for Triggers

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** Medium
**Parent:** 907 (sound editor)
**Dependencies:** 901 (editor core), 905a (trigger editor), 908a (import manager)

---

## Current Behavior

- **No w3s:** none of the 16 maps has a `war3map.w3s`. Their sounds are made by the script, as the World Editor writes them:
  - `set X = CreateSound(file, looping, 3D, stop when out of range, fade in, fade out, EAX)`;
  - then `SetSoundParamsFromLabel`, `SetSoundDuration`, `SetSoundChannel`, `SetSoundVolume` and `SetSoundPitch` on it.
- **DAoW 5.4b:** makes 85 sounds so. Its music is one `SetMapMusic` plus many `PlayThematicMusic` calls.
- **The game:** every sound native is a no-op.

## Intended Behavior

### The sound editor (`editor/sounds.lua`)

- **The script's sounds:** each `CreateSound` call and its setters is found, shown, and counted where played.
  - File, flags, fades, EAX, label, duration, channel, volume and pitch can be changed.
  - Saving rewrites the calls. A setter the script didn't call is added after the sound is made.
- **Music:** the file of each music call can be changed.
- **The editor's own sounds:**
  - kept with the triggers in `war3mapEditor.lua`;
  - made by `EditorInitSounds`, called first by `EditorInitTriggers`;
  - played by new trigger actions: Play sound, Stop sound, Play music.
  - Checking reports a trigger naming a sound that doesn't exist.
- **Files:** each sound's file is found in the map or the install, or reported missing.
- **Undo:** every change is one step.

### The panel (`editor/sounds_ui.lua`, "Sounds" on the toolbar)

- **List:** the sounds, paged.
- **Chosen sound:** typed file and label; toggles; - / + numbers; EAX cycled.
- **Play and Stop:** play through the window: `viewer.play_sound(bytes, ext)` and `viewer.stop_sound()`, using raylib's audio (WAV, MP3, OGG).
- **Music tab:** the music calls, with typed files.
- **Toolbar:** tool buttons are now as wide as their names.

### The game (`jass/natives/sound.lua`)

- **Sounds kept:** sounds are handles holding their settings.
- **Playing:**
  - playing one logs it in `V.sounds_played` and tells a world's `on_sound(event)`;
  - it stays marked playing until stopped or its duration passes.
- **Music:** `V.music` / `V.map_music`.
- **No sound out loud yet:** the window's game view doesn't play these (see 907's notes).

## Acceptance Criteria

- [x] DAoW 5.4b's 85 sounds read whole (file, flags, fades, EAX, label, duration, channel, volume), where they're played, and the music calls
- [x] A sound's call and setters rewritten; a missing setter added; the music's file changed; undo
- [x] A new sound, its file imported into the map and found there, played by a trigger's "Play sound"
- [x] Saved and played:
  - [x] the game's sound handles have the new settings, and the map's music is the new file
  - [x] the chat trigger played the new sound, and the world heard it
  - [x] no script errors
- [x] Opened again: the editor's sound read back once; the script's changed sound as the script now has it
- [x] The panel driven headless (choose, play through the window, step, toggle, type a label and a music file, delete, Ctrl+Z) and seen in the window

## Notes

- **Tests:** `src/tests/test_sound_editor.lua` (38 tests).
- **Stock files:** most of DAoW's sound files are the game's own (`Sound\Dialogue\...`). They're found only with the owner's install; here they show as not found.
