# 011: Abstract Parallel Worker Library

## Current Behavior

Parallel processing with effil is implemented in `neocities-modernization/scripts/generate-html-parallel`. The pattern includes:
- Thread pool creation with configurable count
- Work distribution across threads
- Thermal management (sleep between batches)
- Progress reporting
- Error collection and reporting

This pattern is duplicated wherever parallel processing is needed.

## Intended Behavior

A reusable library `libs/parallel-worker.lua` that provides:
- `parallel.init(config)` - Configure thread count, thermal sleep, etc.
- `parallel.map(items, worker_fn)` - Apply function to items in parallel
- `parallel.for_each(items, worker_fn)` - Side-effect parallel processing
- `parallel.filter(items, predicate_fn)` - Parallel filter
- Progress callbacks
- Error aggregation

## Suggested Implementation Steps

1. Read `neocities-modernization/scripts/generate-html-parallel` thoroughly
2. Identify core effil patterns and boilerplate
3. Design generic API that doesn't assume HTML generation
4. Create `libs/parallel-worker.lua` with documented interface
5. Add thermal management configuration (sleep duration, batch size)
6. Implement progress callback system
7. Write test script `libs/test-parallel-worker.lua`
8. Refactor `generate-html-parallel` to use the library

## Source Scripts

- `../neocities-modernization/scripts/generate-html-parallel` (primary source)
- `../neocities-modernization/scripts/precompute-diversity-sequences` (similar pattern)

## API Design

```lua
local parallel = require("libs/parallel-worker")

-- Initialize with config
parallel.init({
    threads = 8,
    thermal_sleep = 0.1,  -- Sleep between batches (seconds)
    batch_size = 100,     -- Items per batch before sleep
    on_progress = function(completed, total)
        io.write(string.format("\r[%d/%d]", completed, total))
    end
})

-- Map: transform items in parallel
local results = parallel.map(items, function(item)
    return expensive_transform(item)
end)

-- For each: side effects only
parallel.for_each(files, function(file)
    process_file(file)
end)

-- Filter: parallel predicate evaluation
local filtered = parallel.filter(items, function(item)
    return item.score > threshold
end)
```

## Related Documents

- `README.md` - Scripts documentation
- `libs/` - Library directory
- effil documentation at `/home/ritz/programming/ai-stuff/libs/lua/effil-jit/`
