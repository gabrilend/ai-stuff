#!/usr/bin/env luajit
-- test_balance_history.lua - the balance history generator's data
--
-- Builds the Frozen Throne history (every built version, the disc first) and
-- checks it against changes found earlier by hand: the Knight's melee damage
-- was 25 up to 1.21b and 28 from 1.22a (issue 112b's patch-notes check), and
-- its hit points went from 800 to 835 in 1.19a. Also checks that only fields
-- that change are kept. Needs the install and the layers; skipped without.
--
-- Run: luajit src/tests/test_balance_history.lua [DIR]
-- Issue: issues/completed/115-balance-history-explorer.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local pass, fail, skipped = 0, 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end

local probe = io.open(DIR .. "/wc3-installs/patch-layers/1.22a/manifest.lua", "r")
if not probe then
    skipped = 1
    print("  [SKIP] balance history -- needs the Frozen Throne layers (build-patch-layer.lua --stack) --")
else
    probe:close()
    arg = { [0] = "test" }   -- load the generator as a module, not as a run
    local bh = dofile(DIR .. "/src/cli/balance-history.lua")
    local h = bh.build({ tft = true }).games.tft
    local function at(version)
        for i, v in ipairs(h.versions) do if v == version then return i end end
    end
    test("versions start with the disc and run in order", h.versions[1] == "1.07" and at("1.21b") < at("1.22a"),
        table.concat(h.versions, " "))
    local knight = h.objects.hkni
    test("the Knight is in the history", knight ~= nil)
    if knight then
        local dmg = knight.fields["UnitWeapons.dmgplus1"]
        test("Knight damage 25 at 1.21b, 28 at 1.22a", dmg and dmg[at("1.21b")] == 25 and dmg[at("1.22a")] == 28,
            dmg and (tostring(dmg[at("1.21b")]) .. " -> " .. tostring(dmg[at("1.22a")])))
        local hp = knight.fields["UnitBalance.HP"]
        test("Knight hit points 800 at 1.14b, 835 at 1.19a", hp and hp[at("1.14b")] == 800 and hp[at("1.19a")] == 835,
            hp and (tostring(hp[at("1.14b")]) .. " -> " .. tostring(hp[at("1.19a")])))
        test("the Knight's name comes from the text", knight.name == "Knight", tostring(knight.name))
    end
    -- Every kept field changes somewhere.
    local unchanged = 0
    for _, o in pairs(h.objects) do
        for _, values in pairs(o.fields) do
            local first, changes
            for i = 1, #h.versions do
                local v = values[i]
                if v ~= nil then if first == nil then first = v elseif v ~= first then changes = true end end
            end
            if not changes then unchanged = unchanged + 1 end
        end
    end
    test("only fields that change are kept", unchanged == 0, unchanged .. " unchanged fields")
end

print(string.format("\nTests: %d passed, %d failed (%d skipped)", pass, fail, skipped))
os.exit(fail > 0 and 1 or 0)
