# 71 — The self-installing cable (delivery)

The cable bears the software. Everything we write is assembled into a self-contained
bundle that lives on the cable's storage; plug the cable in and the system installs
with one command — or just runs in place — and then it works.

## Current behavior

Implemented and tested — this issue is complete (see `issues/completed/`). A
packager assembles the whole project into a portable "cable image"; a self-installer
that rides on the image checks its few dependencies, asks consent, and copies the
bundle into place with a launcher; a launcher runs the delivered system and proves
it works with a smoke test. Dependencies present on the dev machine at build time:
luajit (required) and libfuse 2.9.9 (optional, enables the mount).

## Intended behavior

- **Packager** (`delivery/package-cable.sh`): gather the non-ephemeral project into
  an output "cable image" ready to copy onto the cable's storage. Runnable from any
  directory via `${DIR}`. Writes a version stamp and a manifest.
- **Portable / run-in-place**: the bundle runs straight from the mounted cable with
  no system install, so "it just works" needs nothing installed but the runtime.
- **Self-installer** (`delivery/install.sh`, rides on the image): self-locates the
  mount, checks dependencies (luajit **required** — hard error if absent; libfuse
  **optional** — reported as a capability, never a silent fallback), asks consent,
  copies to a target, and drops a launcher on `PATH`. Idempotent; supports
  `--uninstall` and `--in-place`.
- **No silent autorun.** Auto-executing code off a plugged-in USB device is the
  BadUSB attack this project exists to avoid; installation is one explicit command.
  An opt-in udev auto-run is offered only as a documented, consent-required extra.
- **Launcher** (`delivery/launch.sh`): the entry point. Reads `input/` at startup
  and writes a goodbye to `output/` on exit (house style); dispatches subcommands
  (today: a smoke test that runs the delivered code; later: mount, send, …).

## Suggested implementation steps

1. `delivery/package-cable.sh`: copy the runtime tree (excluding `tmp/`, `output/`)
   into `${OUT}` (default `output/cable-image`), place `install.sh` and `launch.sh`
   at the image root, and write `VERSION` + `MANIFEST`.
2. `delivery/install.sh`: argument parsing (`--target`, `--bindir`, `--yes`,
   `--in-place`, `--uninstall`), dependency check (error vs capability report),
   consent prompt, copy, launcher generation, log to `tmp/`.
3. `delivery/launch.sh`: resolve its own location as `${DIR}`, ensure a writable
   `tmp/`/`output/`, read `input/`, dispatch, write goodbye.
4. `tests/70-delivery-test.sh`: package → install to a scratch target under `tmp/`
   → run the launcher from there → assert the smoke test passes; assert a missing
   required dependency is refused rather than limped past.

## Related documents and tools

- `docs/delivery-self-installing-cable.md` (mechanism + the security stance).
- Delivers everything from every phase; re-run whenever the project grows.
