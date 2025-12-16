# Issue 206: Design Game Object Types

**Phase:** 2 - Data Model
**Type:** Architecture
**Priority:** High
**Dependencies:** 201, 202, 203, 204, 205 (parser outputs inform type design)

---

## Current Behavior

Each parser returns ad-hoc Lua tables. No unified type system exists for
game objects. Unit, Doodad, Region, Camera, and Sound are all represented
as plain tables with inconsistent structures.

---

## Intended Behavior

A unified type system with abstract classes for all game objects:
- **Doodad** - Trees, destructibles, decorative objects
- **Unit** - Units, buildings, heroes, items
- **Region** - Trigger areas, waygate destinations
- **Camera** - Cinematic and gameplay cameras
- **Sound** - Sound definitions and ambient loops

Each type provides:
- Consistent API for accessing properties
- Type-specific methods
- Serialization support
- Clear separation from parser output

---

## Suggested Implementation Steps

1. **Create game object module structure**
   ```
   src/gameobjects/
   ├── init.lua       (module exports)
   ├── doodad.lua
   ├── unit.lua
   ├── region.lua
   ├── camera.lua
   └── sound.lua
   ```

2. **Implement Doodad class**
   ```lua
   -- src/gameobjects/doodad.lua
   local Doodad = {}
   Doodad.__index = Doodad

   function Doodad.new(parsed)
       return setmetatable({
           type_id = parsed.id,
           variation = parsed.variation,
           position = {
               x = parsed.position.x,
               y = parsed.position.y,
               z = parsed.position.z,
           },
           angle = parsed.angle,
           scale = {
               x = parsed.scale.x,
               y = parsed.scale.y,
               z = parsed.scale.z,
           },
           flags = parsed.flags,
           life = parsed.life,
           creation_id = parsed.creation_number,
           -- Runtime state (nil until game starts)
           current_life = nil,
           destroyed = false,
       }, Doodad)
   end

   function Doodad:is_visible()
       return self.flags >= 1
   end

   function Doodad:is_solid()
       return self.flags >= 2
   end

   function Doodad:get_max_life()
       return self.life
   end

   return Doodad
   ```

3. **Implement Unit class**
   ```lua
   -- src/gameobjects/unit.lua
   local Unit = {}
   Unit.__index = Unit

   function Unit.new(parsed)
       local unit = setmetatable({
           type_id = parsed.id,
           variation = parsed.variation,
           position = {
               x = parsed.position.x,
               y = parsed.position.y,
               z = parsed.position.z,
           },
           angle = parsed.angle,
           scale = {
               x = parsed.scale.x,
               y = parsed.scale.y,
               z = parsed.scale.z,
           },
           player = parsed.player,
           base_hp = parsed.hp,         -- -1 = default
           base_mp = parsed.mp,         -- -1 = default
           item_drops = parsed.item_drops or {},
           abilities = parsed.abilities or {},
           hero_data = parsed.hero_data,
           random_unit = parsed.random_unit,
           waygate_dest = parsed.waygate_dest,
           creation_id = parsed.creation_number,
           -- Runtime state
           current_hp = nil,
           current_mp = nil,
           is_alive = true,
       }, Unit)

       return unit
   end

   function Unit:is_hero()
       return self.hero_data ~= nil
   end

   function Unit:is_building()
       -- Buildings have specific type ID prefixes
       local first = self.type_id:sub(1, 1)
       local second = self.type_id:sub(2, 2)
       return second == "t" or second == "g" or second == "n"  -- town hall patterns
   end

   function Unit:is_item()
       local first = self.type_id:sub(1, 1)
       return first == "I" or first == "i"
   end

   function Unit:is_random()
       return self.random_unit ~= nil
   end

   function Unit:is_waygate()
       return self.waygate_dest and self.waygate_dest >= 0
   end

   function Unit:get_hero_level()
       if self.hero_data then
           return self.hero_data.level or 1
       end
       return nil
   end

   return Unit
   ```

4. **Implement Region class**
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

   function Region:has_weather()
       return self.weather ~= nil
   end

   function Region:has_ambient_sound()
       return self.ambient_sound ~= nil
   end

   return Region
   ```

5. **Implement Camera class**
   ```lua
   -- src/gameobjects/camera.lua
   local Camera = {}
   Camera.__index = Camera

   function Camera.new(parsed)
       return setmetatable({
           name = parsed.name,
           target = {
               x = parsed.target.x,
               y = parsed.target.y,
           },
           z_offset = parsed.z_offset,
           rotation = parsed.rotation,
           aoa = parsed.aoa,
           distance = parsed.distance,
           roll = parsed.roll,
           fov = parsed.fov,
           far_clip = parsed.far_clip,
           near_clip = parsed.near_clip,
           -- 1.31+ fields
           local_pitch = parsed.local_pitch,
           local_yaw = parsed.local_yaw,
           local_roll = parsed.local_roll,
       }, Camera)
   end

   function Camera:get_eye_position()
       -- Calculate camera eye position from target + angles
       local rad_rot = math.rad(self.rotation)
       local rad_aoa = math.rad(self.aoa)

       local horizontal = self.distance * math.cos(rad_aoa)
       local vertical = self.distance * math.sin(rad_aoa)

       return {
           x = self.target.x - horizontal * math.sin(rad_rot),
           y = self.target.y - horizontal * math.cos(rad_rot),
           z = self.z_offset + vertical,
       }
   end

   function Camera:has_local_rotations()
       return self.local_pitch ~= nil
   end

   return Camera
   ```

6. **Implement Sound class**
   ```lua
   -- src/gameobjects/sound.lua
   local Sound = {}
   Sound.__index = Sound

   function Sound.new(parsed)
       return setmetatable({
           name = parsed.name,
           file = parsed.file,
           eax = parsed.eax,
           flags = parsed.flags,
           fade_in = parsed.fade_in,
           fade_out = parsed.fade_out,
           volume = parsed.volume,
           pitch = parsed.pitch,
           channel = parsed.channel,
           distance = parsed.distance,
           cone = parsed.cone,
       }, Sound)
   end

   function Sound:is_looping()
       return self.flags.looping
   end

   function Sound:is_3d()
       return self.flags.sound_3d
   end

   function Sound:is_music()
       return self.flags.music
   end

   function Sound:get_effective_volume()
       if self.volume < 0 then
           return 100  -- Default volume
       end
       return self.volume
   end

   return Sound
   ```

7. **Create module init**
   ```lua
   -- src/gameobjects/init.lua
   local Doodad = require("gameobjects.doodad")
   local Unit = require("gameobjects.unit")
   local Region = require("gameobjects.region")
   local Camera = require("gameobjects.camera")
   local Sound = require("gameobjects.sound")

   return {
       Doodad = Doodad,
       Unit = Unit,
       Region = Region,
       Camera = Camera,
       Sound = Sound,
   }
   ```

---

## Technical Notes

### Runtime vs Static Data

Each game object class separates:
- **Static data**: Loaded from map files, immutable after load
- **Runtime state**: Initialized when game starts, mutable during gameplay

For example, a Unit has:
- `base_hp`: Static, from map file (-1 = default)
- `current_hp`: Runtime, initialized from base_hp, changes during combat

### Metatables

Using Lua metatables provides:
- Method access via `object:method()`
- Type checking via `getmetatable(object) == ClassName`
- Clean API for consumers

### Serialization

Objects should be serializable for:
- Replay recording
- Savegame support
- Debugging/inspection

Consider adding `tostring()` metamethods for debugging.

---

## Related Documents

- issues/201-parse-war3map-doo.md (Doodad input format)
- issues/202-parse-war3map-units-doo.md (Unit input format)
- issues/203-parse-war3map-w3r.md (Region input format)
- issues/204-parse-war3map-w3c.md (Camera input format)
- issues/205-parse-war3map-w3s.md (Sound input format)
- issues/207-build-object-registry-system.md (object storage)

---

## Acceptance Criteria

- [ ] Doodad class with visibility/solidity methods
- [ ] Unit class with hero/building/item detection
- [ ] Region class with bounds checking
- [ ] Camera class with eye position calculation
- [ ] Sound class with flag accessors
- [ ] All classes use metatables
- [ ] All classes accept parser output in constructors
- [ ] Unit tests for each class
- [ ] Documentation comments on public APIs

---

## Notes

This issue focuses on the type definitions only. The registry system
(207) handles storage and lookup. Keep these concerns separate.

Consider whether items should be a separate class or a Unit subtype.
For simplicity, treating items as Units with `is_item()` returning true
maintains consistency with the WC3 data model where items are in
war3mapUnits.doo.
