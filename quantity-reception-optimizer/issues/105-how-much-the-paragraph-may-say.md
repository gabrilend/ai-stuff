# 105 — How much the paragraph may say

## Current behavior

Nothing exists. Depends on `104`.

## Intended behavior

**The context policy, and the settings file it lives in.**

The vision: the reasoning is "either encouraged or discouraged from embracing
context, according to a config file option". This issue makes that option real
on the host side: it lives in a settings file in `input/` (the house rule: a
program's first act is reading `input/`), and it chooses the falloff
parameters `104` uses.

- *encouraged* — wide falloffs; most of the paragraph keeps weight
- *discouraged* — narrow falloffs; little but the quantity's own sentence does

Whether this is two named settings or a number between them is open question 3
in `docs/008`. The file is designed so either answer fits: the policy names a
point, and the falloff parameters for that point are in the same file, next to
it, where they can be tuned.

**The settings file is the one home for every tunable number in the project**
— falloff widths, later the ComfyUI address and image size. Other
issues add their entries here rather than starting their own files. A setting
the code reads and the file does not have is an error naming it; there are no
built-in defaults to fall back to.

The settings page (`203`) edits this file through the host; nothing else
writes it.

## Suggested implementation steps

1. `input/settings.lua` — the settings file, a Lua table, each entry commented
   with what it changes and what the reader will notice.
2. `src/` — the settings module: load, check every required key is present and
   of the right type, hand out values. Writing back is added in `203`.
3. Connect it to `104`: the policy picks the falloff parameters.
4. Tests: a file missing a key is refused with the key's name; the two
   policies, applied to the same fixture, give spectra where *encouraged* is
   everywhere at least as high as *discouraged*.

## Related

`docs/002-datapath-the-hover.md` · `docs/008-open-questions.md` (3) · needs
`104` · blocks `106`, `203`, `303`
