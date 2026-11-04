# validate-output.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/validate-output: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
validate-output -- counts the width of every line and checks every link in
the built site.

WHAT IT DOES (for a CEO): the site's poems are drawn inside fixed-width text
frames, so one character too many on a line pushes a wall out of place, and
a link to a page that was never written is a page-not-found for a reader.
This reads every page of a finished build, all processors at once, and
reports every line wider than the widest frame and every link that points
at nothing -- grouped by cause (content-warning boxes, web addresses,
progress bars, frames, ordinary text) so thousands of findings read as a
handful of problems to fix.  It changes nothing.  (Issue 9-006; owner:
"please write a character counting script and count every line".)

Usage:
  scripts/validate-output [--dir PATH] --jobs N [--output PATH] [--max-width N] [--report PATH]

  --dir PATH   project directory (default below)
  --jobs       how many pages-checking processes run at once (required; run.sh
               passes its --threads value, so one number governs the whole run)
  --output     the built site to check (default DIR/output)
  --max-width  widest allowed line inside a poem column, in visible
               characters, and the width every frame piece must be
               (default: config.lua layout.text_content_width + 4 -- a
               wall, a space, the text, a space, a wall: 84)
  --report     where the full report goes (default
               DIR/tmp/shared-memory/validate-output-report.txt)

Exit status: 0 when nothing is over-wide or broken, 1 otherwise.

--help: print the header above and exit, before any work (libs/script-help.sh)
```
