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

## Open questions

- *Which partition, when the card has several?* The first one marked
  FAT32 (types 0x0B or 0x0C). FAT16 and exFAT partitions are named on
  the developer's line as refused, so a person who reformatted the card
  the wrong way is told what to do about it.
- *Is FAT32 decided by the cluster count, as the specification says, or
  by the boot block's shape?* By the shape: 512-byte sectors, no
  fixed-size root directory, no 16-bit table size. That is what Linux's
  own driver goes by, and a laptop's `mkfs.fat -F 32` on a small card
  makes FAT32 with fewer than the specification's 65525 clusters.
- *What about a card formatted whole, with no partition table?*
- *What about a boot block whose numbers do not add up?*

### Proposed answers (UNVERIFIED)

1. *Which partition?* The first FAT32 one — built.
2. *FAT32 by count or by shape?* By shape — built.
3. *No partition table?* Mounted, from block zero, but only when no
   partition entry claims FAT32 and block zero itself is a FAT32 boot
   block (jump instruction, 512-byte sectors, "FAT32" in its type
   field). A partition table always wins. The doc's rule is to meet the
   card where it is, and some laptops format a card that way.
4. *Numbers that do not add up?* Refused, with a line giving them: a
   cluster size of zero or not a power of two (zero used to divide by
   zero during mount), no reserved sectors or tables, tables and
   reserved space larger than the partition, a table too short to have
   an entry for every cluster (Linux refuses that card too), and a root
   directory whose cluster is not on the volume.
5. *(new)* **The in-memory table can be given back** (`fat_unmount`),
   for a card taken out or a test mounting twice, and a mount that fails
   part-way now gives back what it had taken.
6. *(new)* The report through the debug line is one sentence at mount:
   label, cluster size, first data block, and free clusters of the
   total. The "FAT version" the issue asked for is always FAT32, since
   anything else is refused.

## Related documents

- `docs/011-filesystem.md`.

## Blocked by

401.

## Blocks

403, 404.
