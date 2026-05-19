---
name: Resource Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904, 905a]
parent: 905
---

# 905b — Resource Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Resource Manager identified by the
issue 904 audit as "lockable." A single `resmgr_lock` serializes
the resource-map walking and resource-fork ops.

## current behavior

The Resource Manager assumes single-threaded callers.

## intended behavior

- `resmgr_lock` acquired on entry to: `GetResource`, `LoadResource`,
  `AddResource`, `RemoveResource`, `WriteResource`, plus the
  enumeration / map-walking routines.
- The lock can be released for blocking I/O (file reads) and
  re-acquired after — but with care that the resource map hasn't
  shifted underneath.

## suggested implementation steps

1. Wait for the audit's Resource Manager section.
2. Add lock wrappers per the audit.
3. Group as `patches/201-resmgr-locks.gsos.s.patch`.
4. Test: two tasks reading resources concurrently; verify
   correctness.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent issue
- `issues/904-toolbox-reentrancy-audit.md`
- `issues/905a-reentrancy-easy-memory-manager.md` — prerequisite

## notes

- Releasing the lock during blocking I/O is the subtle bit. The
  audit will say whether it's safe; if not, the long-held lock
  becomes a candidate for 906b's structural fix.
