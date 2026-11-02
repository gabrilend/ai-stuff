-- {{{ Shield destruction mechanics
-- Rules for how defence shields (issue 037) come to fall:
--
--   * Vulnerability windows. Certain kinds of pressure open a five-second
--     window on a shield. While it is open the shield takes 50% more damage
--     and does not repair. The four triggers are:
--       critical      the shield drops below 25% health (re-arms above 50%)
--       concentrated  three or more different attackers hit it within 2 s
--       overload      it takes 20% of its health within 2 s
--       synchronized  another shield of the same base was hit within 2 s
--   * Destruction pacing. When a shield falls, the base's other shields are
--     sealed for 30 seconds: they still take damage, but cannot drop below
--     1 health. A base therefore cannot lose shields faster than one per 30
--     seconds, which gives each unit reset (issue 040) room to play out.
--
-- Every opened window is recorded as a "shield_vulnerable" event so the
-- player can be warned. This module holds rules only; base.lua calls it from
-- Base.damage_shield and Base.update with the base's own clock.
local Mechanics = {}

Mechanics.CRITICAL_FRACTION = 0.25
Mechanics.REARM_FRACTION = 0.5
Mechanics.HIT_WINDOW = 2.0
Mechanics.CONCENTRATED_ATTACKERS = 3
Mechanics.OVERLOAD_FRACTION = 0.2
Mechanics.VULNERABLE_DURATION = 5.0
Mechanics.VULNERABLE_MULTIPLIER = 1.5
Mechanics.DESTRUCTION_COOLDOWN = 30.0

-- {{{ Mechanics.is_vulnerable
function Mechanics.is_vulnerable(shield)
    return (shield.vulnerable_time or 0) > 0
end
-- }}}

-- {{{ Mechanics.is_sealed
function Mechanics.is_sealed(base, now)
    return (base.sealed_until or -1) > now
end
-- }}}

-- {{{ Mechanics.adjust_damage
-- The damage a hit really does to `shield`: raised while the shield is
-- vulnerable, and held so the shield keeps 1 health while the base is sealed.
function Mechanics.adjust_damage(base, shield, amount, now)
    if amount <= 0 then
        return 0
    end
    if Mechanics.is_vulnerable(shield) then
        amount = amount * Mechanics.VULNERABLE_MULTIPLIER
    end
    if Mechanics.is_sealed(base, now) then
        amount = math.min(amount, math.max(0, shield.current_hp - 1))
    end
    return amount
end
-- }}}

-- {{{ local function prune_hits
local function prune_hits(shield, now)
    local kept = {}
    for _, hit in ipairs(shield.recent_hits or {}) do
        if now - hit.time <= Mechanics.HIT_WINDOW then
            table.insert(kept, hit)
        end
    end
    shield.recent_hits = kept
end
-- }}}

-- {{{ local function find_trigger
-- Returns the name of the first trigger the shield now meets, or nil.
local function find_trigger(base, shield, now)
    local fraction = shield.max_hp > 0 and shield.current_hp / shield.max_hp or 0
    if fraction < Mechanics.CRITICAL_FRACTION and not shield.critical_spent then
        shield.critical_spent = true
        return "critical"
    end

    local attackers, attacker_count, damage = {}, 0, 0
    for _, hit in ipairs(shield.recent_hits) do
        damage = damage + hit.amount
        if hit.attacker_id and not attackers[hit.attacker_id] then
            attackers[hit.attacker_id] = true
            attacker_count = attacker_count + 1
        end
    end
    if attacker_count >= Mechanics.CONCENTRATED_ATTACKERS then
        return "concentrated"
    end
    if damage >= shield.max_hp * Mechanics.OVERLOAD_FRACTION then
        return "overload"
    end

    for _, other in ipairs(base.shields) do
        if other ~= shield and other.active and other.last_hit_time
            and now - other.last_hit_time <= Mechanics.HIT_WINDOW then
            return "synchronized"
        end
    end
    return nil
end
-- }}}

-- {{{ Mechanics.record_hit
-- Called after a hit has landed on a standing shield. Remembers the hit and
-- opens a vulnerability window if a trigger is met and none is open yet.
-- Returns the trigger's name when a window opened, otherwise nil.
function Mechanics.record_hit(base, shield, attacker_id, amount, now)
    shield.recent_hits = shield.recent_hits or {}
    table.insert(shield.recent_hits, {time = now, attacker_id = attacker_id, amount = amount})
    prune_hits(shield, now)

    local reason = nil
    if shield.active and not Mechanics.is_vulnerable(shield) then
        reason = find_trigger(base, shield, now)
        if reason then
            shield.vulnerable_time = Mechanics.VULNERABLE_DURATION
            shield.vulnerable_reason = reason
        end
    end
    shield.last_hit_time = now
    return reason
end
-- }}}

-- {{{ Mechanics.on_shield_destroyed
-- Seals the base's remaining shields for the cooldown.
function Mechanics.on_shield_destroyed(base, now)
    base.sealed_until = now + Mechanics.DESTRUCTION_COOLDOWN
end
-- }}}

-- {{{ Mechanics.update
-- Counts vulnerability windows down and re-arms the critical trigger once a
-- shield has repaired back above REARM_FRACTION.
function Mechanics.update(base, dt)
    for _, shield in ipairs(base.shields or {}) do
        if (shield.vulnerable_time or 0) > 0 then
            shield.vulnerable_time = math.max(0, shield.vulnerable_time - dt)
            if shield.vulnerable_time == 0 then
                shield.vulnerable_reason = nil
            end
        end
        if shield.critical_spent and shield.current_hp > shield.max_hp * Mechanics.REARM_FRACTION then
            shield.critical_spent = false
        end
    end
end
-- }}}

return Mechanics
-- }}}
