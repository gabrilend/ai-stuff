# 079-test-html-page — info

The page's own JavaScript, run in node (18 or newer) by
`078-test-html-page.lua`, against the server 078 started. It is not run
on its own; its one argument is 078's JSON file.

- The page's script, from the page as the server sends it, run with no
  browser. It asks no other address for anything.
- **The parser**:
  - the six shared test canvases, line for line with their `.expected`
    files, changed cells included;
  - 078's 46 canvases, against 022's answer for each, refused ones on the
    same line.
- **The locks**:
  - GCM test cases 13 to 15 through the page's `unlock`;
  - case 16 through the copied noble-ciphers;
  - a changed tag, and another session's words, do not unlock;
  - RFC 7914's PBKDF2 examples.
- **A session** against the real server:
  - the newest version, then a new one written as the blitter does, drawn
    within a second;
  - a 403 begins a new session by itself;
  - a password viewer, after which the password is forgotten;
  - a wrong password, an unknown viewer, and a key viewer asked for a
    password;
  - one version fetched synchronously.
- **What it paints**: the colour of each kind and age of mark, kuvalu's,
  none; which letters are new; and layout, as 022's `viewer.layout`.
- **A pretend browser** (a few objects standing in for the DOM) runs
  `start()`:
  - the grid of spans, row by row, with their colours and fades;
  - the font size and centring;
  - a window too small, which shows the error and hides the grid;
  - `#NAME:KEY:2` drawn before anything else can run;
  - the sign-in form, with the password box emptied at once;
  - a wrong password, which brings the form back;
  - a bad address.

Real pixels in Firefox are the owner's check
(`issues/completed/803-the-html-page.md`).
