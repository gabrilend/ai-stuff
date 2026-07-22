# 001-cassette-tone-encoder — info

> Black-box summary of the cassette **encoder** (data generation). Part of the
> experimental cassette branch (issue 905, Phase 9); gates nothing.

## What this module is

The "generate" side of the branch: it turns a byte string (a tiny game slice) into
a stream of audio samples — the tones a cassette would carry. It reads the format
from the descriptor (000) and is pure (same input → same samples). It does not
decode (002) and does not view/export (003).

## External functions

- `M.encode(desc, message) -> samples`
  The one door. `desc` is a validated-or-validatable descriptor from 000;
  `message` is a byte string. Returns an array of float samples in `[-amplitude,
  amplitude]`: a mark leader, then one UART-style frame (`start,d0..d7,stop`,
  LSB-first) per byte, each bit a pure-sine tone burst. Errors if `message` is not
  a string, or if the descriptor is malformed (no fallback).

- `M.frame_bits(desc, message) -> bits`
  The bit stream *without* the audio (a flat array of 0/1), exposed so the viewer
  and tests can inspect framing directly. Same validation and errors as `encode`.

## Guarantees / invariants relied on

- Each bit burst starts at phase 0 and is a whole number of cycles (guaranteed by
  the descriptor's "frequency is a multiple of baud" invariant), so the encoded
  signal has no phase drift and the decoder's zero-crossing counts stay exact.
- Determinism: no randomness, no clock, no I/O. Suitable for reproducible tests.
