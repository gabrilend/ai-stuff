# Issue 10-018: Animated Command Option Transitions

**Priority**: Low
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2026-01-30
**Related To**: 10-008 (Multiline Command Wrapping), 10-004 (Command Preview System)

---

## Summary

Add smooth visual animations to the command preview when options are added or removed, making the TUI feel more polished and helping users track changes.

---

## Current Behavior

When an option is toggled in the TUI:
- The command preview updates **instantly**
- Options appear/disappear with no transition
- Hard to visually track what changed in a long command

```
Before toggle:
./run.sh --extract --embed --generate

After toggle (instant):
./run.sh --extract --embed --catalog --generate
                           ^^^^^^^^^ appeared instantly
```

---

## Intended Behavior

### Option Addition Animation

When an option is added:

1. **Insert with highlight color** (e.g., cyan/bright)
2. **Pause** for 300-500ms
3. **Fade to normal color** (white/default)

```
Frame 1 (t=0ms):    ./run.sh --extract --embed [--catalog] --generate
                                               ^^^^^^^^^^^^ cyan/bright

Frame 2 (t=500ms):  ./run.sh --extract --embed --catalog --generate
                                               ^^^^^^^^^ normal color
```

### Option Removal Animation

When an option is removed:

1. **Change to dim/removal color** (e.g., red or dark gray)
2. **Pause** for 300-500ms
3. **Remove the text**, leaving empty space
4. **Slide remaining options left** one character at a time with ~100ms between frames

```
Frame 1 (t=0ms):    ./run.sh --extract --embed [--catalog] --generate
                                               ^^^^^^^^^^^^ red/dim

Frame 2 (t=400ms):  ./run.sh --extract --embed            --generate
                                               ^^^^^^^^^^^ empty space

Frame 3 (t=500ms):  ./run.sh --extract --embed           --generate
Frame 4 (t=600ms):  ./run.sh --extract --embed          --generate
Frame 5 (t=700ms):  ./run.sh --extract --embed         --generate
...
Frame N:            ./run.sh --extract --embed --generate
                                               ^^^^^^^^^ slid into place
```

---

## Technical Considerations

### Timer-Based Animation

The TUI library needs to support scheduled updates:

```lua
-- Animation state for command preview
local animation = {
    active = false,
    phase = nil,  -- "insert_highlight", "insert_fade", "remove_highlight", "remove_empty", "remove_slide"
    start_time = 0,
    target_text = "",
    removed_range = nil,  -- {start, end} character positions
    slide_progress = 0
}

-- In the main loop, check if animation is active
function update_animation()
    if not animation.active then return end

    local elapsed = os.clock() * 1000 - animation.start_time

    if animation.phase == "insert_highlight" and elapsed > 400 then
        animation.phase = "insert_fade"
        -- Render with normal color
    elseif animation.phase == "remove_highlight" and elapsed > 400 then
        animation.phase = "remove_empty"
        -- Render with empty space
    elseif animation.phase == "remove_empty" then
        -- Slide characters left every 100ms
        local slide_frames = math.floor(elapsed / 100)
        if slide_frames > animation.slide_progress then
            animation.slide_progress = slide_frames
            -- Shift display one character left
        end
        if animation.slide_progress >= removed_char_count then
            animation.active = false
            -- Set final text
        end
    end
end
```

### Non-Blocking Input

Animation must not block keyboard input:
- Use non-blocking `getch()` or poll-based input
- Animation continues in background while user can still navigate
- If user toggles another option mid-animation, queue it or interrupt gracefully

### Performance

- Only animate the command preview area, not full screen redraws
- Use ANSI cursor positioning to update just the preview line(s)
- Consider skipping animation if terminal doesn't support colors

---

## Configurable Timing

```lua
-- Animation timing configuration (milliseconds)
state.animation_config = {
    enabled = true,
    insert_highlight_duration = 400,   -- How long to show highlight color
    remove_highlight_duration = 400,   -- How long to show removal color
    slide_interval = 100,              -- Time between slide frames
}
```

### Disable Option

Some users prefer instant updates. Provide a way to disable:

```lua
-- In menu config
menu_set_animation(false)  -- Disable all animations
```

---

## Color Scheme

| Animation Phase | Color | ANSI Code |
|-----------------|-------|-----------|
| Insert highlight | Cyan/Bright | `\027[96m` (bright cyan) |
| Insert normal | White/Default | `\027[0m` |
| Remove highlight | Red/Dim | `\027[91m` (bright red) |
| Remove empty | (no text) | — |
| Slide in progress | White/Default | `\027[0m` |

---

## Implementation Steps

### Phase 1: Timer Infrastructure
1. [ ] Add non-blocking input to TUI main loop
2. [ ] Implement `schedule_update(delay_ms, callback)` function
3. [ ] Add animation state tracking

### Phase 2: Insert Animation
4. [ ] Detect when option is added
5. [ ] Render with highlight color
6. [ ] Schedule fade to normal after delay

### Phase 3: Removal Animation
7. [ ] Detect when option is removed
8. [ ] Render with removal color
9. [ ] Replace with spaces after delay
10. [ ] Implement character-by-character slide

### Phase 4: Polish
11. [ ] Handle rapid toggles (queue or interrupt)
12. [ ] Add animation disable config option
13. [ ] Test with various terminal widths
14. [ ] Test with multiline wrapped commands (10-008)

---

## Animation Queue System

**Critical Requirement**: Animations must be queued, not interrupted.

When multiple options are toggled rapidly:
1. Each toggle adds a task to the animation queue
2. Tasks are processed **one at a time**, in order
3. No animation is skipped or forgotten
4. Current animation completes before next begins

### Queue Data Structure

```lua
local animation_queue = {
    tasks = {},  -- Array of pending animation tasks
    current = nil,  -- Currently executing animation
}

function queue_animation(task)
    table.insert(animation_queue.tasks, task)
    if not animation_queue.current then
        start_next_animation()
    end
end

function start_next_animation()
    if #animation_queue.tasks == 0 then
        animation_queue.current = nil
        return
    end
    animation_queue.current = table.remove(animation_queue.tasks, 1)
    -- Begin animation...
end

function on_animation_complete()
    start_next_animation()  -- Process next in queue
end
```

### Task Types

```lua
-- Add operation
{
    type = "add",
    text = "--catalog",
    position = 28,  -- Character position in command string
    line = 1        -- Line number (for multiline commands)
}

-- Remove operation
{
    type = "remove",
    text = "--catalog",
    position = 28,
    line = 1,
    slide_targets = {  -- Options that need to slide left after removal
        {text = "--generate", original_pos = 39, final_pos = 28}
    }
}
```

### Line-Aware Sliding

When an option is removed and others slide left:
- Track which line each option is on
- If an option slides past a line break, it may wrap to the previous line
- Recalculate line breaks after each slide frame
- The slide animation respects the multiline layout (see 10-008)

### Example: Rapid Toggles

User rapidly unchecks `--extract`, then `--embed`, then `--catalog`:

```
Queue state:
  [0] remove --extract (currently animating)
  [1] remove --embed (waiting)
  [2] remove --catalog (waiting)

Timeline:
  t=0ms:   Start removing --extract (highlight red)
  t=400ms: --extract becomes empty space
  t=500ms: Slide --embed left
  t=600ms: Slide --embed left
  ...
  t=Nms:   --extract removal complete
           Start removing --embed (highlight red)
  ...
```

Each removal completes fully before the next begins. The command preview always shows a valid intermediate state.

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Rapid toggling | **Queue all animations**, process in order |
| Option toggled mid-animation | Add to queue, don't interrupt current |
| Re-add option being removed | Add "add" task to queue after current "remove" completes |
| Terminal resize during animation | Pause animation, recalculate layout, resume |
| Animation disabled | Process queue instantly (no delays) |
| Very long slide distance | Cap at ~10 frames, then jump to final |
| Queue becomes very long (>10) | Consider "fast-forward" mode: reduce delays by 50% |

---

## Files to Update

| File | Changes |
|------|---------|
| `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` | Animation state, timing, render logic |
| `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua` | Non-blocking input, scheduled updates |

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issues/10-004-implement-built-up-command-preview-system.md` - Base preview system
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/issues/10-008-implement-multiline-command-wrapping.md` - Multiline support
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` - TUI library source

---

## Notes

- This is a "polish" feature - the preview system works fine without it
- Animation timing should be subtle enough not to feel sluggish
- Consider users with motion sensitivity - provide disable option
- The slide animation is the most complex part; could be simplified to instant collapse if too difficult
- May need to refactor the rendering loop to support incremental updates

### Simplification Option

If full animation is too complex, a simpler version:
- Insert: Flash bright for 200ms, then normal
- Remove: Flash red for 200ms, then remove instantly

This gives visual feedback without the complex slide animation.
