# Issue 308: Build Event Dispatch System

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 307-implement-trigger-framework

---

## Current Behavior

No event system to fire triggers. Triggers can be created but never
execute because nothing signals when events occur.

---

## Intended Behavior

An event dispatch system providing:
- Event type registration
- Trigger-to-event binding
- Event firing with context
- Event filtering (region, unit type, player, etc.)
- Timer events
- Periodic events

---

## Suggested Implementation Steps

1. **Create event module**
   ```
   src/runtime/
   ├── init.lua         (runtime API)
   ├── handles.lua      (handle management)
   ├── triggers.lua     (from 307)
   └── events.lua       (this issue)
   ```

2. **Define event types**
   ```lua
   local EVENT = {
       -- Game events
       MAP_INIT = "MAP_INIT",
       GAME_START = "GAME_START",

       -- Timer events
       TIMER_EXPIRE = "TIMER_EXPIRE",
       TIMER_PERIODIC = "TIMER_PERIODIC",

       -- Unit events
       UNIT_DEATH = "UNIT_DEATH",
       UNIT_SPAWN = "UNIT_SPAWN",
       UNIT_DAMAGED = "UNIT_DAMAGED",
       UNIT_ATTACKED = "UNIT_ATTACKED",
       UNIT_ACQUIRED_TARGET = "UNIT_ACQUIRED_TARGET",
       UNIT_ISSUED_ORDER = "UNIT_ISSUED_ORDER",
       UNIT_SPELL_CHANNEL = "UNIT_SPELL_CHANNEL",
       UNIT_SPELL_CAST = "UNIT_SPELL_CAST",
       UNIT_SPELL_EFFECT = "UNIT_SPELL_EFFECT",
       UNIT_SPELL_FINISH = "UNIT_SPELL_FINISH",
       UNIT_SPELL_ENDCAST = "UNIT_SPELL_ENDCAST",

       -- Region events
       UNIT_ENTER_REGION = "UNIT_ENTER_REGION",
       UNIT_LEAVE_REGION = "UNIT_LEAVE_REGION",

       -- Player events
       PLAYER_CHAT = "PLAYER_CHAT",
       PLAYER_LEAVE = "PLAYER_LEAVE",
       PLAYER_ALLIANCE_CHANGE = "PLAYER_ALLIANCE_CHANGE",

       -- Dialog events
       DIALOG_BUTTON_CLICK = "DIALOG_BUTTON_CLICK",

       -- Track events
       TRACKABLE_HIT = "TRACKABLE_HIT",
       TRACKABLE_TRACK = "TRACKABLE_TRACK",
   }
   ```

3. **Implement event registry**
   ```lua
   local EventRegistry = {}
   EventRegistry.__index = EventRegistry

   function EventRegistry.new()
       local self = setmetatable({}, EventRegistry)
       self.listeners = {}  -- event_type → {trigger, filter}[]
       return self
   end

   function EventRegistry:register(event_type, trigger, filter)
       if not self.listeners[event_type] then
           self.listeners[event_type] = {}
       end
       local listener = {
           trigger = trigger,
           filter = filter or function() return true end,
       }
       self.listeners[event_type][#self.listeners[event_type] + 1] = listener
       return listener
   end

   function EventRegistry:unregister(event_type, listener)
       local list = self.listeners[event_type]
       if not list then return end
       for i, l in ipairs(list) do
           if l == listener then
               table.remove(list, i)
               return
           end
       end
   end

   function EventRegistry:fire(event_type, context)
       local list = self.listeners[event_type]
       if not list then return end

       for _, listener in ipairs(list) do
           if listener.filter(context) then
               listener.trigger:fire(context)
           end
       end
   end
   ```

4. **Implement timer events**
   ```lua
   -- TriggerRegisterTimerEvent(trigger, timeout, periodic)
   function runtime.TriggerRegisterTimerEvent(trigger, timeout, periodic)
       local timer_id = runtime._next_timer_id
       runtime._next_timer_id = runtime._next_timer_id + 1

       local timer = {
           id = timer_id,
           trigger = trigger,
           timeout = timeout,
           periodic = periodic,
           elapsed = 0,
           enabled = true,
       }

       runtime._timers[timer_id] = timer

       -- Register with event system
       local listener = events.registry:register(
           periodic and EVENT.TIMER_PERIODIC or EVENT.TIMER_EXPIRE,
           trigger,
           function(ctx) return ctx.timer_id == timer_id end
       )

       timer.listener = listener
       return timer
   end

   -- Called by game loop
   function events.update_timers(dt)
       for id, timer in pairs(runtime._timers) do
           if timer.enabled then
               timer.elapsed = timer.elapsed + dt
               if timer.elapsed >= timer.timeout then
                   local event_type = timer.periodic and
                       EVENT.TIMER_PERIODIC or EVENT.TIMER_EXPIRE

                   events.registry:fire(event_type, {
                       timer_id = id,
                       elapsed = timer.elapsed,
                   })

                   if timer.periodic then
                       timer.elapsed = timer.elapsed - timer.timeout
                   else
                       timer.enabled = false
                   end
               end
           end
       end
   end
   ```

5. **Implement region events**
   ```lua
   -- TriggerRegisterEnterRegion(trigger, region, filter)
   function runtime.TriggerRegisterEnterRegion(trigger, region, filter)
       return events.registry:register(
           EVENT.UNIT_ENTER_REGION,
           trigger,
           function(ctx)
               if ctx.region ~= region then return false end
               if filter and not filter(ctx.unit) then return false end
               return true
           end
       )
   end

   -- TriggerRegisterLeaveRegion(trigger, region, filter)
   function runtime.TriggerRegisterLeaveRegion(trigger, region, filter)
       return events.registry:register(
           EVENT.UNIT_LEAVE_REGION,
           trigger,
           function(ctx)
               if ctx.region ~= region then return false end
               if filter and not filter(ctx.unit) then return false end
               return true
           end
       )
   end

   -- Called by region system when unit crosses boundary
   function events.unit_entered_region(unit, region)
       events.registry:fire(EVENT.UNIT_ENTER_REGION, {
           unit = unit,
           region = region,
           event_id = EVENT.UNIT_ENTER_REGION,
       })
   end
   ```

6. **Implement unit events**
   ```lua
   -- TriggerRegisterUnitEvent(trigger, unit, event)
   function runtime.TriggerRegisterUnitEvent(trigger, unit, event_type)
       return events.registry:register(
           event_type,
           trigger,
           function(ctx) return ctx.unit == unit end
       )
   end

   -- TriggerRegisterAnyUnitEventBJ(trigger, event)
   function runtime.TriggerRegisterAnyUnitEventBJ(trigger, event_type)
       return events.registry:register(event_type, trigger)
   end

   -- Called by combat system
   function events.unit_died(unit, killer)
       events.registry:fire(EVENT.UNIT_DEATH, {
           unit = unit,
           killer = killer,
           event_id = EVENT.UNIT_DEATH,
       })
   end

   function events.unit_damaged(unit, source, amount)
       events.registry:fire(EVENT.UNIT_DAMAGED, {
           unit = unit,
           source = source,
           damage = amount,
           event_id = EVENT.UNIT_DAMAGED,
       })
   end
   ```

7. **Implement player events**
   ```lua
   -- TriggerRegisterPlayerEvent(trigger, player, event)
   function runtime.TriggerRegisterPlayerEvent(trigger, player, event_type)
       return events.registry:register(
           event_type,
           trigger,
           function(ctx) return ctx.player == player end
       )
   end

   -- TriggerRegisterPlayerChatEvent(trigger, player, message, exact)
   function runtime.TriggerRegisterPlayerChatEvent(trigger, player, message, exact)
       return events.registry:register(
           EVENT.PLAYER_CHAT,
           trigger,
           function(ctx)
               if player and ctx.player ~= player then return false end
               if message then
                   if exact then
                       return ctx.message == message
                   else
                       return ctx.message:find(message, 1, true) ~= nil
                   end
               end
               return true
           end
       )
   end
   ```

---

## Technical Notes

### Event Flow

```
Game State Change → Event Fire → Filter Check → Trigger Fire → Actions Execute
      ↓                ↓              ↓              ↓              ↓
  (damage)      (UNIT_DAMAGED)  (unit match?)  (conditions)   (heal unit)
```

### Event Context Structure

Each event provides context data:
```lua
{
    event_id = EVENT.UNIT_DEATH,
    unit = <dying unit>,
    killer = <killing unit>,
    damage = 100,
    -- Additional event-specific fields
}
```

### Filter Functions

Filters narrow which triggers receive events:
```lua
-- Only fire for specific unit
function(ctx) return ctx.unit == my_hero end

-- Only fire for unit type
function(ctx) return ctx.unit.type_id == "hfoo" end

-- Only fire for player
function(ctx) return ctx.player == Player(0) end
```

### Timer Precision

Timers are updated each game tick:
- Accumulate delta time
- Fire when threshold reached
- Periodic timers reset and continue
- One-shot timers disable after firing

### Event Priority

Events fire in registration order. No explicit priority system
(matches WC3 behavior).

---

## Related Documents

- docs/runtime/events.md (to be created)
- issues/307-implement-trigger-framework.md (trigger firing)
- issues/309-phase-3-integration-test.md (testing)

---

## Acceptance Criteria

- [ ] Event registry stores trigger-event bindings
- [ ] Event filtering works correctly
- [ ] Timer events fire at correct intervals
- [ ] Periodic timers repeat correctly
- [ ] Region enter/leave events work
- [ ] Unit events (death, damage, etc.) work
- [ ] Player events (chat, leave) work
- [ ] Context data available during trigger execution
- [ ] Triggers can unregister from events
- [ ] Unit tests for event system

---

## Notes

The event system is the bridge between game state and trigger execution.
When something happens in the game (unit dies, timer expires, player
chats), the event system notifies all registered triggers.

Key design decisions:
1. **Filtering at registration** - Avoid checking all triggers for all events
2. **Context passing** - All relevant data available via GetTrigger* functions
3. **Order preservation** - Triggers fire in registration order
4. **Decoupling** - Game systems fire events without knowing about triggers

This completes the trigger execution pipeline:
- Issue 307: Trigger mechanics (conditions, actions)
- Issue 308: Event system (when triggers fire)

Together they enable the full JASS trigger model.

Reference: [WC3 Event Reference](https://www.hiveworkshop.com/)
Reference: [JASS Event API](http://jass.sourceforge.net/doc/)

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:14*

## Sub-Issue Analysis

This issue is well-suited for splitting. It covers multiple distinct subsystems (core registry, timer events, region events, unit events, player events) that can be implemented and tested independently. Each event category has different context structures and filtering logic.

### Recommended Sub-Issues

---

#### 308a - implement-event-registry-core

**Description:** Create the foundational `events.lua` module with EVENT type constants, the EventRegistry class (register, unregister, fire methods), and basic filter infrastructure.

**Covers:**
- Event type enumeration (all EVENT.* constants)
- EventRegistry class implementation
- Core fire/register/unregister mechanics
- Basic unit tests for registry operations

**Dependencies:** 307 (trigger framework - needs trigger:fire() method)

**Acceptance Criteria:**
- [ ] Event registry stores trigger-event bindings
- [ ] Event filtering works correctly
- [ ] Triggers can unregister from events

---

#### 308b - implement-timer-events

**Description:** Implement timer event handling including one-shot and periodic timers, the update_timers() tick function, and TriggerRegisterTimerEvent runtime API.

**Covers:**
- Timer storage in runtime._timers
- TriggerRegisterTimerEvent() function
- events.update_timers(dt) game-loop hook
- Periodic timer reset logic
- One-shot timer disable logic

**Dependencies:** 308a (needs event registry)

**Acceptance Criteria:**
- [ ] Timer events fire at correct intervals
- [ ] Periodic timers repeat correctly
- [ ] Timer unit tests

---

#### 308c - implement-region-events

**Description:** Implement region entry/exit event registration and firing APIs.

**Covers:**
- TriggerRegisterEnterRegion()
- TriggerRegisterLeaveRegion()
- events.unit_entered_region() / events.unit_left_region() fire hooks
- Region-specific filter composition

**Dependencies:** 308a (needs event registry)

**Acceptance Criteria:**
- [ ] Region enter/leave events work
- [ ] Region event unit tests

---

#### 308d - implement-unit-events

**Description:** Implement unit event registration (death, damage, spawn, spell, orders) and the fire hooks for game systems to call.

**Covers:**
- TriggerRegisterUnitEvent()
- TriggerRegisterAnyUnitEventBJ()
- events.unit_died(), events.unit_damaged(), etc.
- Unit-specific filter logic

**Dependencies:** 308a (needs event registry)

**Acceptance Criteria:**
- [ ] Unit events (death, damage, etc.) work
- [ ] Unit event unit tests

---

#### 308e - implement-player-events

**Description:** Implement player event registration including chat events with message filtering (exact/substring match).

**Covers:**
- TriggerRegisterPlayerEvent()
- TriggerRegisterPlayerChatEvent() with exact/substring matching
- events.player_chat(), events.player_left() fire hooks
- Player-specific filter logic

**Dependencies:** 308a (needs event registry)

**Acceptance Criteria:**
- [ ] Player events (chat, leave) work
- [ ] Context data available during trigger execution
- [ ] Player event unit tests

---

### Dependency Graph

```
307 (trigger framework)
    │
    ▼
  308a (core registry)
    │
    ├──────┬──────┬──────┐
    ▼      ▼      ▼      ▼
  308b   308c   308d   308e
 (timer) (region)(unit)(player)
```

### Rationale for Splitting

1. **Independent testing** - Each event category can be unit tested in isolation
2. **Parallel development** - After 308a, sub-issues b/c/d/e have no mutual dependencies
3. **Natural boundaries** - Each maps to a distinct JASS API surface area
4. **Incremental integration** - Can verify trigger→event→action flow with just timers before adding combat events
5. **Manageable scope** - Each sub-issue is ~50-100 lines of focused code
