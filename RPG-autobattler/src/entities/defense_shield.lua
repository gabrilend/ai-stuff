-- {{{ Defense shields
-- Every base is guarded by three defence shields. Each holds about five
-- average units of health. While any shield stands, a hit aimed at the base
-- lands on the front shield instead, so the core only takes damage once all
-- three are gone. Shields slowly repair when left alone, but a destroyed
-- shield stays down for the rest of the match.
--
-- Shields live as plain tables in the base component's `shields` list, each
-- with its own position around the base so it can be drawn and targeted.
-- This file knows nothing about the base module, so base.lua can require it.
local DefenseShield = {}

DefenseShield.COUNT = 3
DefenseShield.HEALTH_IN_UNITS = 5
DefenseShield.REGEN_RATE = 2.0      -- health per second
DefenseShield.REGEN_DELAY = 5.0     -- seconds without damage before repair
DefenseShield.RING_RADIUS = 40      -- distance from the base's centre

-- {{{ DefenseShield.create_shields
-- Returns `count` shields spread evenly on a ring around (x, y). The first
-- shield faces `facing` (radians), which should point toward the enemy so
-- the front shield is the one attackers meet first.
function DefenseShield.create_shields(x, y, max_hp, count, facing)
    count = count or DefenseShield.COUNT
    facing = facing or 0
    local shields = {}
    for index = 1, count do
        -- Spread the shields across the front half: centre, then either side.
        local offset = 0
        if index > 1 then
            local side = (index % 2 == 0) and 1 or -1
            offset = side * math.floor(index / 2) * (math.pi / 4)
        end
        local angle = facing + offset
        shields[index] = {
            index = index,
            x = x + math.cos(angle) * DefenseShield.RING_RADIUS,
            y = y + math.sin(angle) * DefenseShield.RING_RADIUS,
            max_hp = max_hp,
            current_hp = max_hp,
            active = true,
            time_since_damage = DefenseShield.REGEN_DELAY,
            total_absorbed = 0,
            destroyed_by = nil
        }
    end
    return shields
end
-- }}}

-- {{{ DefenseShield.get_front_shield
-- The lowest-numbered shield still standing, or nil when all are down.
function DefenseShield.get_front_shield(shields)
    for _, shield in ipairs(shields or {}) do
        if shield.active then
            return shield
        end
    end
    return nil
end
-- }}}

-- {{{ DefenseShield.count_active
function DefenseShield.count_active(shields)
    local count = 0
    for _, shield in ipairs(shields or {}) do
        if shield.active then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ DefenseShield.damage_shield
-- Removes up to `amount` health from one shield. Damage beyond what the
-- shield has left is lost, not passed on: one big hit can break at most one
-- shield, so every shield's fall triggers its own reset. Returns the health
-- removed and whether this hit destroyed the shield.
function DefenseShield.damage_shield(shield, amount, attacker_team)
    if not shield or not shield.active or amount <= 0 then
        return 0, false
    end

    local dealt = math.min(amount, shield.current_hp)
    shield.current_hp = shield.current_hp - dealt
    shield.total_absorbed = shield.total_absorbed + dealt
    shield.time_since_damage = 0

    if shield.current_hp <= 0 then
        shield.current_hp = 0
        shield.active = false
        shield.destroyed_by = attacker_team
        return dealt, true
    end
    return dealt, false
end
-- }}}

-- {{{ DefenseShield.update
-- Repairs standing shields that have gone REGEN_DELAY seconds without damage.
-- Only time past the delay counts, as with the base core.
function DefenseShield.update(shields, dt)
    for _, shield in ipairs(shields or {}) do
        if shield.active then
            local before = shield.time_since_damage
            shield.time_since_damage = before + dt
            local repair_time = shield.time_since_damage - math.max(before, DefenseShield.REGEN_DELAY)
            if repair_time > 0 and shield.current_hp < shield.max_hp then
                shield.current_hp = math.min(shield.max_hp,
                    shield.current_hp + DefenseShield.REGEN_RATE * repair_time)
            end
        end
    end
end
-- }}}

-- {{{ DefenseShield.get_status
-- A summary for drawing: one row per shield with its position, whether it
-- stands, and its health fraction.
function DefenseShield.get_status(shields)
    local status = {}
    for _, shield in ipairs(shields or {}) do
        table.insert(status, {
            index = shield.index,
            x = shield.x,
            y = shield.y,
            active = shield.active,
            fraction = shield.max_hp > 0 and shield.current_hp / shield.max_hp or 0
        })
    end
    return status
end
-- }}}

return DefenseShield
-- }}}
