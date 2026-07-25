-- 017-easing-test.lua — proof for the easings and envelopes.
--
-- What this is, generally: a property test that walks BOTH whole
-- dispatch tables (so a curve added later cannot forget the
-- contract), plus shape spot-checks — the stroke lingers low, its
-- mirror leaps, the envelopes breathe where they should.
-- Run: luajit src/017-easing-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local easing = require("016-easing")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
    end
end
-- }}}

-- the property walk: every registered easing keeps the contract —
-- ends pinned, bounds kept, and (for motion) never walking backward
for name, fn in pairs(easing.EASINGS) do
    check("motion '" .. name .. "' starts at zero", fn(0) == 0)
    check("motion '" .. name .. "' ends at one",
          math.abs(fn(1) - 1) < 1e-12)
    local inside, forward = true, true
    local last = fn(0)
    for i = 1, 200 do
        local v = fn(i / 200)
        if v < -1e-12 or v > 1 + 1e-12 then inside = false end
        if v < last - 1e-12 then forward = false end
        last = v
    end
    check("motion '" .. name .. "' stays inside its banks", inside)
    check("motion '" .. name .. "' never walks backward", forward)
end

-- envelopes: bounds only (they may start and end anywhere inside)
for name, fn in pairs(easing.ENVELOPES) do
    local inside = true
    for i = 0, 200 do
        local v = fn(i / 200)
        if v < -1e-12 or v > 1 + 1e-12 then inside = false end
    end
    check("envelope '" .. name .. "' stays inside its banks", inside)
end

-- the stroke's character: lingers low at the half, snaps at the end
local stroke = easing.motion("stroke")
check("the stroke lingers below a fifth at halfway",
      stroke(0.5) < 0.2)
check("the stroke has covered most ground by nine tenths",
      stroke(0.9) > 0.7)

-- the mirror leaps where the stroke lingers
local out = easing.motion("ease-out")
check("ease-out is the stroke's mirror at the half",
      math.abs(out(0.5) - (1 - stroke(0.5))) < 1e-12)

-- envelopes breathe where they should
local env_in = easing.envelope("in")
local env_out = easing.envelope("out")
local env_inout = easing.envelope("in-out")
local flash = easing.envelope("flash")
check("fade-in is silent at birth and full past its shoulder",
      env_in(0) == 0 and env_in(0.5) == 1)
check("fade-out is full early and silent at the end",
      env_out(0.5) == 1 and env_out(1) == 0)
check("in-out breathes in, holds, breathes out",
      env_inout(0) == 0 and env_inout(0.5) == 1 and env_inout(1) == 0)
check("a flash is loudest at the instant it begins",
      flash(0) == 1 and flash(0.5) < 0.2)
check("hold holds", easing.envelope("hold")(0.37) == 1)

-- the walls teach: refusals carry the legal words
local ok, err = pcall(easing.motion, "strok")
check("a misspelled motion is refused", not ok)
check("the refusal teaches the legal words",
      err ~= nil and err:find("stroke", 1, true) ~= nil
      and err:find("linear", 1, true) ~= nil)
check("a misspelled envelope is refused",
      not pcall(easing.envelope, "fade"))

print(string.format("easing: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
