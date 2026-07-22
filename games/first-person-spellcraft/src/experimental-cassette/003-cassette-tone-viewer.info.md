# 003-cassette-tone-viewer — info

> Black-box summary of the cassette **viewer / exporter** (data viewing). Part of
> the experimental cassette branch (issue 905, Phase 9); gates nothing.

## What this module is

The "view" side of the branch: it shows a human what the encoder (001) produced —
as a readable symbol strip, a text summary, or a real `.wav` file you can play. It
READS samples; by design it never turns them back into bytes (that wall belongs to
the decoder, 002), so a display change can never corrupt the data or its meaning.

## External functions

- `M.render_symbols(desc, samples) -> string`
  One glyph per bit-window: `.` for a space bit, `#` for a mark bit. A picture of
  the tones, not a decode — it reports per-window tone and never reassembles bytes
  or checks framing. Errors if the sample count is not a whole number of windows.

- `M.summarise(desc, message, samples) -> string`
  A one-block report (message bytes, scheme, sample rate, samples produced, tape
  length in seconds, the honest pico-8 slice budget). All figures computed live.

- `M.write_wav(desc, samples, path) -> path`
  Writes a canonical 16-bit PCM mono WAV — the listenable "cassette." Returns the
  path. Errors with the exact reason if the file cannot be opened (no fallback to a
  temp path, no swallowed failure).

## Notes for a future reader

- LuaJIT is Lua 5.1: there is no `string.pack`, so little-endian bytes are emitted
  by hand (`le16`/`le32`). Comment at those helpers explains why.
- `render_symbols` intentionally duplicates the decoder's nearest-count idea *for
  drawing only*. If you need actual bytes, call the decoder — do not grow this into
  a second decoder behind the viewing wall.
