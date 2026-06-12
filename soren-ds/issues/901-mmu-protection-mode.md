# 901 — MMU protection mode

## Current behavior

Through phase 8, the MMU has been off — every pointer is a real
physical address, every app shares the kernel's address space
with no isolation. A wild pointer anywhere kills everything. The
memory model doc (`007-memory-model.md`) describes step two:
turn the MMU on, but for *protection only* — no translation, no
per-app virtual address space.

## Intended behavior

The kernel configures the MMU to enforce per-region access
without remapping addresses:

- Identity mapping. Every virtual address resolves to the same
  physical address (the MMU does not change what pointers
  point to).
- Region permissions. The MMU's page table grants or denies
  access per page based on which app is currently running on
  the requesting core.
- The kernel's region is accessible from any context. The
  per-app regions are accessible only from the owning app's
  worker context.

The MMU bring-up:

1. Allocate the page table at a fixed kernel address.
2. Populate every entry with identity mappings.
3. Set permissions: kernel pages are kernel-readable and
   kernel-writeable; app pages are owner-only.
4. Install the page table into the MMU's translation table
   base register.
5. Enable the MMU bit on the system control register.

The MMU enable is the riskiest single operation in the project.
A misconfigured page table at enable-time produces a fault
before the fault handler is wired up, which is unrecoverable
without a reboot. Phase 9 validates the configuration off-line
via the build system before flashing; the kernel image refuses
to boot if the page table is malformed.

## Suggested implementation steps

1. Page table data structure aligned to the MMU's requirements
   (per 101's chip docs).
2. `mmu_install_identity_mapping()` — populate every entry.
3. `mmu_set_region_permissions()` — set per-region access bits.
4. `mmu_enable()` — the dangerous moment; isolated in a
   single function with no other work alongside it.
5. Build-system validation of the page table.

## Related documents

- `docs/007-memory-model.md`.
- `notes/safety/000-bricking-and-recovery.md`.

## Blocked by

101, 108.

## Blocks

902, every later phase 9 issue.
