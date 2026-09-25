# route-b-fetch.lua

Fetches the Warcraft III wiki's unit, building and item pages from Liquipedia,
once and slowly, into `wc3-installs/external-values/` (a link beside the
installs, ignored by git). Route B of the stock values cross-check compares
their infobox numbers with the game's own tables. It never fetches a page
that is already cached.

- **Phases:**
  - `discover`: lists the pages that use each infobox template (one request
    per template, continued past 500).
  - `current`: fetches today's revision, 50 pages per request.
  - `old <list file>`: fetches each listed page as it stood under 1.29.2 (the
    last revision before 2018-08-08, when 1.30 came out), one page per
    request, since the API allows no more for old revisions.
  - `status`: shows the counts and fetches nothing.
- **Spacing:** one request every 10 seconds, give or take 1–2 seconds at
  random. The spacing holds across runs, because the last request's time is
  kept in `.last_request`.
- **Identity:** the User-Agent names the tool only, never the person.
- **Cache:** `pages.<template>.txt` holds the discovered titles.
  `current/` and `old/` each hold `<name>.wikitext` plus `<name>.meta` (the
  title, revision, timestamp and fetch time, tab-separated). A page with no
  revision before the cutoff gets an empty text and "none before …" in its
  meta.
- **Licence:** the text is Liquipedia's (CC BY-SA 3.0). It is used only to
  check Route A: never to fill a table, and never committed.

Usage: `luajit src/cli/route-b-fetch.lua [--dir DIR] discover | current | old <list> | status`

Issue: `issues/112e-route-b-published-values-cross-check.md`
