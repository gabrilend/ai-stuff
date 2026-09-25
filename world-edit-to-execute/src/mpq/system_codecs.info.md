# system_codecs.lua

zlib (method byte `0x02`) and bzip2 (`0x10`) decompression through the
system's `libz.so.1` and `libbz2.so.1`, via LuaJIT's FFI. Replaces an earlier
route that ran Python on temporary files.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `zlib(data, expected_length)` | zlib stream with its 2-byte header (string); output cap (integer) | the bytes (string), or `nil` and a message naming the zlib error (a bad checksum is an error) |
| `bzip2(data, expected_length)` | bzip2 stream (string); output cap (integer) | the bytes (string), or `nil` and a message |

Needs LuaJIT; a missing FFI or library raises an error naming what's missing.
