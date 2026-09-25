# adpcm.lua

Decompresses MPQ sectors of WAVE sound compressed with Blizzard's lossy
IMA-ADPCM variant (method bytes `0x40` mono, `0x80` stereo). Ported from
StormLib's `adpcm.cpp` (MIT, Ladislav Zezula, after Tom Amigo's sources).

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `decompress(data, expected_length, channel_count)` | compressed bytes (string; after the method byte and after any Huffman layer); the most bytes to produce (integer); 1 or 2 | 16-bit little-endian samples (string), or `nil` and an error message |

## Data

| Name | Type | Meaning |
|------|------|---------|
| `STEP_SIZE` | table indexed 0–88 → integer | step sizes |
| `NEXT_STEP` | table indexed 0–31 → integer | step-index change per code |

## How it works

Two header bytes (zero, then the bit shift), one starting sample per channel,
then one code byte per sample, alternating channels in stereo. Code `0x80`
repeats the last sample and shrinks the step; `0x81` grows the step by 8 and
produces no sample.
