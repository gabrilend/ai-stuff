# bsd0.lua

Applies one entry from a Warcraft III patch program: a whole new file, or a
Blizzard "BSD0" binary diff against the old file. Needs LuaJIT.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `read_header(entry)` | the entry's bytes (string) | `{kind, old_crc, old_size, new_size}` (integers), or `nil` and an error |
| `apply(entry, old)` | the entry's bytes; the old file's bytes (string; `nil` for whole files) | the new file's bytes (string), or `nil` and an error |
| `crc32(bytes)` | string | unsigned integer |

## Data

| Name | Value | Meaning |
|------|-------|---------|
| `KIND_WHOLE` | `0x01` | the whole new file follows the header |
| `KIND_DIFF` | `0x04` | a run-length-packed BSDIFF40 diff follows |
| `KIND_DIFF_OLDEST` | `0x00` | the oldest diff format, copy-and-insert records plus 16-bit additions (1.01–1.14b); described in full in `bsd0.lua` |
| `KIND_DIFF_UNPACKED` | `0x02` | a BSDIFF40 diff follows as is, no size word, no packing (two entries in Reign of Chaos 1.18a–1.20e) |
| `RUN_STEP_1_21` | `1` | run-length step from 1.21a on |
| `RUN_STEP_1_20` | `32` | run-length step in 1.19a–1.20e |

## Entry format (24-byte header, little-endian)

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint16 | header size, 24 |
| 2 | uint8 | 0x04 on every entry seen |
| 3 | uint8 | kind |
| 4 | uint32 | CRC32 of the old file (0 for whole files) |
| 8 | uint32 | old file size |
| 12 | uint32 | new file size |
| 16 | uint64 | Windows FILETIME |

Refuses a diff whose old file doesn't have the named CRC32 and size, a result
of the wrong size, and unknown kinds. Every length in a diff is checked
against its buffers before memory is touched (a misread diff once crashed the
process), and old-file bytes are added only where the old position lies
inside the old file, as the reference bsdiff does.

The run-length code counts runs from 1 in patches from 1.21a on, and from 32
in 1.19a–1.20e (a copy token gives `(b & 0x7F) + step` bytes, a zero token
`b + step` zeros). The bytes don't say which; `patch_layer.lua` chooses by the
build number the patch program's script names (below 6263, 1.21a's, is the
older step). Found by comparing the same file's diff in 1.20e and 1.21a;
confirmed on all 218 of 1.20e's archive diffs and by incremental patches
reproducing full-patch layers (issue 112d). An uncompressed diff payload hasn't been
seen yet and is refused until one is.

Ported in part from StormLib's `SFilePatchArchives.cpp` (MIT).

## The oldest diff format (kind 0x00)

Two blocks follow the header's two lengths. Block A rebuilds the file from
records (a 16-bit word: type in the top two bits, length in the low 14):
insert literal bytes; copy from the old file with a running offset; the same
copy adding the last two-byte insert to every 16-bit word; zero bytes. Block B
then adds amounts to 16-bit words, grouped by ascending amount. Numbers are
variable length (1–4 bytes). Rebuilds all 110 known-answer files from 1.14b
(six differ only by later patches' edits). Known gap: the three program
binaries over a megabyte (War3.exe, Game.dll, WorldEdit.exe) fail with a copy
outside the old file; large offsets work some way not yet understood (issue
112d).
