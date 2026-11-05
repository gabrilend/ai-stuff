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

## Decisions (2026-11-05; each the owner's to overturn)

1. **Inline JavaScript, as this issue asks.** The issue's words win over
   the general preference for pages without JavaScript. The page's own
   script is small: a parser, a session, a draw. The two copied libraries
   are most of the 126 KB.
2. **noble-ciphers 1.3.0 and noble-hashes 1.8.0, from the npm registry.**
   Each tarball was checked against the registry's published integrity
   before use. Only the files the page needs were copied (4 and 8), unchanged,
   into `libs/noble-ciphers/` and `libs/noble-hashes/`. Their notes give the
   source, version, integrity and each file's hash. The last 1.x versions
   were chosen because their files are CommonJS: the server puts each in a
   function of its own with a ten-line `require`, so no bundler is needed.
   2.x is modules only. `scripts/refresh-vendored` names them and leaves
   them be. A refresh is by hand.
3. **The server locks with its own AES-256-GCM, SHA-256 and PBKDF2 in plain
   LuaJIT** (`src/074-crypto.lua`), checked against each standard's
   published examples. The alternative was OpenSSL's libcrypto through the
   FFI, as rmail does in C. That would be one more outside library for the
   one program reachable from outside, and nothing outside was to be added
   without asking. Its AES looks up tables, which another program on kuvalu
   could time. If the owner prefers libcrypto, only 074 changes.
4. **The password becomes a key by PBKDF2-HMAC-SHA256, 600,000 rounds**
   (`password-rounds`, OWASP's 2023 advice). noble-hashes and 074 both
   have it, and both are checked against RFC 7914. A desktop browser takes
   about 3 s and a phone longer. The page says it is slow on purpose.
   scrypt or Argon2 would cost a guesser more memory, but this project has
   no Lua copy of either.
5. **Every viewer has a key, and every page a session.** The address
   carries `#NAME:KEY` (64 hex digits). The name says which viewer, and
   never reaches the server through the fragment. A password viewer gives
   a name and password in the page's form. Either way the page asks
   `/session?viewer=NAME` and unlocks the session key, as `docs/network.md`
   asks for passwords, and uses one path for both.
6. **The viewers file is outside the project** (`viewers-file`, default
   `~/.config/guide-feature/viewers`, made mode 600), like every key file,
   and is read again at each sign-in, so `scripts/add-viewer` needs no
   restart.
7. **What travels**: hex of nonce, ciphertext and tag, as text. A
   synchronous request (for `#NAME:KEY:VERSION`) can read it, and it costs
   twice the bytes of a small canvas. The additional data binds each seal to
   its session (`guide-feature session ID`, `guide-feature canvas ID`).
8. **Sessions are kept in memory, at most `max-sessions` (64), each ending
   after `session-seconds` (3600) unused**; a full table drops the one used
   longest ago. A page meeting a 403 starts a new session by itself. This is
   the server's only state, and nothing a request sends is written anywhere.
9. **Plain text only to the four machines** (`send-plain = "local"`).
   The desktop viewers and any tool on the four machines keep reading plain
   text. Elsewhere a canvas route without a session is 403, saying to open
   the page. `everyone` keeps the old behaviour (026 uses it). `nobody`
   locks it for everyone.
10. **The page's look follows the Lua window**: the same three voice
    colours, kuvalu's, the background, and the word and sentence strengths
    by age. A cell's colour change is a 0.6 s CSS transition, and each changed
    letter fades in over 0.5 s. It is laid out as `viewer.layout` (205)
    does, up to 32 px a letter, and below 6 px it shows the too-small error.
11. **`#NAME:KEY:VERSION` draws one version before the page finishes
    loading**, with a synchronous request, so `firefox --headless
    --screenshot` (which shoots at the load event) shows it. The phase 8
    demo uses it.
12. **A strict policy on the page** (`Content-Security-Policy`): its own
    script and style, requests to this server only, no forms elsewhere, no
    framing; and no referrer.
13. **The page's JavaScript is tested in node** (078 runs
    `079-test-html-page.js`), with a few objects standing in for the DOM so
    `start()` runs too. Without node, those checks are skipped and the test
    says so. Firefox is the real check (below).
14. **The phase 2 demo writes the new settings too**, since settings have
    no defaults: its readers are on this machine, so `send-plain = "local"`,
    and its viewers file sits beside its throwaway project, never inside.

## What was built (2026-11-05)

- `src/074-crypto.lua`, `src/076-html-page.lua`, `src/077-html-page.html`,
  `scripts/add-viewer`, and the new settings in `input/canvas-server`. The
  canvas server (`025`) now serves the page and sessions and locks each
  canvas.
- `libs/noble-ciphers/`, `libs/noble-hashes/` and their `.upstream` notes;
  `scripts/refresh-vendored` knows a registry copy.
- `src/075-test-crypto.lua` (34 checks), `src/078-test-html-page.lua` with
  `src/079-test-html-page.js` (97 checks). They cover:
  - the GCM test cases;
  - RFC 7914;
  - the six shared test canvases, plus 46 more against the Lua reader;
  - a whole session against the real server;
  - the page in a pretend browser.
- Every deliberate break is caught: 20 in the crypto, 45 in the server and
  the page. Two that were not caught showed dead or redundant code, now
  removed.
- `docs/canvas-protocol.md` ("Locked, in a session"), `docs/network.md`,
  `docs/datapath-viewers.md`, `docs/vendored-code.md`, `libs/README`.

## Needs the owner's machine

- **A look in Firefox** at the real page, which this build could not do:
  there is no browser here, and none was downloaded. The pretend browser
  checks what the script does to the page. It cannot show pixels, fonts,
  the transitions, or the password prompt in use. Steps on kuvalu:
  `scripts/add-viewer me`, then open the printed address, and
  `firefox --headless --screenshot` it (the phase 8 demo does this).
- **node on kuvalu**, or 078 skips the page's own checks (it says so).
- The router's forwarded port, and `add-viewer --address` with the public
  address for a viewer outside the house.
- The page's colours and timings tuned by eye.
