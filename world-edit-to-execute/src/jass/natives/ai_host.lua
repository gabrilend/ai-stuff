--[[
JASS natives: starting and commanding computer players (Issue 521)

The common.j natives a map script uses to hand players to an AI, and
Blizzard.j's MeleeStartingAI, on the AI manager (src/ai/init.lua).
Installed after interface.lua and bj.lua, whose do-nothing versions
these replace.
]]

return function(V, N, T)
    local function manager() return require("ai").manager(V) end
    local function real(name) V.noop[name] = nil end

    N.StartMeleeAI = function(p, path) if p then manager():start_script(p.id, path, false) end end
    N.StartCampaignAI = function(p, path) if p then manager():start_script(p.id, path, true) end end
    N.CommandAI = function(p, cmd, data) if p then manager():command(p.id, cmd, data) end end
    N.PauseCompAI = function(p, on) if p then manager():pause(p.id, on) end end
    N.GetAIDifficulty = function(p)
        local d = V.opts.ai_difficulty or "normal"
        return ({ easy = "AI_DIFFICULTY_NEWBIE", normal = "AI_DIFFICULTY_NORMAL", insane = "AI_DIFFICULTY_INSANE" })[d]
    end
    -- Blizzard.j: every computer player gets the melee AI of its race
    N.MeleeStartingAI = function()
        for n = 0, 11 do
            local p = V:player(n)
            if p.controller == "MAP_CONTROL_COMPUTER" and p.slot == "PLAYER_SLOT_STATE_PLAYING" then
                local race = tostring(p.race or "RACE_HUMAN"):lower():gsub("^race_", "")
                manager():start_script(n, "scripts\\" .. race .. ".ai", false)
            end
        end
    end
    for _, name in ipairs({ "StartMeleeAI", "StartCampaignAI", "CommandAI", "PauseCompAI", "MeleeStartingAI" }) do
        real(name)
    end
end
