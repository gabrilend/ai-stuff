# Datapath — listening (sound to beat sheet)

## In

Any sound file ffmpeg can decode, in `input/`.

## Through

1. **Decode.** ffmpeg converts the sound to mono, 22050 samples per second,
   signed 16-bit raw samples, written to `tmp/shared-memory/<run>/sound.raw`.
2. **Allocate.** The listener reads the file length, allocates one array of
   window loudness values up front (one per 1/50 s window), then fills it.
   The file is split into equal slices, one per thread; each thread measures
   its own windows into its own part of the array (CLAUDE.md: assign memory
   first, then let threads take parts of the list).
3. **Envelope.** Each window's loudness is the square root of the mean of
   its squared samples (RMS). The whole envelope is divided by its largest
   value so it runs 0–1.
4. **Onsets.** A window is an onset when its loudness exceeds the average of
   the preceding ~0.5 s by a set ratio and is a local peak. Strength is how
   far it exceeded.
5. **Sections.** The envelope is smoothed over several seconds; a section
   boundary is placed where the smoothed energy crosses between energy
   bands and stays there for a minimum length. Each section gets its mean
   energy and a word label.
6. **Tempo.** The gaps between strong onsets are histogrammed; a clear peak
   gives beats per minute. No clear peak gives `false`.

## Out

`beat-sheet.lua` in the run folder (format: beat-sheet-format.md) and a
receipt line: seconds of sound, onsets found, sections found, tempo.

## The viewer, separately

`beat-view` draws the envelope with onset ticks and coloured section bands as
a PNG, so a person can see whether the ear heard what they heard. It only
reads the beat sheet.
