---
name: application library curation
phase: 5
status: pending
blockedBy: [301, 501]
---

# 502 — application library curation

The device ships with a curated set of preloaded IIds software. The
wishlist from the vision document (a doc editor, a paint program, a
game, a music player, a tech demo or two) is the minimum. Each app
boots and is usable end-to-end.

## current behavior

The device boots GS/OS to a Finder but has only stock system
software. The wishlist apps aren't installed.

## intended behavior

- A `assets/library/` directory contains the curated apps as `.2mg`
  or `.shk` (Shrinkit archive) files.
- On first boot, the boot script copies these into the shared
  volume's `Applications/` folder, where the Finder picks them up.
- Subsequent boots don't re-copy; the user's modifications to apps
  persist.
- The curated set, version 1:
  - **Teach** — a small text editor (ships with GS/OS)
  - **AppleWorks GS** — the productivity suite (license permitting)
  - **Platinum Paint** or **DeluxePaint II GS** — the paint program
    (license permitting)
  - **Cogito**, **Task Force**, or **Modulae** — visual tech demos
  - a music player or tracker (NoiseTracker GS or Music Construction
    Set GS — license permitting)
  - one game (visually striking, license permitting)
- Each app's license is verified before bundling. If a recommended
  app's redistribution status is unclear, it's left out and the
  user must supply it themselves (with documentation on how).
- A "library refresh" tool re-syncs the curated set if the user
  deletes something by accident.

## suggested implementation steps

1. Build the candidate list from the vision document's wishlist.
2. For each candidate, verify license terms. Document each in
   `assets/library/LICENSES.md`.
3. Drop the redistributable ones into `assets/library/`. For the
   non-redistributable ones, write a `assets/library/MANUAL.md`
   explaining how the user can obtain and install them.
4. Write the first-boot copy logic in the broker.
5. Write the "library refresh" tool.
6. Test on a fresh device: power on, see Applications populated.
   Open each app, confirm it boots.

## related documents

- `notes/vision/000-vision.md` — software wishlist
- `issues/301-shared-backing-filesystem.md` — provides Applications
  folder
- `issues/501-boot-configuration.md` — provides first-boot detection
- `docs/001-architecture-overview.md` — license posture

## known design questions

- License verification process: maintain a spreadsheet of every
  bundled app, its license, and a link to a verifying source.
  Update on every release.
- What about IIds emulator-specific demos (e.g., demos that exploit
  GSplus's particular quirks)? Skip these — they're not faithful
  to "real IIds software" and the bare-metal port (phase 11) would
  break them.
- Update mechanism for the library? A future issue — for phase 5,
  shipped-with-device is enough.
