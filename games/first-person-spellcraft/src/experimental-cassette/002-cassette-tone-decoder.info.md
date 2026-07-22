# 002-cassette-tone-decoder — info

> Black-box summary of the cassette **decoder** (the inverse of 001). Part of the
> experimental cassette branch (issue 905, Phase 9); gates nothing.

## What this module is

The recover-the-bytes half of the round-trip: audio samples in, the original byte
string out. It reads the format from the descriptor (000) and is the exact inverse
of the encoder (001). It recovers each bit by counting zero-crossings in the
bit-window and classifying to the nearest expected count (mark vs space).

## External functions

- `M.decode(desc, samples) -> message`
  The one door. `samples` is the float array from `encoder.encode`. Returns the
  original byte string. Errors LOUDLY (never guesses) on: a sample count that is
  not a whole number of bit-windows, a framing error (no start bit where one is
  due), a truncated frame, or a bad/missing stop bit.

- `M.symbols_to_bytes(desc, symbols) -> message`
  Lower entry point that skips the audio stage: takes an array of 0/1 bit symbols
  and reassembles bytes. Exposed so tests can inject symbol-level corruption (e.g.
  a flipped stop bit) and confirm the decoder refuses it. Same error policy.

## Contract with the encoder

- `decode(desc, encode(desc, message)) == message` for any byte string, provided
  the descriptor passes `validate`. This equality is the property the round-trip
  test (004) asserts across many inputs, including all 256 byte values.

## Notes for a future reader

- Decoding is exact only because the encoder emits whole tone cycles per bit (the
  descriptor invariant). If you ever add noise, jitter, or real tape wow/flutter,
  this simple zero-crossing classifier is the first thing that will need to grow
  (a Goertzel/energy detector). That is a hardware-era concern, flagged in FINDINGS.
