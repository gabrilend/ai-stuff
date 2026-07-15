# Mounting a USB-C link as a filesystem

The most natural interface for "everything is a file" is an *actual* filesystem.
Instead of a bespoke UI, a connected USB-C peer appears under `/mnt/` (e.g.
`/mnt/usb-c-<peer>/`), and the ordinary tools are the API: `ls` to see what the
far end sent, `cat` to read it, `cp myfile /mnt/usb-c-<peer>/` to send one, `rm` to
delete. The VFS becomes the front door.

## The mechanism: FUSE

The kernel's Virtual File System layer turns a syscall like `read("/mnt/.../foo")`
into a call to whatever filesystem owns that mountpoint. **FUSE** (Filesystem in
Userspace) lets *our own userspace program* be that filesystem: we register a set
of callbacks (`getattr`, `readdir`, `open`, `read`, `write`, `create`, `truncate`,
`unlink`, …), the kernel routes every operation on the mountpoint to them via
`/dev/fuse`, and we answer out of the RAM arena.

This is the same edge-glue pattern as the USB transport: the OS-specific part is a
thin adapter; the store, opcodes, and link underneath it are portable. FUSE is the
Linux/macOS answer (libfuse / macFUSE); WinFsp is the Windows equivalent with the
same "implement these file ops" contract. So the mount is universal in the same way
the wire format is — only the adapter changes per OS.

Environment reality (verified at scaffold time on the dev machine): `fusermount`
and `fusermount3` are present, `/dev/fuse` exists, the kernel lists `fuse`, and
libfuse **2.9.9** is installed (fuse3 headers are not). So a *local* mount is
buildable and testable here today; the binding targets libfuse 2.x, with 3.x as a
drop-in where present.

## VFS operation → store action → opcode

Every file operation the kernel hands us becomes a store mutation, and (in peer
mode) the same mutation is encoded as an opcode and sent across the link. There is
no operation that is not already expressible in the safe opcode set — which is why
mounting adds no new capability and no new risk.

| VFS op (kernel → our FUSE callback) | store action                    | opcode sent to peer            |
|-------------------------------------|---------------------------------|--------------------------------|
| `getattr` / `readdir`               | `stat` / `list` (query only)    | — (local read)                 |
| `create` / `mknod`                  | make an empty named region      | `OP_FILE_ALLOC name,0`         |
| `open`                              | confirm the file exists         | —                              |
| `read(off,len)`                     | read bytes from the arena       | — (data already local)         |
| `write(off,buf)`                    | poke bytes into the region      | `OP_FILE_WRITE name,off,buf`   |
| `truncate(len)`                     | resize the region               | `OP_FILE_TRUNCATE name,len`    |
| `unlink`                            | free the region                 | `OP_FILE_DELETE name`          |
| `setxattr user.direction`           | set the `direction` metadata    | `OP_FILE_META name,direction,v`|
| `rename`                            | delete old + create/​write new  | `OP_FILE_DELETE` + `ALLOC`/`WRITE` |

Incoming opcodes from the peer mutate the arena directly, so the new/changed files
simply *appear* in the mount on the next `readdir`/`getattr` — no push needed.

## Safety at the mount

Mounting does not weaken the "no arbitrary code execution" promise; it reinforces it
with a second, independent layer:

- Mount options **`noexec,nosuid,nodev`**: the kernel refuses to execute any file on
  the mount, ignore setuid bits, and honor device nodes — so even a binary the peer
  sends cannot be run *from* the mount.
- **`default_permissions`**: the kernel enforces ownership/permission checks against
  our reported `getattr`, rather than trusting the caller.
- FUSE runs as the mounting user in userspace; it holds no extra privilege, and a
  crash unmounts rather than harms the kernel.
- The opcode path is unchanged: the peer still cannot express anything but a file
  mutation, because the wire vocabulary has no run/eval/syscall verb.

## Two modes

1. **Local mode** — mount a single arena+directory as a filesystem with no peer.
   Depends only on the RAM data core (Phase 1). This is the first milestone and is
   testable on the dev machine: mount to a scratch dir, `cp`/`cat`/`rm`, unmount,
   assert the arena reflects it.
2. **Peer mode** — each connected USB-C cable gets its own arena kept in sync with
   the far end over the `link`, mounted at `/mnt/usb-c-<peer>/`. Writes encode to
   opcodes and cross the wire; incoming opcodes surface as files. Depends on the
   framing/link (Phase 2) and the USB transport (Phases 3–4).

See `issues/61-mount-arena-as-filesystem.md` (local adapter) and
`issues/62-mount-usb-c-peer.md` (per-cable peer mount) for the build steps.
