# 141-a-bootable-medium — info

Wraps one file into a medium a firmware will open. Issue `502`, steps seven
through nine; checked by `142`, including by real firmware on all three
architectures.

Treat it as a black box: hand it a file and where the file goes, get back the
bytes you would put on a card.

## Invocation

```lua
local medium = dofile(DIR .. "/src/141-a-bootable-medium.lua")
local made, why = medium.medium({
  bytes    = the_file_contents,        -- the thing a firmware will run
  path     = "EFI/BOOT/BOOTX64.EFI",   -- where it looks for it
  identity = "some string",            -- what the identifiers derive from
  sectors  = nil,                      -- optional; a size is found if absent
  label    = "SEED",                   -- optional, up to eleven characters
})
```

`made` is `{ image, partition_at, partition_sectors, total_sectors, shape }`,
or `nil` and a sentence.

| Also offered | What it is for |
|---|---|
| `medium.crc32(bytes)` | the check a partition table makes of itself |
| `medium.geometry(sectors)` | how a partition of that size divides into a FAT16 filesystem, or nil |
| `medium.filesystem(options)` | just the partition, without a table around it |
| `medium.SECTOR` | five hundred and twelve, named once |
| `medium.ESP_TYPE` | the identifier marking a partition as the one to start from |

## Why this exists

For months every emulated machine here booted from a directory the emulator
synthesised into a filesystem, so the thing the image builder produced was never
the thing under test — and it turned out no firmware could open it. Both halves
were right about their own half: the builder's offsets matched what the engine
looks for exactly. Nobody asked the component that has to find the first byte.

## Behaviour worth knowing

- **The smallest medium is about four megabytes**, and the floor comes from the
  filesystem rather than from anything chosen here. Which of the three FATs a
  filesystem *is* depends on how many clusters it has, and this one is only
  FAT16 above roughly four thousand of them — so a partition holding a
  one-kilobyte file still has to be a couple of megabytes or it stops being the
  format its own boot sector claims.
- **The size is found rather than calculated** when none is given, because the
  arithmetic is circular: the cluster size depends on the total and the total
  depends on the cluster size. It steps a megabyte at a time and asks.
- **Long names are written when a name needs them.** The third architecture's
  boot path is `EFI/BOOT/BOOTRISCV64.EFI`, whose stem is eleven characters and
  does not fit the eight-and-three naming FAT has always had. An earlier version
  refused it, with a comment claiming no firmware path needed long names — a
  claim made by looking at one machine.
- **Identifiers are derived, never drawn.** Every tool that writes a partition
  table generates its names at random, which would make the build produce a
  different image every time from the same recipe. They come from the caller's
  identity string instead.
- **The table is written at both ends**, which is what the format requires: one
  that exists once is one that a single bad sector destroys.

## The mistake this file already made once

The checksum was written with addition where the algorithm needs exclusive-or,
on the reasoning that adding to a value with no overlapping bits is the same
thing. It is the same thing only when the bits do not overlap, which is exactly
the case that does not hold. It produced a plausible thirty-two bit number for
every input and the wrong one for all of them — and a partition table whose
check fails is ignored **in silence**, so the failure would have been a machine
that boots nothing with no message naming a reason.

It was caught because the algorithm has a published answer for the digits one to
nine, and `142` checks that before it trusts anything else here.
