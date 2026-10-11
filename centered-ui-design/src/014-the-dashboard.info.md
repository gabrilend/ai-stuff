<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 014-the-dashboard

The arch console (019) as four window-sized layers: face (brushed metal surface, cut windows, painted buttons, engraved labels, gold band edges, allies' arches dimmed), dials (paper discs beneath the windows, turned by the game, each clipped to its window), glass (how windows bend their dials; the band marked as painted glass), band (where each band pixel paints on the map). A ring-ordered row of arches slides with the chair; a clip shows your own and the very edge of the next. Only your own buttons answer. Layout is data, in arch units.

| Offers | Takes | Gives |
|---|---|---|
| `new(width, height, team_size, seat)` | | dashboard (with its `section`) |
| `draw(dashboard, state, seconds)` | state: month, weekday, day, fps, frame_ms, unit_count, cap, named_text, someone_named, seat_colors, delivered (four counts) | redraws the layers |
| `set_chair(dashboard, offset)` | arches slid along the row | moves your arch and what is shown |
| `button_under(dashboard, x, y, someone_named)` | a pixel | the button's verb or nil |
| `covers(dashboard, x, y)` | a pixel | whether it is on your arch (surface or band) |
| `set_pointer(...)`, `flash_name_someone(dashboard)` | | hover/press lighting; the "name someone first" reminder |
| `ORDER_BUTTONS`, `SETTINGS_BUTTONS`, `WINDOWS`, `LABELS`, `CALENDAR_CENTER`, `ARCH_*_SHARE`, `NEIGHBOUR_SHOWN`, `MONTHS`, `MONTH_DAYS`, `WEEKDAYS` | | layout and calendar data |
