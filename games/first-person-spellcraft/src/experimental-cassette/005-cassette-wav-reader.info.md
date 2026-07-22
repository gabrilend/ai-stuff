# 005-cassette-wav-reader — info

> Black-box summary of the cassette **WAV reader** (file input). Part of the
> experimental cassette branch (issue 905, Phase 9); gates nothing.

## What this module is

The file-input inverse of the viewer's `write_wav` (003): it reads a 16-bit PCM
mono WAV file back into a float sample array, so the round-trip can run all the way
through a real file on disk — `bytes → tones → .wav file → tones → bytes` — not just
the in-memory sample array. Kept separate from the decoder (002): parsing a
container format is a different concern from demodulating tones.

## External functions

- `M.read(desc, path) -> samples`
  Reads the WAV at `path` into an array of float samples in `[-1, 1]`, ready to hand
  to `decoder.decode`. Validates the file is exactly the shape this branch writes —
  RIFF/WAVE, PCM, mono, 16-bit, and the descriptor's sample rate — and errors LOUDLY
  on any mismatch (wrong rate, stereo, 8-bit, missing `fmt `/`data` chunk, unreadable
  file). No quiet coercion: a wrong-rate read would misalign every bit-window.

## Notes for a future reader

- LuaJIT is Lua 5.1 (no `string.unpack`), so little-endian `u16`/`u32` are read by
  hand from `string.byte`. Signed samples use the two's-complement fixup
  (`raw >= 32768 → raw - 65536`).
- WAV chunks are word-aligned: an odd chunk size carries a pad byte, which the chunk
  walk skips (`chunk_size % 2`).
- This reader assumes the clean files this branch produces. A real tape captured to
  WAV (with noise, DC offset, wow/flutter) is a separate, harder problem flagged in
  FINDINGS — it would need the decoder to grow, not this reader.
