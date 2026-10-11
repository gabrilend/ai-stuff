<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 001-read-the-input

Reads `input/game-settings.lua` first thing and checks it.

| Offers | Takes | Gives |
|---|---|---|
| `read(project_dir)` | project folder (string) | the checked settings table; raises an error naming the first missing or wrong field |
| `check_settings(settings, source_name)` | a table, a name for messages | nothing; raises on the first problem (missing field, wrong kind, out-of-range cap, plane outside the depth band, hub outside the edge, negative fold) |
| `REQUIRED_FIELDS` | | list of { name, kind } — kind "whole" or "number"; includes team_size (1..4) and seat (1..team_size) |
