# reading-walk-pages.lua — info

The reading walk's map as linked web pages, and a one-stop-per-screen view for
small OLED displays (issue 065h). Plain HTML and one stylesheet; no scripts.

| | |
|---|---|
| `reading-walk-pages.lua <project>` | pages from the project's map (built first if missing) into `delta-version/tmp/shared-memory/reading-walk/<project>-pages/` |
| `--out=DIR` | write them there instead |
| `--map=FILE` | from a map kept elsewhere |
| `--workers=N` | worker processes (default: CPU count); one job per page |

## What is made

| File | Holds |
|---|---|
| `index.html` | the project, stop and file counts, files in reading order, a link to the first stop |
| `<file-with-dashes>.html` | one source file: every stop with its summary, description (marked when from a comment or missing), uses (each linking to the stop that makes it), recorded reasons, chapter, its code coloured by kind, and links to the stops before and after (across files) |
| `oled/<n>.html` | stop n alone: black background, only text lit, name and summary large, back and next links (access keys b and n) |
| `walk.css` | the one stylesheet; colours as tokens, redefined for a dark preference; narrow screens stack the file list above the stop |

Tests: `test-reading-walk.sh` (pages section).
