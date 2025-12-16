# MPQ Debug Scripts

Debug scripts for tracking down the file extraction issue in Issue 102d.

## Scripts (in tmp/)

1. `debug-offset.lua` - Tests the offset reading with fixed 1-based indexing
2. `debug-decompress.lua` - Tests decompression of decrypted sector data
3. `debug-sector-data.lua` - Writes decrypted sector data to file
4. `debug-verify-decrypt.lua` - Verifies decryption by comparing raw vs decrypted

Run with: `lua5.3 tmp/debug-offset.lua`

## Issues Found and Fixed

### Issue 1: Off-by-one in offset handling
- `absolute_offset` is already a 1-based Lua position
- Fixed: Use `offset` directly instead of `offset + 1`

### Issue 2: Decryption padding
- MPQ decryption operates on 4-byte blocks
- Sectors may not be 4-byte aligned
- Fixed: Pad with zeros, decrypt, truncate back

### Issue 3: zlib checksum corruption
- MPQ uses zlib compression but the Adler-32 checksum may be corrupted
- Root cause: Partial block decryption affects trailing checksum bytes
- Fixed: Use raw deflate mode (skip zlib header, ignore checksum)

## Test Results

- 15/16 test maps extract successfully
- 1 map (Daow6.2.w3x) uses PKWARE DCL compression (not implemented)

## Note

The tmp/ directory should be compressed at each major release version.
