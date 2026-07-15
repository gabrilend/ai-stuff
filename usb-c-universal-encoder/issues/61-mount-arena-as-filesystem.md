# 61 — Mount the arena as a filesystem (local mode)

Expose a file directory (over its arena) as a real mountpoint via FUSE, so ordinary
tools — `ls`, `cat`, `cp`, `rm` — are the interface. No peer yet; this proves the
VFS↔store mapping on one machine.

## Current behavior

Not yet implemented. The dev machine can host it: `fusermount`/`fusermount3` are
present, `/dev/fuse` exists, the kernel lists `fuse`, and libfuse **2.9.9** is
installed (verified at scaffold time). Depends on the file directory (issue 12),
which is not built yet.

## Intended behavior

- A FUSE adapter binds a running file directory to a mountpoint. Kernel file
  operations are answered from the arena:
  - `getattr`/`readdir` → the directory's `stat`/`list`,
  - `create` → an empty named region,
  - `read`/`write` → direct arena read/poke at the requested offset,
  - `truncate` → region resize, `unlink` → region free,
  - `setxattr user.direction` (and its getxattr) → the file's `direction` metadata.
- Mounted with `noexec,nosuid,nodev,default_permissions`, so the "no arbitrary
  execution" promise holds at the VFS layer too (see `docs/mount-as-filesystem.md`).
- A mount/unmount script with the standard `${DIR}` convention (hard-coded default,
  overridable by argument), which ensures the mountpoint exists and cleans up on
  exit.
- Unknown/unsupported operations return a proper errno, never a silent success.

## Suggested implementation steps

1. Decide the binding: a LuaJIT FFI binding to libfuse 2.9.9 (the high-level
   `fuse_operations` struct of callbacks + `fuse_main`), or vendor an existing Lua
   FUSE binding into `libs/`. Record the choice and why in the module header.
2. `src/NN-fuse-mount.lua`: implement the callback set above, each delegating to the
   directory/arena API so bounds and validation live in one place.
3. A run script (`run-mount.sh`) honoring `${DIR}`: create the mountpoint, launch
   the adapter with the safe mount options, and unmount on signal/exit.
4. Test by mounting to a scratch dir under `tmp/`, performing real `cp`/`cat`/`rm`
   with shell tools, unmounting, then asserting the arena/directory reflects the
   operations. Also assert a file copied in cannot be executed from the mount.

## Related documents and tools

- `docs/mount-as-filesystem.md` (mechanism + the VFS→opcode table), blocks on issue
  12, precedes issue 62 (peer mode).
