# libs/png-writer.lua — info

Writes PNG files from raw RGB bytes, with no library: stored (uncompressed)
deflate blocks, CRC-32 per chunk, Adler-32 over the data. Files are about
the raw size. First used by see-in-3d (issue A08).

| | |
|---|---|
| `M.encode(width, height, rgb)` | the PNG file's bytes (string); `rgb` is width×height×3 bytes, rows from the top; errors on a wrong length |
| `M.write(path, width, height, rgb)` | the same, to a file |
| `M.crc32(text)`, `M.adler32(text)` | the two checksums (integers) |

Round-trip tested in `test-see-in-3d.sh` with a decoder written there, and
read by ImageMagick.
