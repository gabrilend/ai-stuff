<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 007-read-the-input

Reads and checks `input/viewer-settings.lua` first thing (issue 005).

| Offers | Takes | Gives |
|---|---|---|
| `read(project_dir)` | project folder | the checked settings table |
| `check_settings(settings, source_name)` | | nothing; raises naming the first missing or wrong field |
| `REQUIRED_FIELDS` | | list of { name, kind ("whole"/"number"/"yes or no"/"colour"), min, max }: window_width, window_height, field_of_view_degrees, turn_degrees_per_second, window_resizable, edge_margin_pixels, edge_speed, background_colour, edge_colour, text_colour |
