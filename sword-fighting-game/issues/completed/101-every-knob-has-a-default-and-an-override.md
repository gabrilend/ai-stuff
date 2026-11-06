# 101 — Every Knob Has A Default And An Override

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | none |
| Blocks | 102, 103, 201, 202 (and through them, everything) |
| Files | `src/001-config.def.lua`, `src/002-util.lua`, `config.lua` (optional, project root) |
| Reads | `docs/architecture.md` (configuration in the suckless manner) |

## Current behavior

Built. `src/001-config.def.lua` holds every knob in sections (tick, field,
body, stamina, sword, swings, hits, ranged, mind, round, campaign, view, mods,
keys, buttons), aligned with a comment per line. `src/002-util.lua` loads it
and lays an optional root `config.lua` over it with a merge that stops on an
unknown knob or a wrong type, naming the dotted path; lists (keys, mods) are
replaced whole. The same file holds the stop-with-a-message helper, angle and
plain-number vector arithmetic, a sandboxed data-file loader and a folder
lister. Tested in tests/031-the-spine.lua.

## Intended behavior

One file holds the default of every knob in the game, laid out the way dwm's
config.def.h is: an aligned table, one knob per line, a short comment saying
what the number means and in what unit. Knobs are grouped into sections
(tick, field, body, stamina, sword, hits, ranged, round, campaign, view, keys).

A person changes a knob by writing a config.lua at the project root that
returns a table of the same shape with only the knobs they want different. The
loader starts from the defaults and lays the overrides over them. An override
whose name is not a default is an **error naming the knob**, not a silent
no-op: a typo must never quietly do nothing.

Key bindings are a list of rows { key, action, argument } as in dwm's keys[];
the front desk indexes them by key name once at start-up.

A small utility file beside it holds what every other file needs: `die` (stop
with "sword-fighting-game: <message>"), clamp, lerp, sign, 2D vector helpers
on plain numbers (no vector objects, so the tick allocates nothing), angle
wrapping, a deep copy, and a table merge that refuses unknown keys.

## Suggested implementation steps

1. Write the defaults table with every section the roadmap needs. Values not
   yet used still get their row, so the shape is visible from day one.
2. Write the merge-with-refusal in the utility file; the config loader is
   "defaults, then merge config.lua if the file exists". A missing config.lua
   is the ordinary case, not a fallback: the defaults are the design.
3. Test: an override changes one knob and leaves the rest; an unknown knob
   stops the load with its dotted name in the message.

## Related documents and tools

- `docs/balance-updates.md` — every change to a default is logged there, with
  why.
