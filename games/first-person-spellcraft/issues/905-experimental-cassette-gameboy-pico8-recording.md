# 905 — EXPERIMENTAL: cassette → gameboy-control-interface → pico-8-style recording

> **Phase:** 9 — Platform & Packaging
> **⚠ EXPERIMENTAL — exploratory / research spike. Sacrosanct whimsy.**
> This issue is a documented **exploration**, not a shipping deliverable. Nothing
> — least of all the Anbernic release (903, 904) — may be gated on it. It exists
> so a treasured piece of the vision is never lost.
> **Blocked by (within phase):** 903 (something built to encode). It forks off the
> same built game/data as the main pipeline, then goes its own strange way.

## Current Behavior

**In progress — the software round-trip is built and proven; the hardware link
remains a research question.** Under `src/experimental-cassette/` there is now a
Kansas-City-Standard-flavoured FSK pipeline: an **encoding descriptor** (`000`,
data-at-rest scheme + validator), a **tone encoder** (`001`, bytes → audio
samples), a **tone decoder** (`002`, samples → bytes, the exact inverse), a
**viewer/exporter** (`003`, an ASCII symbol strip plus a real 16-bit-PCM-mono WAV
writer), a **WAV reader** (`005`, a WAV file on disk back into samples), and a
**round-trip prover + demo** (`004`) driven by `run-cassette-experiment.sh` (the
`${DIR}` convention, runs from any directory, reads `input/` first, writes
artifacts to the RAM tier). Tests pass for **every byte value 0–255**, the full
loop runs through a real WAV file on disk (`bytes → tones → .wav → tones → bytes`),
and malformed descriptors, flipped stop bits, and truncated streams are caught as
loud errors (no silent fallback). Running the launcher emits a listenable
`cassette-demo.wav` (verified as valid RIFF/WAVE PCM), reads it back to confirm it
decodes to the same bytes, and writes a report.

Still only a wish (deferred, so this issue stays open): the **cassette →
gameboy-control-interface → load** hardware link — the Game Boy has no analog audio
input, so an external demodulator is required and *that box*, not the Game Boy,
reads the tones (see `src/experimental-cassette/FINDINGS.md`); any **noise / jitter
/ error-correction** model (the zero-crossing decoder is exact only for clean
synthesised tones, and there is no checksum yet — the WAV reader `005` likewise
trusts the clean files this branch writes); and the actual **pico-8-sized game
slice** to encode (this branch
forks off Phases 1–8, which do not exist yet, so the pipe was proven with
placeholder text). At 300 baud a 32 KB slice is ~18 minutes of tape — the honest
cost that keeps the payload a tiny slice, not the whole game.

## Intended Behavior

The vision's whimsy is honored, quoted verbatim and treated as sacrosanct:

> oh! what if we made it run on a cassette and we hooked up a cassette tape player
> to a gameboy control interface and used the binary "sounds" it made to record
> the game in the style of a pico-8

This issue documents that path as an **experimental branch**, its datapath its own
fork off the built game/data:

```
  built game / data  ──►  AUDIO ENCODER  ──►  cassette tape (binary "sounds")
   (a pico-8-sized         (bytes → tones,      a physical recorded object
    slice — see below)     pico-8 style)

  cassette player ──► gameboy control interface ──► AUDIO DECODER ──► game loads
   (tones out)         (reads tones as its           (tones → bytes)   pico-8 style
                        control/data input)
```

Two honesties this branch keeps loud, per the no-silent-fallback rule:

- **It targets a pico-8-sized slice, not the whole game.** The full Phases 1–8
  game almost certainly does not fit the data budget of an audio cassette read this
  way. So the branch encodes a **tiny playable demake** — a pico-8-style slice — and
  says so plainly. This is a stated scope, not a quiet shrink of the real game.
- **The gameboy-control-interface link is an open hardware question.** Whether tones
  off a tape head can be fed through a gameboy control interface and decoded back to
  bytes is exactly the thing to find out. This issue is a **research spike** with an
  explicit "here is what we do not yet know" list, not a promise it works.

The deliverable of this issue is **knowledge and artifacts of exploration**: an
encode/decode scheme sketch, a description of the interface link, and a clear
record of feasibility findings — including a candid "this may not be possible,
and here is why" if that is where it lands. Any poetry the vision or the user adds
about this path is preserved here as part of the record.

## Suggested Implementation Steps

1. Mark the issue **EXPERIMENTAL** at the top and state, up front, that no shipping
   work depends on it.
2. Define the **cassette encoding descriptor** (which slice of the game, the
   bytes→tones scheme, the framing) as an exploratory sketch.
3. Prototype an **audio encoder** (bytes → pico-8-style tones) and matching
   **decoder** (tones → bytes) on the computer first — prove the round-trip in
   software before any tape or hardware is involved.
4. Research the **gameboy control interface** link: how tones from a cassette player
   could be presented to it and recovered; write down what is known and, loudly,
   what is not.
5. Pick a **pico-8-sized slice** of the game to be the demake payload; state the
   size budget that forced the slice.
6. Record findings as a research artifact — feasibility, dead-ends, next questions —
   and preserve any related poetry verbatim.

## Stats / Meta

- **Kind:** EXPERIMENTAL research spike / preserved whimsy.
- **Gates any release?** No. Explicitly not.
- **Scope honesty:** pico-8-sized slice, not the whole game (stated, not silent).
- **Open question:** the gameboy-control-interface link's feasibility.

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — the
  "Experimental branch — cassette → gameboy → pico-8" section.
- [notes/vision](../notes/vision) — the source of this whimsy (lines ~126–128);
  sacrosanct.
- Issue **903** — the built game/data this branch forks off from.
- `src/experimental-cassette/` — the built software round-trip (descriptor 000,
  encoder 001, decoder 002, viewer/exporter 003, prover+demo 004, WAV reader 005,
  the run script) and each module's `.info.md`.
- `src/experimental-cassette/FINDINGS.md` — the candid feasibility record: what is
  proven, the Game-Boy-has-no-audio-input problem, and the open next questions.
