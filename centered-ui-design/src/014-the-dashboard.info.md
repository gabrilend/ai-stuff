<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 014-the-dashboard

The dashboard as three window-sized layers: face (brushed metal, cut windows, painted buttons, engraved labels), dials (paper discs under the windows, turned by the game, each clipped to its own window), glass (how each window's glass bends what is beneath). Only buttons answer the mouse.

| Offers | Takes | Gives |
|---|---|---|
| `new(width, height, radius_fraction)` | | dashboard |
| `draw(dashboard, state, seconds)` | state: month, weekday, day, fps, frame_ms, unit_count, cap, named_text, someone_named, settings_hint | redraws the layers |
| `button_under(dashboard, x, y, someone_named)` | a pixel | the button's verb or nil |
| `covers(dashboard, x, y)` | a pixel | whether it is on the dashboard |
| `set_pointer(...)`, `flash_name_someone(dashboard)` | | hover/press lighting; the "name someone first" reminder |
| `ORDER_BUTTONS`, `SETTINGS_BUTTONS`, `MONTHS`, `MONTH_DAYS`, `WEEKDAYS` | | layout and calendar data |
