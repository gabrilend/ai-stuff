# huffman.lua

Decompresses MPQ sectors compressed with Blizzard's adaptive Huffman code
(method byte `0x01`). Warcraft III uses it mostly on sound, together with
ADPCM, and some protected maps use it on other files. Ported from StormLib's
`huff.cpp` (MIT, Ladislav Zezula and ShadowFlare).

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `decompress(data, expected_length)` | compressed bytes after the method byte (string); the most bytes to produce (integer) | the decompressed bytes (string), or `nil` and an error message |

## Data

| Name | Type | Meaning |
|------|------|---------|
| `WEIGHTS` | table of 9 tables, each indexed 0–255 → integer | the starting weight per byte for each data type (0 sparse, 1 binary, 2 text, 3 general, 4 and 5 ADPCM, 6–8 stereo); exposed so tests and checks can compare them with the reference source |

## How it works

The first byte of the data picks a weight table. A tree is built from it, and
each decoded byte raises its own weight and rebalances the tree, so the code
adapts as it goes. Symbol `0x100` ends the sector; `0x101` means "a byte not
yet in the tree follows as 8 raw bits".
