# Issue 109: Implement PKWARE DCL Decompression

**Phase:** 1 - Foundation (Extension)
**Type:** Feature
**Priority:** Medium
**Dependencies:** 102d-implement-file-extraction

---

## Current Behavior

MPQ file extraction fails for files compressed with PKWARE DCL (implode) algorithm.
Currently returns error: "PKWARE DCL decompression not implemented"

Affected test map: `Daow6.2.w3x` (older map using legacy compression)

---

## Intended Behavior

A pure Lua implementation of PKWARE DCL decompression that:
- Decompresses data compressed with PKWARE implode algorithm
- Supports both Binary and ASCII compression modes
- Supports variable dictionary sizes (4-6 bits)
- Integrates with existing `src/mpq/extract.lua` module
- Enables 16/16 test maps to parse successfully

---

## Suggested Implementation Steps

1. **Create pkware module**
   ```
   src/mpq/
   └── pkware.lua      (this issue)
   ```

2. **Implement lookup tables**
   - ChBitsAsc, ChCodeAsc (256 entries each) - ASCII character encoding
   - LenBits, LenCode, ExLenBits, LenBase (16 entries each) - Length encoding
   - DistBits, DistCode (64 entries each) - Distance encoding

3. **Implement bit reader**
   ```lua
   -- Bit buffer management
   -- Reads N bits from input stream
   -- Handles byte boundary crossing
   ```

4. **Implement decode functions**
   ```lua
   -- DecodeLit: Decode literal byte or length code
   -- DecodeDist: Decode backward distance for repetition
   ```

5. **Implement main decompression loop**
   ```lua
   -- Read compression type (binary/ascii) and dictionary size
   -- Loop:
   --   literal = DecodeLit()
   --   if literal < 0x100: output byte
   --   if literal == 0x305: end of stream
   --   if literal >= 0x100: copy from output buffer
   ```

6. **Integrate with extract.lua**
   - Add `require("mpq.pkware")` in extract.lua
   - Replace error message with actual decompression call
   - Handle both IMPLODE flag and COMPRESS+PKWARE flag cases

---

## Technical Notes

### Algorithm Overview

PKWARE DCL uses LZ77 sliding window compression with Shannon-Fano coding:

1. **Compression Types**
   - Binary (0): Raw bytes, simpler decoding
   - ASCII (1): Character codes via lookup tables

2. **Dictionary Sizes**
   - 4 bits: 1024 byte window
   - 5 bits: 2048 byte window
   - 6 bits: 4096 byte window

3. **Literal vs Length**
   - First bit: 0 = literal byte, 1 = length code
   - Length codes 0x100-0x304: repetition with distance
   - Code 0x305: end of stream

### Key Constants

```lua
CMP_BINARY = 0
CMP_ASCII = 1
LITERAL_END = 0x305
```

### Reference Implementation

Based on StormLib's `src/pklib/explode.c` (~800 lines C)

---

## Related Documents

- docs/formats/pkware-dcl-compression.md (existing documentation)
- issues/102d-implement-file-extraction.md (parent extraction issue)

---

## Acceptance Criteria

- [x] Can decompress PKWARE DCL compressed data
- [x] Supports Binary compression mode
- [x] Supports ASCII compression mode (implemented, not tested - no test data available)
- [x] Supports 4/5/6 bit dictionary sizes
- [x] Integrated into extract.lua
- [x] Daow6.2.w3x extracts successfully
- [x] Phase 1 integration test shows 16/16 maps passing
- [ ] Unit tests for decompression (deferred to test suite issue)

---

## Notes

This is an extension to Phase 1 that addresses a known limitation documented
in docs/formats/pkware-dcl-compression.md. Implementation uses pure Lua
(~470 lines) rather than FFI or external dependencies.

Reference: [StormLib source](https://github.com/ladislav-zezula/StormLib)
Reference: [PKWARE DCL spec](http://www.psychopc.org/other/pkware_dcl_spec.txt)

---

## Implementation Notes

### Files Created/Modified

- `src/mpq/pkware.lua` - New pure Lua PKWARE DCL decompressor (~470 lines)
- `src/mpq/extract.lua` - Modified to integrate pkware module

### Implementation Details

1. **Lookup Table Generation (`gen_decode_tabs`)**
   - Pre-computes 256-entry inverse lookup tables for O(1) decoding
   - LenPositions maps peeked bits → length code position
   - DistPositions maps peeked bits → distance code position

2. **BitStream Class**
   - Manages bit-level reading from byte stream
   - Methods: `fill_buffer()`, `peek_bits(n)`, `read_bits(n)`, `waste_bits(n)`
   - Uses 32-bit buffer to accumulate bits before consumption

3. **Decode Functions**
   - `decode_len()` - Decodes length using lookup table + extra bits
   - `decode_dist()` - Decodes distance, uses 2 bits for rep_length=2, else dict_bits
   - `decode_lit_binary()` - Binary mode: flag bit + 8-bit literal or length code
   - `decode_lit_ascii()` - ASCII mode: flag bit + variable-length character code

4. **Key Fix: Expected Size Parameter**
   - PKWARE compressed data does not always contain an end-of-stream marker
   - Added `expected_size` parameter to stop decompression at correct output size
   - extract.lua now calculates per-sector expected size from block table

### Test Results

```
Success: 16 / 16 maps
Daow6.2.w3x: OK (877 bytes w3i) - Previously failed with "PKWARE DCL not implemented"
```
