# 149-the-png-writer.lua

The `.png` end's writer (docs/067, issue 804 step 1): pixels to a PNG
file with no compression library — stored deflate blocks, CRC-32 and
Adler-32 by hand — modelled on delta-version's readme-gallery `png.lua`.
Byte-reproducible: the same pixels always give the same bytes.

| Function | In | Out |
|---|---|---|
| `encode(width, height, pixels, channels)` | whole numbers from 1; a string of `width*height*channels` bytes, rows top first; 4 (RGBA, default) or 3 (RGB) | the PNG file's bytes: signature, IHDR (8-bit, no interlace), one IDAT of stored blocks with every row's filter 0, IEND. Refuses a size the pixels do not fill, naming both |
| `write(path, width, height, pixels, channels)` | a path; as `encode` | writes the file through a neighbour name and a rename; returns its length |
| `zlib_stored(raw)` | bytes | a zlib stream of stored blocks of at most 65535 bytes, with its Adler-32 |
| `crc32(s)`, `adler32(s)` | a string | the checksum as a number |
| `COLOUR_TYPES`, `STORED_MAX`, `SIGNATURE` | | channels → PNG colour type; 65535; the eight signature bytes |
