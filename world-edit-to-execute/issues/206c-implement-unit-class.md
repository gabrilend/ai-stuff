# Issue 206c: Implement Unit Class

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** High
**Dependencies:** 206a-create-gameobjects-module-structure, 202-parse-war3map-units-doo
**Parent Issue:** 206-design-game-object-types

---

## Current Behavior

Unit parser (src/parsers/unitsdoo.lua) returns plain tables. No Unit class exists
to provide type detection, hero handling, or consistent API.

---

## Intended Behavior

A Unit class that wraps parsed unit data with:
- Type detection (hero, building, item)
- Hero data access (level, stats, inventory)
- Random unit and waygate handling
- Clear separation of static vs runtime data

```lua
local gameobjects = require("gameobjects")
local unit = gameobjects.Unit.new(parsed_unit)

print(unit.type_id)          -- "Hpal" (Paladin)
print(unit:is_hero())        -- true
print(unit:get_hero_level()) -- 5
print(unit:is_building())    -- false
print(unit:is_waygate())     -- false
```

---

## Suggested Implementation Steps

1. **Create Unit class**
   ```lua
   -- src/gameobjects/unit.lua
   local Unit = {}
   Unit.__index = Unit

   function Unit.new(parsed)
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
   end
   ```

2. **Implement type detection methods**
   ```lua
   function Unit:is_hero()
       return self.hero_data ~= nil
   end

   function Unit:is_building()
       -- Buildings have specific type ID patterns
       -- Second char typically indicates structure type
       local second = self.type_id:sub(2, 2)
       return second == "t" or second == "g" or second == "n"
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
   ```

3. **Implement hero methods**
   ```lua
   function Unit:get_hero_level()
       if self.hero_data then
           return self.hero_data.level or 1
       end
       return nil
   end

   function Unit:get_hero_stats()
       if self.hero_data then
           return {
               str_bonus = self.hero_data.str_bonus or 0,
               agi_bonus = self.hero_data.agi_bonus or 0,
               int_bonus = self.hero_data.int_bonus or 0,
           }
       end
       return nil
   end

   function Unit:get_inventory()
       if self.hero_data then
           return self.hero_data.inventory or {}
       end
       return {}
   end
   ```

4. **Add __tostring metamethod**
   ```lua
   function Unit:__tostring()
       local desc = self.type_id
       if self:is_hero() then
           desc = desc .. " L" .. self:get_hero_level()
       end
       return string.format("Unit<%s P%d at (%.0f,%.0f)>",
           desc, self.player, self.position.x, self.position.y)
   end
   ```

5. **Update init.lua and create tests**

---

## Technical Notes

### Unit Type ID Patterns

```lua
-- Heroes: Capital first letter
Hpal = "Paladin"
Obla = "Blademaster"
Udea = "Death Knight"
Edem = "Demon Hunter"

-- Buildings: Second char indicates type
htow = "Town Hall"
hbar = "Barracks"

-- Items: 'I' or 'i' prefix
Iclr = "Cloak of Flames"
bspd = "Boots of Speed" (lowercase)

-- Random: 'Y' prefix
YYU5 = "Random unit level 5"
```

### Parser Output Fields

From src/parsers/unitsdoo.lua:
```lua
{
    id = "Hpal",
    variation = 0,
    position = { x, y, z },
    angle = 0.0,
    scale = { x, y, z },
    player = 0,
    hp = -1,              -- -1 = default
    mp = -1,
    item_drops = {...},   -- From 202b
    abilities = {...},    -- From 202c
    hero_data = {...},    -- From 202d (nil for non-heroes)
    random_unit = {...},  -- From 202e (nil if not random)
    waygate_dest = -1,    -- From 202e
    creation_number = 1,
    is_hero = true,       -- Helper flag
}
```

---

## Related Documents

- issues/202-parse-war3map-units-doo.md (parser implementation)
- issues/202a-d (sub-parsers)
- src/parsers/unitsdoo.lua (input format)
- issues/206-design-game-object-types.md (parent)

---

## Acceptance Criteria

- [ ] Unit class with constructor
- [ ] is_hero() method
- [ ] is_building() method
- [ ] is_item() method
- [ ] is_random() method
- [ ] is_waygate() method
- [ ] get_hero_level() method
- [ ] get_hero_stats() method
- [ ] get_inventory() method
- [ ] __tostring metamethod
- [ ] Unit tests for Unit class
- [ ] init.lua exports Unit

---

## Notes

Unit is the most complex game object type. Items are handled as Units with
is_item() returning true, maintaining consistency with WC3's data model
where items appear in war3mapUnits.doo.

Note: 202e (random/waygate) should be completed before this issue to ensure
random_unit and waygate_dest fields are available.
