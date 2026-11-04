# libs/see-in-3d-animate.lua — info

The pieces of a moving picture made from still ones (issue A12). Used by
`see-in-3d animate`.

| | |
|---|---|
| `M.workflow_between(settings)` | one in-between frame as a ComfyUI graph: both ends encoded, mixed by `LatentBlend` (`blend` 1 = all FROM, 0 = all TO), lightly repainted (`denoise`) under the mechanism's `prompt`, one `seed` for all frames |
| `M.blends(segments, frames_per_segment)` | the frames in order: `{ segment integer, blend number }`; a shared middle drawn once |
| `M.median_cut(frames, count)` | up to `count` palette colours `{ r, g, b }` chosen from the frames' own pixels (strings of RGB bytes), splitting the widest colour box at its median |
| `M.palette_bytes(palette)` | the 768-byte colour table (ffi) the GIF encoder embeds |
| `M.indexer(palette)` | a function `(rgb string, pixel count) -> ffi uint8 array` of palette indexes; nearest colour looked up once per 15-bit colour |

The GIF bytes themselves are written by gif-generator's
`src/004-gif.lua` (`compress_frame`, `assemble`), used as it is.
