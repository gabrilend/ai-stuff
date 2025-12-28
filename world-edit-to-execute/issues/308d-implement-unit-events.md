# Issue 308d: Implement Unit Events

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent Issue:** 308-build-event-dispatch-system.md
**Dependencies:** 308a-implement-event-registry-core

---

## Current Behavior

The event registry from 308a provides infrastructure for event→trigger bindings.
However, there are no unit-related events - no way to trigger actions when units
are damaged, die, attack, cast spells, or receive orders.

Currently:
- No TriggerRegisterUnitEvent function
- No TriggerRegisterAnyUnitEventBJ function
- No event firing hooks for combat/unit actions
- No GetEventDamage, GetKillingUnit, etc. accessor functions

---

## Intended Behavior

A unit event subsystem that provides:

1. **Unit Event Registration APIs**:
   - `TriggerRegisterUnitEvent(trigger, unit, event_type)` - Specific unit events
   - `TriggerRegisterAnyUnitEventBJ(trigger, event_type)` - Any unit events
   - `TriggerRegisterPlayerUnitEvent(trigger, player, event_type, filter)` - Player's units

2. **Event Firing Hooks** - Called by future combat/unit systems:
   - `events.unit_died(unit, killer)` - Fire UNIT_DEATH
   - `events.unit_damaged(unit, source, amount, attack_type)` - Fire UNIT_DAMAGED
   - `events.unit_attacked(unit, attacker)` - Fire UNIT_ATTACKED
   - `events.unit_spawned(unit)` - Fire UNIT_SPAWN
   - `events.unit_acquired_target(unit, target)` - Fire UNIT_ACQUIRED_TARGET
   - `events.unit_issued_order(unit, order, target)` - Fire UNIT_ISSUED_ORDER
   - Spell events: channel, cast, effect, finish, endcast

3. **Event Context Structures**:
   ```lua
   -- UNIT_DEATH context
   {
       event_id = EVENT.UNIT_DEATH,
       unit = <dying unit>,
       triggering_unit = <dying unit>,
       killing_unit = <killer>,
   }

   -- UNIT_DAMAGED context
   {
       event_id = EVENT.UNIT_DAMAGED,
       unit = <damaged unit>,
       triggering_unit = <damaged unit>,
       source = <damage source unit>,
       damage = <damage amount>,
       attack_type = <attack type constant>,
   }
   ```

4. **Context Accessor Functions**:
   - `GetDyingUnit()` - Unit that died
   - `GetKillingUnit()` - Unit that killed
   - `GetEventDamage()` - Damage amount
   - `GetEventDamageSource()` - Damage source unit
   - `GetAttacker()` - Attacking unit
   - `GetOrderedUnit()` - Unit receiving order
   - `GetIssuedOrderId()` - Order ID
   - `GetSpellAbilityId()` - Spell being cast
   - `GetSpellTargetUnit()` - Spell target

---

## Suggested Implementation Steps

1. **Implement TriggerRegisterUnitEvent function**
   ```lua
   -- {{{ TriggerRegisterUnitEvent
   function runtime.TriggerRegisterUnitEvent(trigger, unit, event_type)
       return events.register(
           event_type,
           trigger,
           function(ctx)
               return ctx.unit == unit
           end
       )
   end
   -- }}}
   ```

2. **Implement TriggerRegisterAnyUnitEventBJ function**
   ```lua
   -- {{{ TriggerRegisterAnyUnitEventBJ
   -- Fires for any unit matching the event type (no unit filter)
   function runtime.TriggerRegisterAnyUnitEventBJ(trigger, event_type)
       return events.register(event_type, trigger)
       -- No filter = fires for all units
   end
   -- }}}
   ```

3. **Implement TriggerRegisterPlayerUnitEvent function**
   ```lua
   -- {{{ TriggerRegisterPlayerUnitEvent
   function runtime.TriggerRegisterPlayerUnitEvent(trigger, player, event_type, filter)
       return events.register(
           event_type,
           trigger,
           function(ctx)
               -- Unit must belong to specified player
               if ctx.unit.owner ~= player then return false end
               -- Apply optional additional filter
               if filter and not filter(ctx.unit) then return false end
               return true
           end
       )
   end
   -- }}}
   ```

4. **Implement unit_died fire hook**
   ```lua
   -- {{{ unit_died
   -- Called by combat system when unit health reaches 0
   function events.unit_died(unit, killer)
       events.fire(events.EVENT.UNIT_DEATH, {
           event_id = events.EVENT.UNIT_DEATH,
           unit = unit,
           triggering_unit = unit,
           dying_unit = unit,
           killing_unit = killer,
       })
   end
   -- }}}
   ```

5. **Implement unit_damaged fire hook**
   ```lua
   -- {{{ unit_damaged
   -- Called by combat system when unit takes damage
   function events.unit_damaged(unit, source, amount, attack_type)
       events.fire(events.EVENT.UNIT_DAMAGED, {
           event_id = events.EVENT.UNIT_DAMAGED,
           unit = unit,
           triggering_unit = unit,
           damaged_unit = unit,
           source = source,
           damage_source = source,
           damage = amount,
           attack_type = attack_type,
       })
   end
   -- }}}
   ```

6. **Implement unit_attacked fire hook**
   ```lua
   -- {{{ unit_attacked
   -- Called when unit initiates attack against target
   function events.unit_attacked(target, attacker)
       events.fire(events.EVENT.UNIT_ATTACKED, {
           event_id = events.EVENT.UNIT_ATTACKED,
           unit = target,
           triggering_unit = target,
           attacked_unit = target,
           attacker = attacker,
           attacking_unit = attacker,
       })
   end
   -- }}}
   ```

7. **Implement unit_spawned fire hook**
   ```lua
   -- {{{ unit_spawned
   -- Called when unit is created/spawned into game
   function events.unit_spawned(unit)
       events.fire(events.EVENT.UNIT_SPAWN, {
           event_id = events.EVENT.UNIT_SPAWN,
           unit = unit,
           triggering_unit = unit,
       })
   end
   -- }}}
   ```

8. **Implement unit_acquired_target fire hook**
   ```lua
   -- {{{ unit_acquired_target
   -- Called when unit acquires a new attack target
   function events.unit_acquired_target(unit, target)
       events.fire(events.EVENT.UNIT_ACQUIRED_TARGET, {
           event_id = events.EVENT.UNIT_ACQUIRED_TARGET,
           unit = unit,
           triggering_unit = unit,
           target = target,
       })
   end
   -- }}}
   ```

9. **Implement unit_issued_order fire hook**
   ```lua
   -- {{{ unit_issued_order
   -- Called when unit receives an order
   function events.unit_issued_order(unit, order_id, target, target_x, target_y)
       events.fire(events.EVENT.UNIT_ISSUED_ORDER, {
           event_id = events.EVENT.UNIT_ISSUED_ORDER,
           unit = unit,
           triggering_unit = unit,
           ordered_unit = unit,
           order_id = order_id,
           target = target,
           target_x = target_x,
           target_y = target_y,
       })
   end
   -- }}}
   ```

10. **Implement spell event fire hooks**
    ```lua
    -- {{{ unit_spell_channel
    function events.unit_spell_channel(unit, ability_id, target, target_x, target_y)
        events.fire(events.EVENT.UNIT_SPELL_CHANNEL, {
            event_id = events.EVENT.UNIT_SPELL_CHANNEL,
            unit = unit,
            triggering_unit = unit,
            ability_id = ability_id,
            spell_ability_id = ability_id,
            target = target,
            spell_target_unit = target,
            target_x = target_x,
            target_y = target_y,
        })
    end
    -- }}}

    -- Similar for: UNIT_SPELL_CAST, UNIT_SPELL_EFFECT, UNIT_SPELL_FINISH, UNIT_SPELL_ENDCAST
    ```

11. **Implement context accessor functions**
    ```lua
    -- {{{ GetDyingUnit
    function runtime.GetDyingUnit()
        local ctx = events._current_context
        return ctx and ctx.dying_unit
    end
    -- }}}

    -- {{{ GetKillingUnit
    function runtime.GetKillingUnit()
        local ctx = events._current_context
        return ctx and ctx.killing_unit
    end
    -- }}}

    -- {{{ GetEventDamage
    function runtime.GetEventDamage()
        local ctx = events._current_context
        return ctx and ctx.damage or 0
    end
    -- }}}

    -- {{{ GetEventDamageSource
    function runtime.GetEventDamageSource()
        local ctx = events._current_context
        return ctx and ctx.damage_source
    end
    -- }}}

    -- {{{ GetAttacker
    function runtime.GetAttacker()
        local ctx = events._current_context
        return ctx and ctx.attacking_unit
    end
    -- }}}

    -- {{{ GetOrderedUnit
    function runtime.GetOrderedUnit()
        local ctx = events._current_context
        return ctx and ctx.ordered_unit
    end
    -- }}}

    -- {{{ GetIssuedOrderId
    function runtime.GetIssuedOrderId()
        local ctx = events._current_context
        return ctx and ctx.order_id
    end
    -- }}}

    -- {{{ GetSpellAbilityId
    function runtime.GetSpellAbilityId()
        local ctx = events._current_context
        return ctx and ctx.spell_ability_id
    end
    -- }}}

    -- {{{ GetSpellTargetUnit
    function runtime.GetSpellTargetUnit()
        local ctx = events._current_context
        return ctx and ctx.spell_target_unit
    end
    -- }}}
    ```

12. **Write unit tests**
    - Create `src/tests/test_unit_events.lua`
    - Test TriggerRegisterUnitEvent for specific unit
    - Test TriggerRegisterAnyUnitEventBJ for any unit
    - Test TriggerRegisterPlayerUnitEvent filters by owner
    - Test unit_died fires UNIT_DEATH with correct context
    - Test unit_damaged fires UNIT_DAMAGED with damage amount
    - Test unit_attacked fires UNIT_ATTACKED with attacker
    - Test unit_spawned fires UNIT_SPAWN
    - Test unit_issued_order includes order_id and target
    - Test spell events fire in correct sequence
    - Test all GetXxx accessor functions return correct values
    - Test accessor functions return nil/0 when no context

---

## Related Documents

- issues/308-build-event-dispatch-system.md (parent issue)
- issues/308a-implement-event-registry-core.md (dependency - event registry)
- issues/4xx-combat-system.md (will call unit event hooks)
- issues/4xx-order-system.md (will call order event hooks)
- src/runtime/events.lua (event registry)
- src/runtime/init.lua (runtime API)

---

## Acceptance Criteria

- [ ] TriggerRegisterUnitEvent fires only for specified unit
- [ ] TriggerRegisterAnyUnitEventBJ fires for any unit
- [ ] TriggerRegisterPlayerUnitEvent filters by unit owner
- [ ] Unit events (death, damage, attack, spawn, order) fire correctly
- [ ] Spell events (channel, cast, effect, finish, endcast) fire correctly
- [ ] events.unit_died(unit, killer) fires UNIT_DEATH
- [ ] events.unit_damaged(unit, source, amount) fires UNIT_DAMAGED
- [ ] events.unit_attacked(target, attacker) fires UNIT_ATTACKED
- [ ] GetDyingUnit returns dying unit from death event
- [ ] GetKillingUnit returns killer from death event
- [ ] GetEventDamage returns damage amount from damage event
- [ ] GetEventDamageSource returns source unit from damage event
- [ ] GetAttacker returns attacking unit from attack event
- [ ] GetOrderedUnit returns ordered unit from order event
- [ ] GetIssuedOrderId returns order ID from order event
- [ ] GetSpellAbilityId returns ability ID from spell events
- [ ] GetSpellTargetUnit returns target from spell events
- [ ] Context accessors return nil/0 outside event execution
- [ ] Unit tests pass for all unit event operations

---

## Notes

Unit events are the most commonly used event type in WC3 maps. The damage and
death events power most combat triggers, while spell events enable custom
ability implementations.

The distinction between UNIT_ATTACKED (target receives event) and a hypothetical
UNIT_ATTACKS (attacker receives event) matches WC3 semantics. Most maps use
UNIT_ATTACKED.

Spell events fire in sequence:
1. SPELL_CHANNEL - Channeling begins (can be interrupted)
2. SPELL_CAST - Cast point reached, mana spent
3. SPELL_EFFECT - Spell actually executes
4. SPELL_FINISH - Spell completed successfully
5. SPELL_ENDCAST - Cleanup (fires even if interrupted)

The unit.owner property used in TriggerRegisterPlayerUnitEvent assumes units
have an owner field. This will be established by the entity/unit system in
Phase 4.

Event contexts include multiple aliases for the same data (e.g., unit,
triggering_unit, dying_unit for UNIT_DEATH) to support different accessor
functions and maintain WC3 API compatibility.
