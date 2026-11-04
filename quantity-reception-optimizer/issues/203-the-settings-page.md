# 203 — The settings page

## Current behavior

Nothing exists. Needs `105` (the settings file) and `202` (the extension).

## Intended behavior

**The context policy, and the other settings, editable from inside Firefox.**

The vision places it in "a menu accessed from the Extensions menu, just to the
left of the hamburger menu". In Firefox that is the puzzle-piece button: its
list shows each extension, and an extension that declares an options page gets
an entry there that opens it. This issue declares that page.

**The settings file in `input/` stays the single source.** The page asks the
host for the current settings (`settings_get`), shows them, and sends changes
back (`settings_put`); the host checks them with the same checks it uses on
load and writes the file. Firefox's own extension storage is not used for
settings, so there is never a question of which copy is right.

The page shows the context policy first and largest, since it is the setting
the vision names. Beneath it, the other tunable numbers, each with the comment
from the settings file as its label.

**A rejected change shows the host's reason** next to the field. Nothing is
half-saved.

## Suggested implementation steps

1. The host gains `settings_get` and `settings_put` handlers, and the settings
   module from `105` gains a writer that keeps each entry's comment.
2. `src/extension/` — the options page and its script, declared in the
   manifest.
3. Test: change the policy in the page, confirm the file changed, hover the
   same quantity, confirm the host's log shows the other falloff in use.

## Related

`docs/006-datapath-the-bridge.md` · `docs/008-open-questions.md` (3) · needs
`105`, `201`, `202` · blocks `205`
