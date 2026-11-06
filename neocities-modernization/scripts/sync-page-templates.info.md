# sync-page-templates.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/sync-page-templates: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
sync-page-templates
Copy the authored page-copy templates into the ephemeral input/pages/ where the
HTML generator reads them.

General description (for a CEO): the explore pages' words are written by hand
and kept under version control in page-templates/. The input/ folder, by
contrast, is wiped and rebuilt from external sources on every sync and does NOT
carry these words -- so this little step puts the committed copy back in place
before the site is built. It is the reason a sync can no longer silently erase
the explore-page text (Issue 11-005): the words now have a canonical home, and
input/pages/ is just a regenerated copy of it.

Edit the canonical files in page-templates/. input/pages/ is OVERWRITTEN from
them on every build, so edits made directly in input/pages/ would be lost.

Usage:
  scripts/sync-page-templates [--dir PATH]
--dir PATH defaults to the hard-coded project root; pass it (as run.sh does) to be safe.

--help: print the header above and exit, before any work (libs/script-help.sh)
```
