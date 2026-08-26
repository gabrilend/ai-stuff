# 038 — What lives where

```meta
phase  | 5
issues | 505
```

The core's address space, region by region, with a size, an alignment, an owner
and an access rule.

```drawing
the core's address space, low to high [not-dimensioned]

   ┌──────────────────────────────────────────┐
   │ weight residency          [C_weights]    │  written once at load,
   │                                          │  read by all six faces
   ├──────────────────────────────────────────┤
   │ key and value cache       [C_kv]         │  grows with context;
   │                                          │  each face owns its own
   ├──────────────────────────────────────────┤
   │ sieve staging buffers     [C_staging]    │  six, one per stage
   ├──────────────────────────────────────────┤
   │ reverse staging buffers   [C_staging_r]  │  six more, for 076a
   ├──────────────────────────────────────────┤
   │ activation checkpoints    [C_checkpoint] │  only when training
   ├──────────────────────────────────────────┤
   │ adapter and optimiser     [C_adapter]    │  only when training
   ├──────────────────────────────────────────┤
   │ the request region        [C_request]    │  the host writes here
   ├──────────────────────────────────────────┤
   │ repair and scrub state    [C_repair]     │  040's
   ├──────────────────────────────────────────┤
   │ control and status        [C_control]    │  including the pane window
   └──────────────────────────────────────────┘
```

## The three that are not just storage

**The staging buffers** are the surface between pipeline stages. Their size sets
how far ahead a face may run, and `053` decides that, so this blueprint takes the
number rather than choosing it.

**The pane window** is not memory. It is an aliasing register saying which two
mebibytes of the core the spout currently sees; moving it is one store. The
alignment must match `063`'s tiling so a pane maps to banks without a shift, and
a misaligned value must be **refused rather than rounded** — a spout quietly
reading a different two mebibytes than the one asked for is a fault with no
symptom.

**The request region** is the only part of the core with a defined layout that
something outside the cube writes. It is therefore the only part with a
compatibility obligation, and it is marked as such.

## Interleaving is the real content

The weight region must be laid out so that a face reading its own layers
sequentially touches banks in a pattern that does not collide with the other five
doing the same in their own regions.

**Get this wrong and the machine loses bandwidth to bank conflicts while every
individual blueprint still checks.** It is the sort of failure that appears only
in `080`'s end-to-end model, which is one of the reasons that model has to exist.

## Symbols

```symbols
C_request     | MB | given | 1     | where a host puts a token identifier and takes one back; the machine's only compatibility surface
C_control     | MB | given | 1     | control and status, including the pane window's aliasing register
C_repair      | MB | given | 16    | the repair map and scrub state from 040
w_interleave  | bit| given | 32768 | address granularity at which consecutive addresses move to the next bank. Eight thousand was tried and is narrower than a single cycle's read from one tier, which would have meant every transfer straddling two banks
C_pane        | MB | derived | n_pane_bit       | the window the spout sees, from 062
n_region      | 1  | given | 9     | regions in the map

C_staging     | MB | derived | n_stage * C_stage_buf                | the six forward staging buffers
C_staging_r   | MB | derived | n_stage * C_stage_buf                | and the six reverse ones for training
C_mapped      | GB | derived | C_weights + C_kv + C_staging + C_staging_r + C_checkpoint + C_adapter + C_request + C_control + C_repair | everything with an address
C_free        | GB | derived | C_core_usable - C_mapped             | what is left
f_mapped      | 1  | derived | C_mapped / C_core_usable             | how full the map is at the reference model
n_bank_stride | 1  | derived | w_interleave / w_tier_port           | cycles a single bank is held before the address moves on
```

## Constraints

```constraints
C-038-1 | C_mapped <= C_core_usable      | everything mapped must fit in what 034 says is usable. The map is what turns a capacity into a limit
C-038-2 | C_free > 0                     | and there must be something left over, because the alternative is a machine that fits its reference model exactly and no other
C-038-3 | w_interleave >= w_transfer     | the interleave granularity must be at least 052's transfer size, so that a single transfer is never split across two banks
C-038-4 | C_pane ~= n_pane_bit          | the pane window's size must be exactly what 062 defines
C-038-5 | C_staging >= C_stage_min       | the staging buffers must hold at least what 053's look-ahead needs
C-038-6 | n_region == 9                  | nine regions. Asserted so that a tenth arrives with an argument rather than by accident, since every region is address space nothing else can have
C-038-7 | n_bank_stride >= 2             | a bank must be held for at least two cycles before the address moves on, or the crossbar spends more time switching than transferring
```

## What is still open

**The interleaving is a stride and not an analysis.** `034` estimated bank
collisions assuming six independent address streams; they are six streams walking
six contiguous regions in step, which is about as correlated as access patterns
get. Whether that makes collisions rarer or more frequent depends entirely on
where the six regions begin relative to the stride, and nobody has worked it out.
**This is the piece of phase 5 most likely to cost real bandwidth silently.**

**The training regions are sized at zero when not training** and there is no
mechanism for that. `076a` needs them and `078`'s residency arithmetic has to
know whether they are present, and the map has no notion of a mode.

**Nothing says what happens on an out-of-range address.** There is no protection
in this machine and no fault for it, so a face computing a wrong address reads
somebody else's region and produces plausible nonsense. `049` has fault bits and
none of them is this.
