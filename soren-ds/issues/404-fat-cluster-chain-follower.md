# 404 — FAT cluster chain follower

## Current behavior

The partition reader (402) located the FAT itself, but reading or
writing a file's data requires following the chain of clusters
the FAT records for that file. Without a chain follower, even a
multi-cluster file is unreadable.

## Intended behavior

The chain follower exposes:

- `chain_read(fat_volume *, start_cluster, offset, buffer, length)`
  — read `length` bytes from the file starting at `offset` into
  the buffer. The follower walks the FAT chain until it lands in
  the cluster containing `offset`, then reads sequential
  clusters until the buffer is full.
- `chain_write(fat_volume *, start_cluster, offset, buffer, length)`
  — symmetric write.
- `chain_allocate(fat_volume *, current_end, additional_clusters)`
  — extend a file by N clusters. Finds free clusters in the FAT,
  links them onto the file's chain, returns the new end cluster.
  Used by `write-path` when an existing file gets larger.
- `chain_free(fat_volume *, start_cluster)` — release every
  cluster in the chain back to the free pool. Used by
  `delete-path`.

The FAT itself is a flat array of 32-bit entries (FAT32). Each
entry holds the next cluster in the chain, or a special value:

- `0x00000000` — cluster is free.
- `0xFFFFFFF7` — cluster is bad (never use).
- `0xFFFFFFF8` through `0xFFFFFFFF` — end of chain.

Writes to the FAT use the same temp-and-rename pattern the
filesystem doc describes for files, applied to the FAT itself:
write the new chain bytes to a scratch area, atomically point
the FAT root to it, free the old chain. This way a power loss
mid-write leaves either the old chain or the new chain, never a
broken half-and-half.

A FAT cache holds the working FAT in RAM — the FAT is small
enough (a few MB for a 32 GB card) to keep entirely in memory.
Reads hit the cache; writes update the cache and schedule a
flush to disk.

## Suggested implementation steps

1. `fat_cache_load()` — read the whole FAT into RAM at boot.
2. `chain_read()`, `chain_write()`.
3. `chain_allocate()` — scan for free clusters, link them.
4. `chain_free()` — walk the chain, mark each entry free.
5. `fat_cache_flush()` — write modified FAT regions back to
   disk.

## Related documents

- `docs/011-filesystem.md`.

## Blocked by

108, 401, 402.

## Blocks

403, 406, 407.
