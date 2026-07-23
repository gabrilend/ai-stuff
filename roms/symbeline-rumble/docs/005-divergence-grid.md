# Divergence Grid

Each row is a shared problem. Columns describe how the `nds` and `native`
profiles solve it, and what the intended re-convergence path looks like (if
any). When a row's targets converge, the row is updated to note the
convergence and the paired patches are retired.

This grid is the **leash on fractal expansion**. New divergences must add a
row here *before* code is written. No row, no patch.

## Live grid

| #  | Problem                          | `nds`                                                    | `native`                                                   | Re-convergence path                                                  | Patch IDs        |
|----|----------------------------------|----------------------------------------------------------|------------------------------------------------------------|----------------------------------------------------------------------|------------------|
| D1 | Tilt-shift visual                | Layered pre-blurred 2D sprite backdrops above/below the sharp 3D band | Depth-driven GLSL fragment-shader blur post-process       | None planned — DS has no shaders; the techniques will stay distinct.  | B-tbd / B-tbd    |
| D2 | Graphics submission              | libnds 3D engine (matrix stack, paletted textures, no shaders) | raylib/SDL2 + GL ES 2 backend                              | None — different APIs at the metal. Trunk uses `platform_render_*` abstractions. | B-tbd            |
| D3 | Audio mixer                      | DS hardware mixer, 16 channels, hand-fed                 | Software mixer (SDL_mixer or equivalent), matching 16 channels | Mixer interface is in trunk; only the backend implementation diverges. | B-tbd            |
| D4 | Input model                      | DS buttons + stylus events                               | SDL key/mouse events mapped to the same logical buttons    | Trunk consumes `platform_input` events only. Backends diverge.        | B-tbd            |
| D5 | File I/O / save data             | libfat on flashcart / DSi internal storage               | Host filesystem under `$XDG_DATA_HOME/symbeline/`           | Trunk uses `platform_file_*`. Backends diverge.                       | B-tbd            |
| D6 | Top-screen targeting             | Not available (no top-screen touch on DS hardware)       | Available (single window, mouse can hit any pixel)         | Game design rule: any top-screen target must have a unit-target equivalent (game-design re-convergence, not code). | None (design)    |
| D7 | Threading                        | None (cooperative + interrupts only)                     | Single-threaded by choice, to preserve parity              | Likely permanent; if workers ever added, they are native-only patches. | None             |
| D8 | Fonts / text rendering           | Bitmap font in VRAM tile                                 | Same bitmap font, rasterized into a texture                | Asset is shared; backends differ only in how they upload it.         | B-tbd            |
| D9 | Multiplayer transport (cross-target) | libnds proprietary local-wireless API; in-process       | melonDS-derived bridge process speaks DS-proprietary over real radio (USB AR9271 typical) | None — different mechanisms at the metal. The trunk's wire protocol is shared; transports diverge underneath. | B-tbd (phase 7) |
| D10 | Multiplayer transport (same-target) | libnds proprietary local-wireless (between two DSes)    | Our own UDP-shaped peer-to-peer protocol over WiFi Direct or ad-hoc 802.11 (between two natives) | None — different physical layers; same wire payload. | B-tbd (phase 7) |
| D11 | Physical radio access for DS-proprietary | Built-in radio natively speaks the proprietary protocol | Requires USB AR9271 (or other 802.11b-injection-capable) adapter; documented as setup item | None — stock RG-XXXX wifi chips don't support raw injection. May converge if future hardware does. | None (hardware) |
| D12 | Bridge sidecar process lifecycle | None — libnds is in-process                              | Native build launches a bridge subprocess (melonDS-derived wifi stack); communicates via local UDP socket; lifetime managed by the game | None — bridge exists only on native. | B-tbd (phase 7) |

## Adding a row

Before writing code that will differ between targets:

1. Append a row to the live grid with a fresh `D#`.
2. Fill in both target columns. If you cannot yet say what the technique is,
   write "TBD — author plans X" rather than leaving blank.
3. Fill in the re-convergence column honestly. If there is no plausible
   convergence, write "None" and say why. "Maybe later" is not a re-convergence path.
4. Reserve patch IDs (`B###` / `E###`) and create the patch files. Even
   empty patch files (printing "not yet implemented") are better than
   in-tree forks.
5. Only now write the code.

## Retiring a row

When both targets converge to the same technique (e.g., a future raylib
backend appears on DS via some miracle, or a feature is dropped), update
the row to read "Converged: <date> — <technique>" and retire the paired
patches in the same change.

## Why the grid is rendered as a table

A table is a primitive grid graph: rows index problems, columns index
targets, cells index techniques, the rightmost column indexes
re-convergence. The graph is small enough to keep in working memory while
deciding whether a new feature is worth a row.
