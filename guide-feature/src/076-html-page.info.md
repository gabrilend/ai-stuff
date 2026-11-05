# 076-html-page — info

The HTML page's server side (issue 803): the page, the viewers, the sessions.

    scripts/add-viewer [ROOT] NAME [--password] [--address HOST]
    luajit src/076-html-page.lua --dir ROOT --add-viewer NAME [--password] [--address HOST]

- **The page**: `build(root)` puts the ten copied noble files
  (`libs/noble-ciphers/`, `libs/noble-hashes/`) into `077-html-page.html`
  where its `/*NOBLE*/` line is. Each file is wrapped in a function of its
  own, with a small `nobleRequire`. Their source-map lines are left out.
  The server builds it once, at start.
- **The viewers file** (`viewers-file` in `input/canvas-server`, outside the
  project, mode 600):

      viewer: NAME key KEY                    a key in the address (64 hex)
      viewer: NAME password SALT ROUNDS KEY   KEY = PBKDF2(password, SALT, ROUNDS)

  It is read again at every sign-in. A wrong line is an error naming it.
- **Sessions**: `GET /session?viewer=NAME` makes a fresh 32-byte key and a
  32-hex id. The answer:

      session: ID
      viewer: NAME
      kind: key | password
      salt: HEX | -
      rounds: N | -
      key: HEX        the session key sealed with the viewer's key, words "guide-feature session ID"

  A session ends after `session-seconds` unused. At most `max-sessions` are
  open; the one used longest ago is dropped.
- **The canvas in a session**: hex of the canvas sealed with the session
  key, words `guide-feature canvas ID`, then a newline.

| Name | Meaning |
|---|---|
| `build(root)` | the page's HTML |
| `NOBLE` | the library files the page holds: name, and path in `libs/` |
| `viewers_path(setting, root)` | the file's path (`~/` is home), or nil and why (inside the project) |
| `read_viewers(path)` | name -> `{ kind, key, salt, rounds }`, or nil and the line that is wrong |
| `viewer_line(name, password, rounds)` | a new viewer's line, and its key |
| `add_viewer(path, name, password, rounds)` | appends one; refuses a name already there |
| `sessions({ seconds, most, now })` | `:start(name, viewer)` -> id, answer; `:find(id)` |
| `lock_canvas(session, id, text)` | the body a canvas route sends in a session |

Tests: `078-test-html-page.lua`.
