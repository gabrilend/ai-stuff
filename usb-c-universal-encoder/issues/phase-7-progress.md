# Phase 7 progress — Delivery: the self-installing cable

Phase 7 makes the cable bear its own software: whatever the project produces is
packaged into a portable image that runs in place or installs with one explicit
command. It is re-run as the project grows, so the cable always carries the current
system.

Do not trust the note below over the test: `tests/70-delivery-test.sh` is the
authority on "does delivery work" — it packages, installs, and runs the result.

## Completed

- **71 — The self-installing cable** (`issues/completed/71-self-installing-cable.md`).
  Three pieces, working and tested end to end:
  - a **packager** that assembles the non-ephemeral project into a "cable image"
    with a version stamp, manifest, and a plain-sight README;
  - a **self-installer** that rides on the image, checks dependencies (luajit
    required — hard error if absent; libfuse optional — reported as a capability,
    not a silent fallback), asks consent, copies the bundle, and drops a launcher on
    `PATH` (with `--in-place` and `--uninstall`);
  - a **launcher** that reads `input/`, runs the delivered code (today a smoke test),
    and writes a goodbye to `output/`.
  The security stance is explicit: no silent autorun (that is the BadUSB attack the
  project refuses); "easy" is one command, and the bundle is portable enough to run
  straight off the mount. Verified by `tests/70-delivery-test.sh` (PASS).

## Notes for later builds

- As Phases 1–6 fill in, the launcher's dispatch (`mount`, `send`, `receive`) grows;
  the packager already ships whatever exists, so re-running it delivers the new
  capabilities with no change to the delivery layer.
- The opt-in udev auto-run convenience (documented, consent-required) is not built
  yet; it is described in `docs/delivery-self-installing-cable.md` for when wanted.
