# 402 — FAT partition reader

## Current behavior

The SD driver (401) can read blocks but does not know what those
blocks mean. The card has a partition table at block zero and a
FAT filesystem starting somewhere inside the partition. Without
a parser, every block looks the same.

## Intended behavior

The partition reader parses two on-disk structures:

- **The MBR** at block zero. Four partition entries; we use the
  first FAT-marked entry. The entry's start LBA tells us where
  the partition begins.
- **The FAT Boot Parameter Block** at the partition start.
  Carries the sector size (always 512 for SD), the sectors per
  cluster, the reserved sector count, the FAT count (usually 2),
  the FAT length, the root cluster (for FAT32), and the volume
  label.

From these the reader computes:

- The first sector of the FAT.
- The first sector of the data area.
- The cluster-to-sector mapping function.
- Whether the filesystem is FAT16, FAT32, or exFAT (only FAT32
  is in scope for launch; the reader refuses FAT16 and exFAT
  with a hard error).

The output is a `struct fat_volume` populated with the computed
fields, ready for the directory walker (403) and the chain
follower (404) to consume.

The reader reports the FAT version, the cluster size in bytes,
and the data area starting LBA through CDC-ACM during init.

## Suggested implementation steps

1. `struct mbr_partition_entry` and `struct fat_bpb`.
2. `read_mbr()` — block-zero parse, return the active FAT
   partition's start LBA.
3. `read_bpb()` — partition-start parse, populate a
   `fat_volume`.
4. `compute_volume_layout(fat_volume *)` — derive sector
   offsets and the cluster math.

## Related documents

- `docs/011-filesystem.md`.

## Blocked by

401.

## Blocks

403, 404.
