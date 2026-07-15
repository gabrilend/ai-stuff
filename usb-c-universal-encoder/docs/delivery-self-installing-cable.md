# Delivery — the self-installing cable

The cable carries its own software. Everything the project produces is assembled
into a portable bundle that lives on the cable's storage; plug the cable in and the
system either runs straight from the mount or installs with a single command, then
works. This is Phase 7, and it re-runs as the project grows — whatever exists gets
delivered.

## The three pieces

1. **Packager** — `delivery/package-cable.sh`. Gathers the non-ephemeral project
   (source, libraries, docs, notes, issues, tests) into an output "cable image": the
   exact folder you would copy onto the cable's storage. It drops the installer and
   launcher at the image root and writes a `VERSION` stamp and a `MANIFEST`.
2. **Self-installer** — `delivery/install.sh`, which rides *on* the image. Run once
   from the mounted cable: it locates itself, checks the few things it needs, asks
   permission, copies the bundle to a target directory, and puts a launcher on your
   `PATH`. It is idempotent and can `--uninstall` or install `--in-place`.
3. **Launcher** — `delivery/launch.sh`. The entry point for the delivered system.
   In house style it reads `input/` at startup and writes a goodbye to `output/` on
   exit. It dispatches subcommands; today the default runs a smoke test that executes
   the delivered code so you can see it work, and later it will mount, send, receive.

## Why not "just autorun on plug"

Because auto-executing code the instant a USB device is plugged in is precisely the
**BadUSB / autorun-worm** attack that this entire project is built to refuse. The
whole point of the wire is that received bytes are *data*, never code; it would be
incoherent to then let the *delivery mechanism* silently run code off a stranger's
cable.

So "easy" here means **one explicit command**, not zero. The bundle is also fully
**portable** — it runs in place from the mount with no install at all — so the
easiest path executes nothing you did not ask for. For users who genuinely want
plug-and-go on their *own* trusted cable, an opt-in udev rule that runs the installer
on connect is offered as a documented, consent-required extra — never the default.

## Dependencies, reported not hidden

- **luajit** — required. Absent → the installer stops with a clear error, rather
  than limping on in a half-working state.
- **libfuse** — optional; it enables mounting a peer under `/mnt/` (Phase 6). Absent
  → the installer reports "mount capability unavailable (libfuse not found); file
  transfer still works," as a stated capability, not a silent fallback. (Present on
  the dev machine at build time: 2.9.9.)

## Universality

The bundle is portable code plus a thin launcher. The only per-OS parts are the ones
the rest of the project already isolates at its edges — the FUSE adapter for mounting
(`docs/mount-as-filesystem.md`) and the USB glue (`docs/transport-design.md`). The
delivery layer itself just copies files and writes a launcher, which any POSIX-ish
environment supports; a Windows path would swap the shell launcher for its
equivalent while shipping the identical payload.

See `issues/71-self-installing-cable.md` for the build steps and
`issues/63-cable-courier-sync.md` for how a carried cable reconciles with a machine
it is plugged into.
