# Issue 9-008: Streaming HTML Generation with Progress Reporting

## Priority
Medium

## Current Behavior

HTML generation accumulates page data in memory before writing:

1. Load all data (poems, embeddings, caches)
2. Generate all pages for a batch in memory
3. Write batch to disk
4. Repeat

**Problems**:
- High memory usage during generation
- No real-time progress feedback to user
- If generation fails mid-batch, all work is lost

## Intended Behavior

Stream HTML pages directly to disk as they're generated, with real-time progress reporting:

```
🌐 Stage 9/10: Generating website HTML
   ├── Chronological: 16/16 pages ████████████████ 100%
   ├── Similar:       3847/7797   █████████░░░░░░░  49%  [poem 3847: "morning light..."]
   ├── Different:     0/7797      ░░░░░░░░░░░░░░░░   0%
   └── Word cloud:    0/200       ░░░░░░░░░░░░░░░░   0%
```

### Benefits

1. **Lower memory**: Each page written immediately, not accumulated
2. **Progress visibility**: User sees real-time generation status
3. **Fault tolerance**: Partial progress preserved on failure
4. **Better UX**: Visual feedback during long operations

## Technical Design

### Progress Reporting Architecture

```lua
-- Progress tracker shared across threads
local Progress = {
    chronological = { total = 16, done = 0, current = "" },
    similar = { total = 7797, done = 0, current = "" },
    different = { total = 7797, done = 0, current = "" },
    wordcloud = { total = 200, done = 0, current = "" }
}

-- Worker thread updates progress atomically
local function generate_similar_page(poem_id, poem_data)
    local html = render_similar_page(poem_id, poem_data)
    write_file(output_path, html)  -- Write immediately

    -- Update progress (atomic increment)
    Progress.similar.done = Progress.similar.done + 1
    Progress.similar.current = poem_data.content:sub(1, 30) .. "..."
end

-- Main thread displays progress
local function display_progress()
    while not all_done() do
        clear_line()
        print_progress_bars(Progress)
        sleep(0.1)  -- Update 10 times per second
    end
end
```

### Streaming Write Pattern

```lua
-- OLD: Accumulate then write
local pages = {}
for i = 1, 7797 do
    pages[i] = generate_page(i)  -- Memory grows!
end
write_all_pages(pages)

-- NEW: Generate and write immediately
for i = 1, 7797 do
    local html = generate_page(i)
    write_file(path, html)  -- Memory stays constant
    update_progress(i)
end
```

### Thread-Safe Progress Updates

Using effil for atomic progress counters (lightweight, not for large data):

```lua
local effil = require("effil")

-- Shared progress counters (just integers, very fast)
local progress = effil.table()
progress.similar_done = effil.atomic(0)
progress.different_done = effil.atomic(0)

-- Worker increments atomically
progress.similar_done:add(1)

-- Main thread reads without blocking
local done = progress.similar_done:get()
```

### Progress Display Format

```
═══════════════════════════════════════════════════════════════════
  🌐 Stage 9/10: Generating website HTML
═══════════════════════════════════════════════════════════════════

  Chronological pages:  16/16    ████████████████████  100%  ✓
  Similar pages:        4521/7797 ███████████░░░░░░░░░   58%  "the weight of morning..."
  Different pages:      2103/7797 █████░░░░░░░░░░░░░░░   27%  "scattered light on..."
  Word cloud pages:     0/200    ░░░░░░░░░░░░░░░░░░░░    0%  waiting...

  Elapsed: 12:34  |  Rate: 42 pages/sec  |  ETA: ~8 min
```

### ASCII Progress Bar Function

```lua
local function progress_bar(done, total, width)
    width = width or 20
    local pct = done / total
    local filled = math.floor(pct * width)
    local empty = width - filled

    return string.rep("█", filled) .. string.rep("░", empty)
end

local function format_progress_line(name, done, total, current_item)
    local bar = progress_bar(done, total)
    local pct = math.floor(100 * done / total)
    local status = done == total and "✓" or current_item:sub(1, 25)

    return string.format("  %-20s %5d/%-5d %s %3d%%  %s",
        name, done, total, bar, pct, status)
end
```

## Suggested Implementation Steps

### Phase 1: Progress Tracking Infrastructure

1. **Create progress module** (`libs/progress-tracker.lua`)
   - Atomic counters for each generation type
   - Thread-safe current item tracking
   - Rate calculation (pages/second)
   - ETA estimation

2. **Create display module** (`libs/progress-display.lua`)
   - ASCII progress bars
   - Terminal cursor control (move up, clear line)
   - Configurable update rate

### Phase 2: Streaming Writes

3. **Update flat-html-generator.lua**
   - Remove page accumulation buffers
   - Write each page immediately after generation
   - Call progress update after each write

4. **Update thread coordination**
   - Workers: generate → write → increment counter
   - Main: display progress loop until all workers done

### Phase 3: Error Recovery

5. **Add checkpoint system**
   - Track which poems have been generated
   - On restart, skip already-generated pages
   - Store checkpoint in `output/.generation_progress.json`

6. **Graceful interruption handling**
   - Catch SIGINT (Ctrl+C)
   - Finish current page, save checkpoint, exit cleanly

## Terminal Control Notes

For smooth progress updates without scrolling:

```lua
-- ANSI escape codes
local CURSOR_UP = "\27[A"
local CLEAR_LINE = "\27[2K"
local CURSOR_HOME = "\27[H"

-- Move cursor up N lines and clear
local function rewrite_progress(lines)
    for i = 1, #lines do
        io.write(CURSOR_UP .. CLEAR_LINE .. lines[i] .. "\n")
    end
    io.flush()
end
```

## Configuration

Add to `config.lua`:

```lua
html_generation = {
    streaming = true,           -- Enable streaming writes
    progress_update_hz = 10,    -- Progress display updates per second
    checkpoint_interval = 100,  -- Save checkpoint every N pages
    show_current_poem = true,   -- Show snippet of current poem
}
```

## Related Documents

- `src/flat-html-generator.lua` - Current batch-based generation
- `libs/tui.lua` - Existing TUI utilities (may have useful functions)
- Issue 9-007 - C shared memory (complementary optimization)
- `run.sh` - Pipeline orchestration (progress display integration)

## Metadata

- **Status**: Open
- **Created**: 2026-01-21
- **Phase**: 9 (Performance Optimization)
- **Estimated Complexity**: Medium
- **Benefits**: Better UX, lower memory, fault tolerance
