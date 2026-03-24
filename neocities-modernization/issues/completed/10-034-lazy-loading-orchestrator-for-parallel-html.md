# 10-034: Lazy Loading Orchestrator for Parallel HTML Generation

## Current Behavior

HTML generation with multiple threads causes memory exhaustion (14+ GB RAM).
Each effil worker thread independently loads the full cache files:

| File | Size | Per Worker |
|------|------|------------|
| `poems.json` | 12MB | Required (poem content) |
| `diversity_cache.json` | 318MB | Uses ~40KB per poem |
| `similarity_rankings_cache.json` | 384MB | Uses ~40KB per poem |
| `poem_colors.json` | 892KB | Small, acceptable |
| **Total per worker** | **~715MB** | |

With 4 workers: 2.8GB raw × 3-4× JSON overhead = **10-14GB RAM**

## Intended Behavior

Parallel HTML generation should use < 3GB RAM total, regardless of thread count.

## Key Insight: Data Structure

Each cache entry is just a list of ~8,275 integers:

```json
// similarity_rankings_cache.json
{
  "rankings": {
    "1": [2767, 3650, 7881, 39, ...],   // ~40KB: "poem 2767 is most similar to poem 1"
    "2": [1234, 5678, 9012, ...],
    ...
  }
}

// diversity_cache.json
{
  "sequences": {
    "1": [5979, 7247, 1646, ...],       // ~40KB: "poem 5979 is most different from poem 1"
    "2": [4321, 8765, ...],
    ...
  }
}
```

**Similarity ranking**: Poems sorted by cosine similarity (most similar first)
**Diversity sequence**: Greedy selection maximizing difference at each step

Workers load 700MB to access 80KB slices!

## Proposed Architecture: Orchestrator Pattern

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN THREAD (ORCHESTRATOR)                        │
│                                                                      │
│  ┌──────────────────┐   ┌──────────────────┐   ┌────────────────┐   │
│  │ diversity_cache  │   │ similarity_cache │   │   Work Queue   │   │
│  │     318MB        │   │      384MB       │   │ [pending poems]│   │
│  └────────┬─────────┘   └────────┬─────────┘   └───────┬────────┘   │
│           │                      │                     │            │
│           └──────────────────────┴─────────────────────┘            │
│                                  │                                   │
│                    ┌─────────────┴─────────────┐                    │
│                    │    Request Handler Loop   │                    │
│                    │  - Receive work requests  │                    │
│                    │  - Extract 80KB slices    │                    │
│                    │  - Send to workers        │                    │
│                    │  - Track completion       │                    │
│                    └─────────────┬─────────────┘                    │
└──────────────────────────────────┼──────────────────────────────────┘
                                   │ effil channels
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│    WORKER 1       │  │    WORKER 2       │  │    WORKER 3       │
│ ┌───────────────┐ │  │ ┌───────────────┐ │  │ ┌───────────────┐ │
│ │ poems.json    │ │  │ │ poems.json    │ │  │ │ poems.json    │ │
│ │ poem_colors   │ │  │ │ poem_colors   │ │  │ │ poem_colors   │ │
│ │   ~13MB       │ │  │ │   ~13MB       │ │  │ │   ~13MB       │ │
│ ├───────────────┤ │  │ ├───────────────┤ │  │ ├───────────────┤ │
│ │ Current Work  │ │  │ │ Current Work  │ │  │ │ Current Work  │ │
│ │ - ranking 40K │ │  │ │ - ranking 40K │ │  │ │ - ranking 40K │ │
│ │ - sequence 40K│ │  │ │ - sequence 40K│ │  │ │ - sequence 40K│ │
│ └───────────────┘ │  │ └───────────────┘ │  │ └───────────────┘ │
│  Generates HTML   │  │  Generates HTML   │  │  Generates HTML   │
│  Writes to disk   │  │  Writes to disk   │  │  Writes to disk   │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

## Memory Comparison

| Component | Current | With Orchestrator |
|-----------|---------|-------------------|
| Main thread | 12MB | 712MB (caches active) |
| Per worker | 715MB | 13MB |
| 4 workers | 2.8GB | 52MB |
| **Total raw** | **2.9GB** | **~765MB** |
| **With JSON overhead** | **~12GB** | **~2.5GB** |

## Suggested Implementation Steps

### Step 1: Create Orchestrator Request/Response Protocol

```lua
-- Message types
REQUEST_WORK = "get_work"      -- Worker → Main: "give me a poem to process"
WORK_SLICE = "work"            -- Main → Worker: poem data + rankings
WORK_DONE = "done"             -- Worker → Main: "finished poem X"
SHUTDOWN = "shutdown"          -- Main → Worker: "no more work, exit"
```

### Step 2: Modify Main Thread Loop

```lua
-- Main thread orchestrator loop
local function run_orchestrator(num_workers, work_queue, caches)
    local pending = {}  -- poem_index → true
    local in_progress = {}  -- poem_index → worker_id
    local completed = {}  -- poem_index → true

    -- Initialize pending queue
    for _, poem_index in ipairs(work_queue) do
        pending[poem_index] = true
    end

    -- Process requests until all work complete
    while next(pending) or next(in_progress) do
        local msg = request_channel:pop(100)  -- 100ms timeout

        if msg and msg.type == REQUEST_WORK then
            local poem_index = next(pending)
            if poem_index then
                pending[poem_index] = nil
                in_progress[poem_index] = msg.worker_id

                -- Send work slice (~80KB, not 700MB!)
                response_channels[msg.worker_id]:push({
                    type = WORK_SLICE,
                    poem_index = poem_index,
                    similarity_ranking = caches.similarity.rankings[tostring(poem_index)],
                    diversity_sequence = caches.diversity.sequences[tostring(poem_index)]
                })
            else
                -- No more work
                response_channels[msg.worker_id]:push({type = SHUTDOWN})
            end

        elseif msg and msg.type == WORK_DONE then
            in_progress[msg.poem_index] = nil
            completed[msg.poem_index] = true
            -- Update progress display
        end
    end
end
```

### Step 3: Modify Worker Thread

```lua
-- Worker thread main loop
local function worker_main(worker_id, config)
    -- Load per-worker data (once)
    local poems_data = load_poems_json()
    local poem_colors = load_poem_colors()
    local poem_lookup = build_poem_lookup(poems_data)

    while true do
        -- Request work
        request_channel:push({type = REQUEST_WORK, worker_id = worker_id})

        -- Wait for response
        local work = response_channels[worker_id]:pop()

        if work.type == SHUTDOWN then
            break
        end

        -- Generate HTML pages using the slice data
        generate_similarity_pages(
            poem_lookup[work.poem_index],
            work.similarity_ranking,
            poem_lookup,
            poem_colors,
            config
        )

        generate_diversity_pages(
            poem_lookup[work.poem_index],
            work.diversity_sequence,
            poem_lookup,
            poem_colors,
            config
        )

        -- Report completion
        request_channel:push({type = WORK_DONE, worker_id = worker_id, poem_index = work.poem_index})
    end
end
```

### Step 4: Update Progress Reporting

Main thread tracks and displays:
- Total poems: 8,275
- Pending: N
- In progress: [worker_id: poem_index, ...]
- Completed: M (M/8275 = X%)

## Why poems.json Stays Per-Worker

Each ranking contains ~8,275 poem indices. To render HTML, the worker must look up
each poem's content. Streaming 8,275 poem lookups through the orchestrator would
create massive channel overhead.

**Decision:** Workers keep poems.json (12MB each) - acceptable trade-off.

## Testing Plan

1. Verify memory usage with `htop` during generation
2. Compare generation time: single-thread vs orchestrator with 4 threads
3. Validate output HTML matches previous generation
4. Test with --force to ensure clean regeneration works

## Related Documents

- `src/flat-html-generator.lua:3155-3400` - Current parallel processing code
- Issue 10-033 - Fixed memory exhaustion (temporary single-thread default)
- Issue 9-002 - Original parallel HTML generation implementation

## Implementation Notes

### Changes Made (2026-03-23)

1. **Message types added** (`src/flat-html-generator.lua:52-57`):
   - `MSG_REQUEST_WORK`, `MSG_WORK_SLICE`, `MSG_WORK_DONE`, `MSG_SHUTDOWN`

2. **Channel setup** (`src/flat-html-generator.lua:3167-3180`):
   - `work_request_channel` (workers → main)
   - `work_response_channels[t]` (main → each worker)
   - `work_queue` built from poem_indices

3. **Worker thread modified** (`src/flat-html-generator.lua:3231-3118`):
   - Receives `request_channel` and `response_channel` instead of batch
   - No longer loads `diversity_cache.json` or `similarity_rankings_cache.json`
   - Uses `convert_similarity_ranking()` and `convert_diversity_sequence()` on data from orchestrator

4. **Orchestrator loop** (`src/flat-html-generator.lua:4125-4231`):
   - Serves work slices on-demand (~80KB each)
   - Tracks `work_queue_idx`, `completed_count`, `workers_active`
   - Progress display with ETA

5. **run.sh default threads** (line 1329):
   - Changed from `1:2` to `4:8` (default 4, max 8)

### Test Results

```
[15 threads] Complete: 8275 poems in 102s (81.1 poems/sec)
```

Memory usage stayed under 3GB (vs 14GB+ before fix).

## Status

**COMPLETED** - 2026-03-23
