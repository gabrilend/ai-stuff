# file-screenshot.info.md

Files one picture into `development-history/`, the project's record of
every picture it takes of itself, kept in order with the mistakes (the
owner's rule: no screenshot is a throwaway).

    scripts/file-screenshot [DIR] PICTURE NAME [--made-by TEXT]

## What it writes, for picture number NNN

| file | what it is |
|---|---|
| `NNN-NAME.png` (or the picture's own extension) | a copy of PICTURE; the original is left where it was |
| `NNN-NAME.info.md` | the notes: what made it (the commit, `--made-by`), what changed since the previous picture (source files new, changed or removed; config.lua lines before `-` and after `+`), and two sections for a person: what it shows, part by part, and the story so far |
| `NNN-NAME.fingerprint` | `md5<TAB>path` for every tracked file in `src/`, `libs/` (not vendored folders, except `libs/vulkan-compute/`), `scripts/` and `config.lua`, then a `== config.lua ==` line and config.lua's text: what the next picture compares with |

NNN is one more than the highest number already filed, three digits. NAME
takes letters, digits and dashes only; anything else is refused.

Test: `scripts/file-screenshot.test.sh`.
