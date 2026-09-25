# patch-notes-build.lua

Turns the cached patch pages into `notes.js` (`window.NOTES`) for the balance
history page. Fetches nothing.

| Function | Takes | Gives |
|----------|-------|-------|
| `plain(line)` | one line of wiki markup | plain text: icons and files dropped, links to their shown text, bold/italic/code marks removed, entities decoded, leftover templates and tags removed |
| `parse(text, version)` | a page's wikitext; its version (for subpages) | `{release, build, sections = {{heading, level, lines = {{text, depth}}}}}`; subpages spliced in, each `{{Patch object … text=…}}` as one line |
| `build()` | — | version → `{title, url, license, fetched, release, build, sections}` for every cached page |
| `write(notes, folder)` | the result of `build`; a folder | `folder/notes.js`, headed with its source and licence |

Command line: `luajit src/cli/patch-notes-build.lua [--dir DIR] <output folder>`
(`scripts/balance-history.sh` runs it when the cache exists).
