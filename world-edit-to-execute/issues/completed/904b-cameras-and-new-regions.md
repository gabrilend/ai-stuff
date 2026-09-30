# Issue 904b: Cameras, and New Regions for the Triggers

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** High
**Parent:** 904 (region and camera editor)
**Dependencies:** 904 first pass (the script's rects moved and resized), 905a (trigger editor)

---

## Current Behavior

- **Regions:** the editor moves and resizes the regions the script makes, but can't make new ones for its own triggers.
- **Cameras:** no test map has a `war3map.w3c`. DAoW 5.4b's 7 cameras are made by its script (`CreateCameraSetup` with `CameraSetupSetField` and `CameraSetupSetDestPosition`). The editor doesn't show them.
- **The game:** every camera native is a no-op.
- **The window:** its view always looks north at 56 degrees down.

## Intended Behavior

### Cameras (`editor/cameras.lua`)

- **The script's cameras:** found with their fields (distance, rotation, angle of attack, field of view, height, roll, far clip) and where they look. Changes rewrite the calls when saved; a field the script didn't set is set after the camera is made.
- **The editor's own cameras:** kept with the triggers in `war3mapEditor.lua` and made by `EditorInitCameras`.
- **Undo:** every change is one step. Setting a camera from the view is one step too.

### New regions (`editor/regions.lua`)

- **Making:** dragged out on open ground with the Regions tool.
- **Kept and made:** stored with the triggers and made by `EditorInitRegions`.
- **Editing:** moved and resized like the script's. Delete (the button or the key) removes only the editor's own.

### Trigger actions

- Apply camera, Pan the camera to a region, Reset the game camera.
- The trigger editor's choices include the new cameras.
- Checking reports a trigger naming a camera that doesn't exist.

### The Cameras tool

- **Markers:** each camera shows as a ring where it looks, with a line back toward its eye.
- **Picking and moving:** pick one; drag it to move where it looks.
- **The palette:** "+ Camera from the view", "View through it", "Set it from the view", fields stepped with - / +, Delete for new ones.

### The game (`jass/natives/camera.lua`)

- **Setups:** camera setups are handles holding their fields.
- **Requests:** applying one, panning, setting a field and resetting ask the local player's view to move (`V.camera`, and the world's `on_camera`). Requests for other players are ignored.
- **The window:** `demo/wc3map/main.lua` glides the view there over the time asked.

### The window (`scene_viewer.c`)

- **Camera angles:** the view has a rotation, a pitch and a field of view. `viewer.camera()` returns them and `viewer.set_camera(x, y, distance, rotation, angle of attack, fov)` takes them.
- **Reset:** key 1 (without an interface) resets them.
- **Nearest distance:** 250 (DAoW's cameras come to 400).

## Acceptance Criteria

- [x] The VM: a camera applied, a pan and a reset reach the world. Another player's request is ignored. Setups are read back.
- [x] DAoW 5.4b's 7 cameras read whole; their calls rewritten; set from a view in one step; undone
- [x] A new camera and a new region, used by chat triggers
- [x] Saved and played:
  - [x] the script's camera has its new fields
  - [x] the trigger applies the new camera (place, distance, rotation, time)
  - [x] another trigger pans to the new region's middle and then resets
  - [x] no script errors
- [x] Opened again: the new camera and region read back once
- [x] The tools driven headless:
  - [x] a camera picked, dragged, viewed through, set from the view, stepped;
  - [x] a camera made from the view, then deleted;
  - [x] a region dragged out, then deleted with Delete.
- [x] Seen in the window: DAoW's first camera viewed through (looking west, close in)

## Notes

- **Tests:** `src/tests/test_cameras_regions.lua` (33 tests).
- **Still open (904):**
  - circular regions;
  - region weather and ambient sound (the w3r's; no test map uses them);
  - camera bounds;
  - cinematic camera paths.
