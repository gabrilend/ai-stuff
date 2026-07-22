# Cassette branch — research findings (issue 905)

> **EXPERIMENTAL. This branch gates nothing.** It is the vision's whimsy, quoted
> sacrosanct: *"what if we made it run on a cassette ... hooked up a cassette tape
> player to a gameboy control interface and used the binary 'sounds' it made to
> record the game in the style of a pico-8."* This file is the honest record of
> what has been proven, what has not, and what may not be possible — per the
> project's no-silent-fallback rule (a shrink of scope must be *stated*, not hidden).

## What is proven (software, done)

The round-trip issue 905 asks us to prove *before any hardware* — bytes → tones →
bytes — is built and passing:

- **Scheme:** Kansas-City-Standard-flavoured FSK. Each bit is a tone burst; a `1`
  (mark) = 2400 Hz, a `0` (space) = 1200 Hz; bytes are UART-framed
  (`start,d0..d7,stop`, LSB-first) behind a 32-bit mark leader. Numbers chosen so
  every bit-window holds whole tone cycles (44100/300 = 147 samples/bit; 8 vs 4
  cycles), which makes zero-crossing decoding exact for a clean signal.
- **Modules** (`src/experimental-cassette/`): `000` descriptor, `001` encoder
  (generation), `002` decoder (inverse), `003` viewer/exporter (ASCII strip +
  a real 16-bit-PCM-mono WAV writer), `004` round-trip prover + demo, `005` WAV
  reader (file → samples).
- **The loop is closed through a real file.** With the WAV reader (005) the path
  runs all the way to disk and home: `bytes → tones → .wav file → tones → bytes`,
  proven equal.
- **Tests pass:** round-trips every byte value 0–255; runs the full loop through a
  WAV file on disk; rejects a malformed descriptor; catches a flipped stop bit and
  a truncated stream as loud errors.
- **Artifact:** `run-cassette-experiment.sh` emits a valid, playable
  `cassette-demo.wav` (verified by `file` as RIFF/WAVE PCM) into the RAM tier, and
  reads it back to confirm it decodes to the same bytes.

## A sobering datapoint (scope honesty)

At 300 baud, a **pico-8-sized 32 KB slice ≈ 32768 × 10 bits ÷ 300 ≈ 1092 s ≈ 18
minutes** of tape audio. That is the honest cost of this delivery at KCS speed.
The KCS 1200-baud variant would cut it to ~4.5 minutes. This is exactly why the
payload is a *stated tiny slice*, never the whole Phases 1–8 game — the full game
does not fit an audio cassette read this way.

## The open hardware question — the "gameboy control interface" link

This is the part to be candid about; it may not work as the vision pictures it.

- **The Game Boy has no general-purpose analog audio input.** Its external I/O is
  the link/serial port (digital), the buttons, and audio *out* only. You cannot
  feed cassette tones straight into a Game Boy and have it sample them the way a
  C64 or ZX Spectrum sampled tape through an input line.
- **The link port is digital serial** (SIN/SOUT/SCK: an 8-bit shift register with a
  clock, logic-level). To get tape bytes in, an **external demodulator** must sit
  between the tape head and the link port, turning analog FSK tones into clocked
  digital bits. That demodulator — a small MCU, or a discrete PLL/comparator like
  a genuine 1980s KCS modem — **is** the "gameboy control interface" in the
  vision's phrase. The Game Boy is the *player*, not the decoder.
- **Honest architecture, then:** `cassette (analog tones) → [interface box:
  tones→bits→serial] → Game Boy link port → game loads`. Feasible in principle
  (tape modems are a solved 1980s problem), but *not* a native "tones into a Game
  Boy" path. Whether that matches the vision's mental image is an open question,
  flagged here rather than papered over.

## Not yet / dead-ends noticed

- **No noise model.** The zero-crossing decoder is exact only for clean synthesised
  tones. Real tape brings wow/flutter, dropouts, DC offset — which would need a
  Goertzel/PLL detector and error correction (there is no checksum/parity yet). The
  WAV reader (005) likewise assumes the clean files this branch writes.
- **No chosen slice.** This branch forks off the built Phases 1–8 game, which does
  not exist yet, so the pipe was proven with placeholder text, not a real demake.

## Next questions

1. Raise the baud (or pick a denser modulation) so a slice is minutes, not tens of
   minutes, of tape?
2. Add a checksum/parity layer so a real (noisy) tape read can detect corruption —
   the WAV reader that closes file → bytes → file now exists (005), but it trusts
   the clean bytes it finds.
3. Spec (or breadboard) the external demodulator that is the real "gameboy control
   interface," and decide whether the Game Boy is truly the target or just a muse?
4. Pick the pico-8-sized demake slice once there is a game to slice.
