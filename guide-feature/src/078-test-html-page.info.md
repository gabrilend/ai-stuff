# 078-test-html-page — info

Tests the HTML page and its way in (issue 803) against the real canvas
server, with this machine counted as outside the house.

    luajit src/078-test-html-page.lua --dir ROOT

- **The page**: `GET /` is the built page, text/html. Its policy lets it
  load nothing from elsewhere. All ten library files are in it.
- **Never plain** outside the four machines: 403 on every canvas route.
- **add-viewer**:
  - a key viewer, given the address to bookmark;
  - a password viewer, the password read from standard input;
  - the file is mode 600 and outside the project, and holds no password;
  - two different passwords, a name used twice and a bad name are refused.
- **A session**:
  - the session key comes locked with the viewer's key;
  - each canvas route sends the server's bytes, locked, in either order of
    fields;
  - 204 when nothing is newer;
  - a fresh nonce each time;
  - one session's canvas does not unlock in another's;
  - a password's salt and rounds are sent, and only the right password
    unlocks;
  - a session ends after `session-seconds` unused;
  - `max-sessions` drops the one used longest ago.
- **Refused**: twelve malformed queries (404), a POST (405), and a viewers
  file with a bad line, a name twice or a short key (500, with the log
  naming the line). The file is read again once put right.
- **In node**, when node is installed: `079-test-html-page.js`, given the
  server's port and 46 canvases of this file's own, each with 022's answer.
  Without node the JavaScript is not run, and the output says so (SKIP).
- **The copies**:
  - each file is as its `.upstream` note's hash says;
  - `refresh-vendored` leaves them be;
  - the log holds no key;
  - the goodbye counts sessions and refusals.
