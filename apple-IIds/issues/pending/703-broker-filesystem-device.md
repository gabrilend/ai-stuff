---
name: Broker Filesystem device
phase: 7
status: pending
blockedBy: [301, 701]
---

# 703 — Broker Filesystem device

The shared volume from issue 301 becomes a first-class GS/OS device,
exposed through the broker virtual peripheral infrastructure (issue
701). The SmartPort fiction goes away.

## current behavior

The shared volume is presented to GS/OS as an emulated SmartPort
hard-disk device (issue 301). This works but adds latency and ties
the volume's API to the limitations of SmartPort.

## intended behavior

- A virtual device named `broker.fs` is registered via the issue
  701 infrastructure.
- The device exposes the shared volume's contents through native
  File Manager ops (open, read, write, close, catalog), not
  through SmartPort block ops.
- GS/OS's File Manager can address files in the shared volume via
  the same path conventions as any other volume.
- Per-file metadata (creator/type, finder info) is preserved
  natively through the device API, not via xattr fiction.
- The native File Manager from issue 602 (when it lands) talks to
  this device directly, with no emulated layer in between.
- Performance: file operations on the shared volume are at most
  one broker-call's latency away from native speed. The
  ~50ms SmartPort overhead drops to ~1ms.

## suggested implementation steps

1. Wait for issue 701's infrastructure.
2. Design the `broker.fs` device's op set:
   - `open(path, mode) → handle`
   - `read(handle, count) → bytes`
   - `write(handle, bytes) → count`
   - `close(handle)`
   - `catalog(path) → entries`
   - `meta(handle) → metadata`
   - `set_meta(handle, metadata)`
3. Implement the broker side in `src/broker/fs-device.lua` (or as
   part of the existing shared-volume.lua refactor).
4. Update GSplus / GS/OS to remove the SmartPort fiction from
   issue 301 once `broker.fs` is reliable.
5. Run the issue 301 conformance tests against the new device
   path. All must pass.
6. Measure file ops per second; expect ~50x speedup vs SmartPort.

## related documents

- `issues/301-shared-backing-filesystem.md` — the staging-ground
  version this replaces
- `issues/701-broker-virtual-peripheral-infra.md` — the
  infrastructure
- `issues/602-file-manager-native.md` — the native File Manager
  that will use this device path directly

## known design questions

- What happens to the SmartPort device during the transition? For
  a brief period both paths exist. The old SmartPort device is
  removed once the new path passes all tests.
- Backward compatibility with existing IIds software: the SmartPort
  device looked like a hard disk; the new device looks like a
  GS/OS volume. The user-visible mount name and behavior should
  be identical. Internal differences are invisible.

## notes

- This is the issue that retires the "virtual disk fiction" the
  arch overview talks about. After it lands, the shared volume is
  no fiction — it's a real GS/OS device.
