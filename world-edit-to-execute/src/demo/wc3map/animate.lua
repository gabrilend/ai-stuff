--[[
Units' Animations (Issue 523)

Which of its model's sequences a unit plays, from what it's doing in the
game (demo/wc3map/game.lua, combat.lua), as WC3 picks them:

  dead       Death, once, then its last frame held while the corpse lies
  attacking  Attack, from its start at each swing, sped up or slowed so
             the swing's wind-up and backswing fit it (within 0.5x - 3x)
  walking    Walk, at the speed the unit moves over the model's own walk
             speed (the sequence's move speed), when the model gives one
  otherwise  Stand (its variants, by rarity)

A model without the one wanted stands. Doodads and buildings stand.

    local animate = require("demo.wc3map.animate")
    local pose = animate.unit(rig, u, dt)       -- for render.model_draw
    local pose = animate.still(rig, d, dt)      -- a doodad's
]]

local anim = require("assets.anim")

local animate = {}

-- {{{ animate.unit
function animate.unit(rig, u, dt)
    local st = u.anim
    if not st then
        st = anim.state()
        u.anim = st
    end
    if not u.alive then
        anim.play(rig, st, "death", { fallback = "stand" })
    elseif u.swing then
        -- a new swing starts the attack over
        local fresh = not st.swing or u.swing < st.swing
        local w = u.weapon
        local len = anim.duration(rig, "attack")
        local rate = 1
        if len and w and (w.attack_point or 0) + (w.backswing or 0) > 0 then
            rate = math.max(0.5, math.min(3, len / (w.attack_point + w.backswing)))
        end
        anim.play(rig, st, "attack", { rate = rate, restart = fresh, fallback = "stand" })
    elseif u.route and not u.paused then
        local rate = 1
        local sq = rig.by_name.walk and rig.sequences[rig.by_name.walk[1]]
        if sq and sq.move_speed and sq.move_speed > 0 and u.speed then
            rate = math.max(0.5, math.min(2.5, u.speed / sq.move_speed))
        end
        anim.play(rig, st, "walk", { rate = rate, fallback = "stand" })
    else
        anim.play(rig, st, "stand", { phase = math.random() })
    end
    st.swing = u.swing
    anim.step(rig, st, dt)
    return anim.pose(rig, st)
end
-- }}}

-- {{{ animate.still
-- Doodads and anything else that only stands (trees sway, banners wave)
function animate.still(rig, d, dt)
    local st = d.anim
    if not st then
        st = anim.state()
        d.anim = st
        anim.play(rig, st, "stand", { phase = math.random() })
    end
    anim.step(rig, st, dt)
    return anim.pose(rig, st)
end
-- }}}

return animate
