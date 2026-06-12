# 803 — Programming environment: HTTP server and editor canvas

## Current behavior

The programming environment app needs to expose the soramech
editor canvas at an HTTP URL the user can reach from a laptop
browser. No HTTP server exists in the kernel; no canvas-side
asset bundle is being served.

## Intended behavior

The kernel includes a small HTTP server box that listens on
port 7700 (the same port the parent soramech project uses for
its desktop editor). The server is minimal — GET and POST only,
no chunked encoding, no keep-alive past a few requests, no TLS.
The transport sits on the UDP-with-rmail-acknowledgement stack
from phase 7 wrapped in just enough TCP-imitation to satisfy
browser clients (a small adapter layer specifically for HTTP).

The server's routes:

- `GET /` — the editor's HTML shell, served from
  `assets/editor/index.html` baked into the kernel image.
- `GET /editor.js`, `/editor.css`, `/canvas.png` etc. —
  static assets from `assets/editor/`.
- `GET /map/<name>` — serves a map's JSON files as a tarball
  (or a small bundle the editor's JavaScript reassembles).
- `POST /map/<name>` — accepts an edited map's JSON files and
  writes them through `write-path` to `/programs/<name>/`.
- `POST /map/<name>/run` — invokes the map through 308's
  `map_run`; the response includes the map's final output.

The editor's HTML/JS/CSS is a near-exact copy of the parent
soramech project's editor (which is itself a canvas-and-
inspector single-page application). The asset bundle is built
during the kernel's compile and statically linked as a
`uint8_t array`; the HTTP server walks the array to satisfy
asset GETs.

A laptop browser on the same ad-hoc network or the USB-C link
points at `http://<device-ip>:7700/` and gets the editor. The
device sees changes save through the POST route in real time.

## Suggested implementation steps

1. The minimal HTTP server box — handles a request, dispatches
   by route.
2. The asset bundle build — generate `editor_assets[]` from
   `assets/editor/` at kernel build time.
3. The map serialisation route — read box files and pack.
4. The TCP-imitation adapter — handles browser TCP expectations
   over the device's UDP transport.

## Related documents

- `docs/008-apps-overview.md` — the programming environment
  section.
- `/home/ritz/programs/sora/soramech/docs/003-editor.md` — the
  parent project's editor UI.

## Blocked by

303, 406, 407, 709.

## Blocks

804, 811.
