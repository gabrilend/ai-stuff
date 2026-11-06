# Project File Server

A Lua utility that writes a plain HTML page for browsing a folder tree from a
browser. Folders open and close with the browser's own `<details>`/`<summary>`
elements, and every name is a `file://` link that opens in the file manager.
The page has no CSS and no JavaScript (issue 007).

## Overview

The page holds, top to bottom:

- **Statistics**: file and folder counts, total size, and the ten most common
  file extensions, in a `<pre>` block.
- **Quick links**: `file://` links to the usual programming folders.
- **Directory tree**: three levels of folders and files under the scanned
  folder, with sizes in parentheses. A folder with something in it is a
  `<details>` element. An empty folder is a plain link. Hidden files and
  folders (names starting with `.`) are left out.

To search the page, use the browser's own find (Ctrl+F).

## Usage

```bash
# Scan the default folder (ai-stuff); the page goes into that folder
project-file-server

# Scan another folder; the page goes into it
project-file-server /path/to/projects

# Name the output file, as a second word or with -o
project-file-server /path/to/projects /tmp/output.html
project-file-server /path/to/projects -o /tmp/output.html

# Interactive menu (generate, serve over HTTP, open, change settings)
project-file-server -I

project-file-server -h
```

The runner refuses an option it does not know and a folder that does not
exist. It loads the library from beside itself, following a symlink to the
runner, so any folder can be scanned, not only the monorepo.

## Names are data

Names come from the disk, and a folder can be called anything. The library
treats every name as data:

- **Shell:** each path is passed to `find`, `du` and `stat` in single quotes.
  A folder called `$(...)` or `` `...` `` is listed, not run.
- **Page:** each name is HTML-escaped. A file called `<script>.md` shows as
  that text and adds no script to the page.
- **Links:** each `file://` link is percent-encoded. Spaces, `#`, `&` and
  quotes in a name don't break the link.

## Architecture

```
project-file-server (runner script)
         │
         ▼
scripts/libs/project-file-server.lua (library, LuaJIT)
         │
         ├── shell_quote / html_escape / file_url → names made safe
         ├── scan_directory_bash()                → three levels of folders and files
         ├── get_project_analysis()               → counts, size, file types
         ├── generate_tree_html()                 → <details> tree
         └── generate_html_page()                 → the whole page
         │
         ▼
    [project-file-server.html]
```

## Dependencies

- **LuaJIT**
- **Shell tools**: `find`, `du`, `stat`, `wc`, `sed`, `sort`, `uniq`
- For the interactive menu's HTTP server only: `python3`

## Tests

`tests/test-project-file-server.sh [scripts-dir]` scans a scratch tree that
contains hostile names. It then checks the page:

- no `<style>`, `<script>`, `style=`, `on…=` or `javascript:` anywhere;
- every name escaped;
- no hidden command run;
- folders as `<details>` elements;
- links percent-encoded;
- the three-level depth limit.

It also checks the runner's arguments.

## Origin

The file server started in the **neocities-modernization** project (issue
2-015) as a local file-browsing page. It moved to the shared scripts during
project cleanup (issue 8-009) on 2025-12-17. Its CSS and JavaScript were
removed in issue 007.

## Related Documents

- `scripts/issues/completed/007-remove-css-and-javascript-from-file-server.md`
- `neocities-modernization/issues/completed/2-015-implement-local-project-file-server.md`
- `neocities-modernization/issues/completed/8-009-project-cleanup-and-organization.md`
