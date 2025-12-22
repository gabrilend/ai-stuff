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

- [ ] Region class with constructor
- [ ] get_center() method
- [ ] get_size() method
- [ ] contains_point() method
- [ ] get_area() method
- [ ] has_weather() method
- [ ] has_ambient_sound() method
- [ ] get_color() method
- [ ] __tostring metamethod
- [ ] Unit tests for Region class
- [ ] init.lua exports Region

---

## Notes

Regions are primarily used for triggers (detecting when units enter/leave)
and as waygate destinations. The contains_point() method will be essential
for trigger evaluation in Phase 3.
