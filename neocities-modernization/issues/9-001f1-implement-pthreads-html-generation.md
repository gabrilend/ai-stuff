# Issue 9-001f1: Implement pthreads-based HTML Generation

## Parent Issue
9-001f: Remove effil Dependency

## Status
- **Phase**: 9
- **Priority**: High
- **Type**: Enhancement
- **Status**: In Progress
- **Created**: 2026-03-18

## Current Behavior

HTML page generation uses effil library for multi-threading:
- `scripts/generate-html-parallel` spawns effil threads
- Each thread generates HTML for one poem (similarity + diversity pages)
- effil has catastrophic performance with shared table access
- Process gets killed during generation (suspected effil instability)

## Intended Behavior

Replace effil threading with a C library using native pthreads:
- Single process, multiple native threads
- C handles the parallel work distribution
- Lua passes data via FFI, waits for completion
- Pattern mirrors existing `libs/vulkan-compute/` infrastructure

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Lua (main script)                     │
│  - Loads JSON data (poems, similarities, colors)         │
│  - Serializes to C-compatible format                     │
│  - Calls htmlgen_run() via FFI                           │
│  - Receives completion status                            │
└────────────────────────┬────────────────────────────────┘
                         │ FFI
                         ▼
┌─────────────────────────────────────────────────────────┐
│              C Library (libhtmlgen.so)                   │
│                                                          │
│  htmlgen_init() - Initialize thread pool                 │
│  htmlgen_set_poems() - Upload poem data                  │
│  htmlgen_set_similarities() - Upload similarity matrix   │
│  htmlgen_run() - Execute parallel generation             │
│  htmlgen_destroy() - Cleanup                             │
│                                                          │
│  Internals:                                              │
│  - Thread pool with N workers (configurable)             │
│  - Atomic work counter for load balancing                │
│  - Each thread: generate HTML string, write to file      │
│  - Progress callback to Lua (optional)                   │
└─────────────────────────────────────────────────────────┘
```

## File Structure

```
libs/html-threaded/
├── include/
│   └── html_gen.h          # Public API
├── src/
│   └── html_gen.c          # pthreads implementation
├── lua/
│   └── html_gen.lua        # LuaJIT FFI bindings
├── Makefile
└── README.md
```

## Implementation Steps

### Phase 1: Core Infrastructure
- [x] Create directory structure
- [x] Implement html_gen.h with API design
- [x] Implement basic html_gen.c with thread pool
- [x] Create Makefile
- [x] Create Lua FFI bindings

### Phase 2: HTML Generation Logic
- [ ] Port HTML template rendering to C
- [ ] Implement similarity page generation
- [ ] Implement diversity page generation
- [ ] Handle boost formatting in C

### Phase 3: Integration
- [ ] Update generate-html-parallel to use new library
- [ ] Remove effil dependency from HTML generation
- [ ] Performance testing and tuning

### Phase 4: Cleanup
- [ ] Update documentation
- [ ] Remove effil references from HTML generation code
- [ ] Update parent issue 9-001f

## API Design

```c
// Initialize HTML generator with thread count
HtmlGenContext* htmlgen_init(int num_threads);

// Set poem data (content, categories, colors)
int htmlgen_set_poems(HtmlGenContext* ctx,
                      const char** contents,
                      const char** categories,
                      const int* colors,
                      int num_poems);

// Set similarity data (sparse format)
int htmlgen_set_similarities(HtmlGenContext* ctx,
                             const int* poem_ids,
                             const float* scores,
                             const int* offsets,
                             int total_pairs);

// Set diversity sequences (from GPU precomputation)
int htmlgen_set_diversity_cache(HtmlGenContext* ctx,
                                const int* sequences,
                                int sequence_length);

// Run parallel generation
int htmlgen_run(HtmlGenContext* ctx,
                const char* output_dir,
                int generate_similar,
                int generate_different);

// Get progress (0.0 - 1.0)
float htmlgen_get_progress(HtmlGenContext* ctx);

// Cleanup
void htmlgen_destroy(HtmlGenContext* ctx);
```

## Design Decisions

1. **C over GPU**: HTML generation is string/IO-bound, not compute-bound.
   GPU shaders excel at numerical parallelism, not string manipulation.

2. **Thread pool over fork**: Single process with shared memory is more
   efficient than process-based parallelism for this workload.

3. **FFI over Lua C API**: Matches existing vulkan-compute pattern,
   simpler integration, no Lua state management in C.

4. **Atomic work counter**: Threads grab work items atomically, natural
   load balancing without explicit work distribution.

## Dependencies

- pthreads (standard on Linux)
- LuaJIT FFI (already used in project)

## Testing

- [ ] Thread pool correctly distributes work
- [ ] All HTML files generated match effil-based output
- [ ] No race conditions or memory leaks (valgrind)
- [ ] Performance improvement over effil

## Related Documents

- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/libs/vulkan-compute/` - Reference implementation pattern
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/scripts/generate-html-parallel` - Current effil-based script
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/issues/9-001f-remove-effil-dependency.md` - Parent issue
