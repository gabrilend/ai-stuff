<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 019-the-arch

The console's shape: one hump of an M. Outer and inner curves are parabolas meeting the base at the feet; the band (glass, the map display) lies between them, the dashboard surface beneath.

| Offers | Takes | Gives |
|---|---|---|
| `new(center_x, base_y, height, width_share, band_share)` | pixels and shares of height | a section: center_x, base_y, height, width, band |
| `shifted(section, steps)` | -1 / +1 | a neighbour's section (sharing a foot) |
| `at(section, across, up)` | arch units | window pixels |
| `in_interior(section, x, y)`, `in_band(section, x, y)` | a pixel | whether it is on the surface / the band |
| `interior_half_width(section, up)` | height in arch units | how far from the center the surface reaches there |
| `curve_points(section, steps)`, `interior_polygon(section, steps)` | | matching inner/outer curve points foot to foot; the surface outline |
