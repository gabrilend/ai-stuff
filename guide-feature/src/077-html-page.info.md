# 077-html-page — info

The HTML page (issue 803), sent by the canvas server at `GET /` once 076 has
put the copied libraries in it. One file: HTML, CSS and its own script.

    http://HOST:PORT/#NAME:KEY            watch, with a key in the address
    http://HOST:PORT/                     sign in with a viewer's name and password
    http://HOST:PORT/#NAME:KEY:VERSION    that version only, drawn before the
                                          page finishes loading (screenshots)

- Asks `/session`, unlocks the session key, then holds
  `GET /canvas?after=N&session=ID` open, as `docs/canvas-protocol.md` says.
  A 403 (the session ended) starts a new one by itself.
- Reads the canvas exactly as `docs/canvas-protocol.md` says (`parse`).
  A canvas it cannot read is shown as the line and why, never guessed at.
- Draws each cell as a span: the voice's colour behind it, from
  `input/lua-window`'s colours and strengths (word 0.85 ... 0.25, sentence
  0.35 ... 0.15), kuvalu's colour for distill mode. Each changed letter fades
  in over 0.5 s. A colour change is a 0.6 s CSS transition.
- Lays the canvas out as `022`'s `viewer.layout` does: the largest letter
  size up to 32 px that fits, centred. Below 6 px it shows the too-small
  error, naming both sizes, and hides the grid.
- A password never leaves the page. The key is made from it
  (`pbkdf2Async`) and the password box is emptied at once.

| `GF.` | Meaning |
|---|---|
| `parse(bytes)` | a view, or an Error with `.line` |
| `changed(view, previous)` | as 022's `viewer.changed` |
| `paint(view, previous)` | each cell's `ch`, `background`, `new` |
| `layout(view, width, height, letter)` | as 022's `viewer.layout` |
| `unlock(key, hex, aad)`, `passwordKey(password, saltHex, rounds)` | the locks |
| `follow(start, get, show, report)` | a session, then each version |
| `start()` | the page in a browser |

Tests: `078-test-html-page.lua` runs `079-test-html-page.js` in node.
