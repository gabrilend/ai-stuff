---
name: HAL — audio
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102f — HAL: audio

ARM-assembly driver for the RG DS's audio output: stereo speakers
and the 3.5mm headphone jack.

## current behavior

Linux's ALSA / SoC audio driver handles audio. On bare metal, raw
I2S writes.

## intended behavior

- Initialize the audio DAC and the I2S / I2C bus to it.
- Configure sample rate (44.1 kHz default), bit depth (16-bit).
- Push PCM data from a ring buffer to the DAC.
- Detect headphone plug insertion if a sense pin is available
  (routes audio appropriately).
- Volume control via the DAC's hardware mixer or a separate
  hardware volume IC.

## API surface

- `audio_init`
- `audio_write(samples, count)` — push samples into the playback
  ring buffer.
- `audio_set_volume(level)`
- `audio_set_output(speakers_or_headphones)`

## suggested implementation steps

1. Identify the audio codec / DAC chip used by the RG DS. Read
   Linux's audio driver. Document.
2. Implement I2C configuration of the codec.
3. Implement the I2S DMA path from RAM ring buffer to codec.
4. Test: play a sine wave through each speaker; play through
   headphones with a plug inserted.

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `issues/507-audio-mixer.md` — the layer above

## notes

- Audio is its own beast. Get the timing right (ring buffer
  refill cadence, DMA completion IRQ) and the rest is bookkeeping.
