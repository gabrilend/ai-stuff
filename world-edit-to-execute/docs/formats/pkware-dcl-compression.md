# PKWARE DCL Compression

**Status:** Not Implemented
**Affected Files:** 1 test map (Daow6.2.w3x)
**Priority:** Low (workaround: use newer map versions)

---

## Overview

PKWARE Data Compression Library (DCL) is a legacy compression algorithm used in
some older Warcraft 3 map files. It predates the more common zlib compression
and was part of PKWARE's proprietary compression suite.

MPQ archives can use multiple compression methods, identified by a flag byte at
the start of compressed sectors:

| Flag | Compression Method | Status |
|------|-------------------|--------|
| 0x01 | Huffman encoding | Not implemented |
| 0x02 | zlib/DEFLATE | **Implemented** |
| 0x08 | PKWARE DCL (implode) | Not implemented |
| 0x10 | bzip2 | Not implemented |
| 0x20 | LZMA | Not implemented |
| 0x80 | IMA ADPCM (audio) | Not implemented |

Most modern WC3 maps use zlib (0x02) compression. PKWARE DCL (0x08) appears in
some older maps created with early versions of the World Editor.

---

## Technical Details

### Algorithm

PKWARE DCL uses a combination of:
1. **LZ77 sliding window** - Dictionary-based compression with back-references
2. **Shannon-Fano coding** - Variable-length prefix codes (predecessor to Huffman)

The algorithm was originally implemented in PKZIP and later exposed as a
standalone library (PKWARE DCL / "implode").

### Detection

In our MPQ extractor, DCL compression is detected in `src/mpq/extract.lua`:

```lua
-- Compression flags (first byte of compressed data)
local COMPRESS_ZLIB = 0x02
local COMPRESS_PKWARE = 0x08

local compression = data:byte(1)
if compression == COMPRESS_PKWARE then
    return nil, "PKWARE DCL decompression not implemented"
end
```

### Affected Test Map

```
File: Daow6.2.w3x
Size: 2.6 MB
Issue: war3map.w3i and war3map.w3e use PKWARE DCL compression

Error message:
  "Sector 1 decompression failed: PKWARE DCL decompression not implemented"
```

This is an older version of the Dark Ages of Warcraft map series. Newer versions
(5.x, 6.8+, 7.x) use zlib compression and work correctly.

---

## Implementation Options

### Option 1: Pure Lua Implementation

Implement the DCL decompression algorithm in Lua. This would require:

1. Shannon-Fano tree decoding
2. LZ77 sliding window with variable-length codes
3. Handling of literal bytes vs back-references

Complexity: Medium-High
Reference: StormLib's `explode.c` (~800 lines of C)

### Option 2: FFI Binding

Use LuaJIT FFI or Lua C API to bind to an existing C implementation:

- StormLib's explode.c
- zlib's contrib/blast (PKWARE DCL compatible)
- libmpq's decompression routines

Complexity: Low (if using LuaJIT), Medium (if pure Lua 5.4)

### Option 3: External Tool

Shell out to an external decompression tool:

```lua
-- Hypothetical implementation
local function decompress_pkware(data)
    local tmp_in = os.tmpname()
    local tmp_out = os.tmpname()
    write_file(tmp_in, data)
    os.execute(string.format("pkware-decompress %s %s", tmp_in, tmp_out))
    return read_file(tmp_out)
end
```

Complexity: Low
Downside: External dependency, slower

### Option 4: Skip (Current Approach)

Since only 1 of 16 test maps uses DCL compression, and newer versions of that
map exist with zlib compression, this limitation has minimal practical impact.

---

## Implementation Checklist

When implementing PKWARE DCL support, complete these steps:

- [ ] Choose implementation approach (Lua, FFI, or external)
- [ ] Create `src/mpq/pkware.lua` module
- [ ] Implement `pkware.decompress(data)` function
- [ ] Add compression flag handling in `src/mpq/extract.lua`
- [ ] Test with Daow6.2.w3x (should extract war3map.w3i and war3map.w3e)
- [ ] Run full integration test suite (should now show 16/16 passing)
- [ ] Update `src/tests/phase1_test.lua` to expect 16/16
- [ ] Update `issues/progress.md` to remove known limitation note
- [ ] **Delete this document** (see below)

---

## Document Removal Instructions

Once PKWARE DCL decompression is implemented and verified:

1. **Verify all tests pass:**
   ```bash
   lua5.4 src/tests/phase1_test.lua
   # Should show: 16/16 maps passed
   ```

2. **Verify the specific map works:**
   ```bash
   lua5.4 src/cli/mapdump.lua assets/Daow6.2.w3x -c info
   # Should display map info without errors
   ```

3. **Remove this document:**
   ```bash
   git rm docs/formats/pkware-dcl-compression.md
   ```

4. **Update table of contents:**
   Edit `docs/table-of-contents.md` to remove the reference to this file.

5. **Commit the removal:**
   ```bash
   git commit -m "Remove PKWARE DCL documentation (now implemented)"
   ```

---

## References

- [StormLib source](https://github.com/ladislav-zezula/StormLib) - `src/pklib/explode.c`
- [PKWARE DCL specification](http://www.psychopc.org/other/pkware_dcl_spec.txt)
- [zlib contrib/blast](https://github.com/madler/zlib/tree/master/contrib/blast) - PKWare DCL compatible
- [MPQ format documentation](http://www.zezula.net/en/mpq/mpqformat.html)

---

## Related Documents

- [docs/formats/mpq-archive.md](mpq-archive.md) - MPQ archive format
- [issues/progress.md](../../issues/progress.md) - Project progress tracking

---

*Document created: 2025-12-16*
*Status: Pending implementation*
