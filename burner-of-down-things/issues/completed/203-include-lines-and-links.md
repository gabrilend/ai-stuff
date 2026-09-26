# 203 — Include lines and links

Finding which file includes which, and resolving the names
([004](../docs/004-datapath-the-survey.md), *resolving a link*).

## Current Behavior

Built as `src/028-include-lines.lua`. Two findings from real sources shaped it. LuaJIT's `gmatch` reads a leading `^` as a literal caret, so anchored patterns silently matched nothing (every C include in kiln was invisible); anchored patterns are now matched once per line with `match`, and tests/032 holds this. And pattern-matching every line was slow on millions of lines, so each scanner has plain keywords (`include`, `require`, …) and only lines holding one are matched.

## Intended Behavior

- One scanner per include style, named in the language table: each takes a
  file's text and returns the names it includes, with the kind (`require`,
  `include`, `import`, `source`). Scanners match whole lines by Lua patterns;
  commented-out lines in the language's line-comment form are skipped.
- Resolve (from-path, name, kind, set of all source paths): the candidate
  paths in 004's order; the first in the set wins; none gives the name as
  written with `inside = no`.

| Decision | What each path leads to |
|---|---|
| A C include in angle brackets | Recorded as outside without trying to resolve |
| A Lua name with dots | Dots become slashes, `.lua` and `/init.lua` tried |

## Suggested Implementation Steps

1. Scanners. **Test:** each style finds its names and ignores commented lines.
2. Resolve. **Test:** a fixture tree where the same name resolves relative to
   the including file first, then to the root.

## Blocked by

- 202
