# 803 — The HTML page

phase 8, viewers for the desk and the browser

## Current behavior

The canvas server answers plain text (204).

## Intended behavior

A single HTML file served at `GET /` by the canvas server, with inline
JavaScript that holds `GET /canvas?after=N` open, parses the canvas text in
JavaScript straight from `docs/canvas-protocol.md`, and draws the grid with
CSS colours for marks and a transition for changes.

This is the remote-access viewer. Under the owner's router rules only the
four machines can reach the canvas server, so for now it is used from kuvalu
or one of the voices (`docs/network.md`).

## Suggested implementation steps

1. The key from the address after `#`, the AES-256-GCM decryptor (tested
   against the standard's published example values, and against a canvas
   the server encrypted), then the page and its parser, checked against the viewer-side reader's test
   canvases (202).
2. Check in Firefox with screenshots.

## Related documents

- `docs/canvas-protocol.md`
- `docs/datapath-viewers.md`

## Open questions

- Answered: the key is read from after the `#` in the page's address, and
  the page decrypts with its own JavaScript AES-256-GCM, because Web Crypto
  is missing on plain HTTP. It is noble-ciphers, copied in. Without a key in
  the address, the page asks for the viewer's password. The password never
  leaves the page: the page derives the viewer's key from it, slowly, and
  unlocks the session key the server sends.

## Blocked by

204.

## Blocks

804.
