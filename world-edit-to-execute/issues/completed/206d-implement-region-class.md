# Issue 206d: Implement Region Class

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 206a-create-gameobjects-module-structure, 203-parse-war3map-w3r
**Parent Issue:** 206-design-game-object-types

---

## Current Behavior

Region parser (src/parsers/w3r.lua) returns plain tables. No Region class exists
to provide bounds checking, weather detection, or consistent API.

---

## Intended Behavior

A Region class that wraps parsed region data with:
- Bounds access and geometric queries
- Weather and ambient sound detection
- Center and size calculations
- Point containment testing

```lua
local gameobjects = require("gameobjects")
local region = gameobjects.Region.new(parsed_region)

print(region.name)               -- "spawn_area"
print(region:contains_point(x, y)) -- true/false
print(region:get_center())       -- { x = 100, y = 200 }
print(region:has_weather())      -- true
```

---

## Suggested Implementation Steps

1. **Create Region class**
   ```lua
   -- src/gameobjects/region.lua
   local Region = {}
   Region.__index = Region

   function Region.new(parsed)
       return setmetatable({
           name = parsed.name,
           creation_id = parsed.creation_number,
           bounds = {
               left = parsed.bounds.left,
               bottom = parsed.bounds.bottom,
               right = parsed.bounds.right,
               top = parsed.bounds.top,
           },
           weather = parsed.weather,
           ambient_sound = parsed.ambient_sound,
           color = parsed.color,
       }, Region)
   end
   ```

2. **Implement geometric methods**
   ```lua
   function Region:get_center()
       return {
           x = (self.bounds.left + self.bounds.right) / 2,
           y = (self.bounds.bottom + self.bounds.top) / 2,
       }
   end

   function Region:get_size()
       return {
           width = self.bounds.right - self.bounds.left,
           height = self.bounds.top - self.bounds.bottom,
       }
   end

   function Region:contains_point(x, y)
       return x >= self.bounds.left and x <= self.bounds.right
          and y >= self.bounds.bottom and y <= self.bounds.top
   end

   function Region:get_area()
       local size = self:get_size()
       return size.width * size.height
   end
   ```

3. **Implement feature detection methods**
   ```lua
   function Region:has_weather()
       return self.weather ~= nil and self.weather ~= ""
   end

   function Region:has_ambient_sound()
       return self.ambient_sound ~= nil and self.ambient_sound ~= ""
   end

   function Region:get_color()
       if self.color then
           return {
               r = self.color.red or 255,
               g = self.color.green or 255,
               b = self.color.blue or 255,
           }
       end
       return { r = 255, g = 255, b = 255 }
   end
   ```

4. **Add __tostring metamethod**
   ```lua
   function Region:__tostring()
       local size = self:get_size()
       return string.format("Region<%s %.0fx%.0f>",
           self.name or "unnamed", size.width, size.height)
   end
   ```

5. **Update init.lua and create tests**

---

## Technical Notes

### Region Bounds

Regions use WC3 world coordinates:
- left/right are X coordinates
- bottom/top are Y coordinates
- Z is implicit (regions are 2D rectangles)

### Weather Effects

Weather strings are 4-char codes:
```lua
"RAhr" = "Ashenvale Rain (Heavy)"
"SNls" = "Lordaeron Snow (Light)"
"FDwh" = "White Fog"
```

### Parser Output Fields

From src/parsers/w3r.lua:
```lua
{
    name = "spawn_area",
    creation_number = 1,
    bounds = {
        left = -512.0,
        bottom = -512.0,
        right = 512.0,
        top = 512.0,
    },
    weather = "RAhr",        -- nil if none
    ambient_sound = "loop1", -- nil if none
    color = { red, green, blue },
}
```

---

## Related Documents

- issues/203-parse-war3map-w3r.md (parser implementation)
- src/parsers/w3r.lua (input format)
- issues/206-design-game-object-types.md (parent)

---

## Acceptance Criteria

- [x] Region class with constructor
- [x] get_center() method
- [x] get_size() method
- [x] contains_point() method
- [x] get_area() method
- [x] has_weather() method
- [x] has_ambient_sound() method
- [x] get_color() method
- [x] __tostring metamethod
- [x] Unit tests for Region class
- [x] init.lua exports Region

---

## Notes

Regions are primarily used for triggers (detecting when units enter/leave)
and as waygate destinations. The contains_point() method will be essential
for trigger evaluation in Phase 3.

---

## Implementation Notes

*Completed 2025-12-22*

### Constructor

The Region.new() constructor copies all fields from parser output:
- Core: name, creation_number
- Bounds: {left, bottom, right, top} (defensive copy)
- Weather: weather_id (4-char code), weather (friendly name)
- Sound: ambient_sound reference
- Color: {r, g, b, a} (defensive copy, defaults to white 255,255,255,255)

### Methods Implemented

| Method | Description |
|--------|-------------|
| `get_center()` | Returns {x, y} center point |
| `get_size()` | Returns {width, height} dimensions |
| `get_area()` | Returns width * height |
| `contains_point(x, y)` | Inclusive bounds check |
| `overlaps_region(other)` | Check if two regions overlap |
| `has_weather()` | weather_id not nil/empty |
| `get_weather_id()` | Returns 4-char weather code |
| `get_weather_name()` | Returns friendly weather name |
| `has_ambient_sound()` | ambient_sound not nil/empty |
| `get_ambient_sound()` | Returns sound reference |
| `get_color()` | Returns {r, g, b} (no alpha) |
| `get_color_rgba()` | Returns {r, g, b, a} |

### Bonus Method

Added `overlaps_region(other)` for checking if two regions overlap - useful
for trigger logic and spatial queries.

### __tostring

Shows weather/sound indicators:
- `Region<spawn 100x100>` - plain region
- `Region<rain_zone 100x100 [weather]>` - has weather
- `Region<ambient 100x100 [sound]>` - has sound
- `Region<full 100x100 [weather+sound]>` - has both

### Tests Added

13 new tests added to test_gameobjects.lua (total now 144):
- Constructor copies all fields
- Default values when fields missing
- get_center() with positive and negative bounds
- get_size()
- get_area()
- contains_point() inside, edges, outside
- overlaps_region() with overlapping and non-overlapping
- has_weather() with nil, empty, valid
- has_ambient_sound() with nil, empty, valid
- get_color() and get_color_rgba()
- Bounds table copied (no external mutation)
- __tostring shows weather/sound indicators
