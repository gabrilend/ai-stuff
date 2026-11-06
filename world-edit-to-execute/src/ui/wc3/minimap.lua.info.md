# minimap.lua

The minimap's conversions (issues 507a, 507d), used by the interface
(`hud.lua`). `minimap.new(extent, rect)` takes the map's ground in WC3
units (`x0, y0, x1, y1`) and the minimap's square on the screen
(`x, y, w, h`), and fits the map into it as WC3 fits a map that is not
square: one scale across and down, centred (`picture`).

- **`to_minimap(x, y)`**: a map point on the screen, north up.
- **`to_world(px, py)`**: back; a point off the picture is the nearest
  point of the map.
- **`inside(px, py)`**: on the minimap's square at all.
- **`view_box(quad)`**: the view's four ground corners (`{ x1, y1, ...
  x4, y4 }`) as a polygon on the minimap, cut to the picture; empty when
  none of it is on the map.
