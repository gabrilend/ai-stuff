# patch-notes-fetch.lua

Fetches Liquipedia's Warcraft III patch pages for the versions the project
doesn't read, once, into `wc3-installs/external-notes/` (a link beside the
installs, ignored by git). Never fetches what's cached; `--list` shows the
state without fetching.

- **Requests:** MediaWiki API (`action=query`, `prop=revisions`), up to 50
  titles per request, compressed, at least 30 seconds apart across runs (the
  last request's time is kept in the cache). The User-Agent names the tool
  only; nothing about the person running it.
- **Pages:** `"Patch <version>"` for each version in the script's list
  (redirects followed: "Patch 1.22a" is the wiki's "Patch 1.22"); subpages a
  page includes with `{{/human}}` are fetched the same way.
- **Cache:** `<version>.wikitext`, `<version>.sub.<name>.wikitext`,
  `.missing` markers for titles with no page, and `sources.tsv`: version,
  page title, URL, licence (CC BY-SA 3.0), fetch time.
