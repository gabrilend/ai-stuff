# vk_cross.lua

The cosine of every vector in one set against every vector in another, on the
GPU in one dispatch. Used by the word pages to score every word-cloud word
against every poem at once (Issue 10-035). Built from the library's general
functions (buffers, upload, pipeline, dispatch, download) and the shader
`shaders/similarity_cross.comp`; no C of its own.

## Functions

| function | takes | returns |
| --- | --- | --- |
| `cosine_table(dir, a, b)` | the project folder; two lists of vectors (Lua arrays of numbers, one length throughout) | a function `score(i, j)` giving the cosine of `a[i]` and `b[j]` (1-based), single precision; 0 for a vector with no length |

Errors on any GPU failure (no device, a buffer, the shader missing: build it
with `make -C libs/vulkan-compute`). There is no CPU path: the word pages
score their GPU shortlist exactly on the CPU instead
(`generate-word-pages.lua`, `shortlist`), so a page never depends on the
GPU's rounding.

## Shader

`similarity_cross.comp`: one thread per (a, b) pair in 16 × 16 workgroups,
x over set B, y over set A; output row `a` holds a's scores against every b.

## Test

`libs/vk-cross.test.lua` (needs the GPU): every score within
single-precision rounding of `embedding-space.cosine_centred`.
