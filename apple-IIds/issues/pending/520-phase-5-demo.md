---
name: phase 5 demo
phase: 5
status: pending
blockedBy: [501, 502, 503, 504, 505, 506, 507, 508]
---

# 520 — phase 5 demo

The deliverable that closes phase 5. Demonstrates the device as a
finished product: cold boot to two desktops with curated software,
settings UI, suspend / resume, audio mixing, and one boot chime.

## current behavior

No phase 5 demo exists. The phase 4 demo demonstrated a usable
device; phase 5 demonstrates a *finished-feeling* device.

## intended behavior

- A script `issues/completed/demos/phase-5/run.sh` extends the
  phase 4 demo.
- The phase 5 demo is the **canonical "first impressions"** demo —
  what someone seeing the device for the first time should see.
- The phase 5 demo:
  - Power on the device: brief loading, one boot chime, both
    screens show GS/OS Finder. Curated apps visible in the
    Applications folder.
  - Open the Settings app on screen A, change a setting (e.g.,
    panel brightness, or audio pan), see it apply live.
  - Open a paint program on screen A, draw something. Open a text
    editor on screen B, type via the radial keyboard. The audio
    mixer keeps both apps audible with proper stereo separation.
  - Close the lid (or trigger the Hall switch): both screens
    sleep. Open the lid: both screens resume exactly where they
    were.
  - Open the docs site (the local HTML at `docs/HTML/`) — this is
    a developer-side demonstration, not on the device itself; or
    it's accessed from the device via a built-in browser if we
    ever have one (out of scope).
- The bottom-panel status strip from earlier phases now shows
  battery percentage, current audio volume, and a small "saving in
  N seconds" indicator from the write-coalescing buffer.

## suggested implementation steps

1. Confirm phase 5 issues 501–508 are completed and moved to
   `issues/completed/`.
2. Pre-load the curated app library (issue 502).
3. Pre-configure a default settings file that showcases the
   personalizations (e.g., pan settings, sleep behavior).
4. Extend `run-demo.sh` to accept `5`.
5. Record the canonical first-impressions video. This becomes the
   project's "trailer."
6. Update `issues/phase-5-progress.md`.

## related documents

- All of phase 5 (501–508)
- `issues/420-phase-4-demo.md` — the prior demo
- `docs/004-roadmap.md` — phase 5 entry

## notes

- This demo closes out the **staging-ground polish** phase. After
  phase 5, the device is a usable product. Phases 6–10 are
  modifications and rewrites that improve the *internals*; from
  the user's perspective the device works the same.
- Worth a real video recording with voice-over narration — this is
  the demo that sells the project to skeptics.
