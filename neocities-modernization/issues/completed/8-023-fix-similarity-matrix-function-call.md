# Issue 8-023: Fix Similarity Matrix Function Call in run.sh

## Current Behavior (BEFORE FIX)

Running `./run.sh -I` and selecting "Generate Similarity Matrix" failed with:

```
luajit: (command line):4: attempt to call field 'generate_similarity_matrix' (a nil value)
stack traceback:
        (command line):4: in main chunk
        [C]: at 0x5589399d0330
Error: Similarity matrix generation failed
```

The code in run.sh line 539 was:
```lua
sim.generate_similarity_matrix('$DIR/assets/poems.json', '$DIR/assets/embeddings/$model_dir_name')
```

Two problems:
1. Function `generate_similarity_matrix` does not exist
2. Parameters were wrong (poems file + directory instead of embeddings file + output file)

## Intended Behavior

The similarity matrix should generate successfully when requested through run.sh.

## Root Cause

The function in `src/similarity-engine.lua` is named `calculate_similarity_matrix`, not `generate_similarity_matrix`. Additionally, the signature is:

```lua
function M.calculate_similarity_matrix(embeddings_file, output_file, top_n, force_regenerate)
```

The call was passing:
- `poems.json` instead of `embeddings.json`
- Directory path instead of output file path

## Fix Applied

Changed run.sh line 534-546 to:
```lua
sim.calculate_similarity_matrix(
    '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
    '$DIR/assets/embeddings/$model_dir_name/similarity_matrix.json',
    nil,
    false
)
```

## Files Modified

| File | Change |
|------|--------|
| `run.sh` | Fixed function name and parameters at lines 534-546 |

---

**Phase**: 8 (Website Completion)

**Priority**: High (blocking similarity matrix generation)

**Created**: 2026-01-04

**Completed**: 2026-01-04

**Status**: Completed

**Type**: Bug Fix
