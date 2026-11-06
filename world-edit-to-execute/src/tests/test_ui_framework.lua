-- test_ui_framework.lua - the interface's layout, hit testing, command grid elements and tooltips (issues 506b, 506c, 506e, 506f)
--
-- In plain terms: checks that anchored frames resolve to the right
-- rectangles, that WC3's console keeps its 4:3 layout at 4:3, wide and
-- narrow windows and is worked out on resize only, that a click is the
-- interface's when it lands on it (top of the draw order first) and the
-- world's otherwise, with hover, pressed, click, hotkey and text focus,
-- that the command card's buttons become elements whose click and
-- hotkey reach the same press, and that tooltips resolve TRIGSTR_
-- references, keep WC3's colour codes, show costs and stay on screen.
-- Headless: a recorder stands in for the renderer.
--
-- Run with: luajit src/tests/test_ui_framework.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local anchor = require("ui.anchor")
local console = require("ui.wc3.console_frames")
local layout = require("ui.wc3.layout")
local hit = require("ui.hit")
local commands = require("ui.wc3.commands")
local tooltip = require("ui.tooltip")
local names = require("ui.wc3.names")
local hud_mod = require("ui.wc3.hud")

-- {{{ Test utilities
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end

local function same(a, b) return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h end
local function show(r) return r and string.format("%s,%s %sx%s", r.x, r.y, r.w, r.h) or "nil" end
local function overlap(a, b) return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h end
local function within(a, w, h) return a.x >= 0 and a.y >= 0 and a.x + a.w <= w and a.y + a.h <= h end

-- a renderer that writes down what it is asked to draw
local function recorder()
    local calls, texts = {}, {}
    local ui = setmetatable({
        ui_text = function(s, x, y, size, r, g, b) texts[#texts + 1] = { s = s, x = x, y = y, c = { r, g, b } } end,
        ui_text_width = function(s, size) return #s * size / 2 end,
    }, { __index = function(_, name) return function(...) calls[#calls + 1] = { name, ... } end end })
    return ui, calls, texts
end
-- }}}

-- {{{ 506b: anchors
print("506b: anchors")
local roots, s = anchor.roots(1920, 1080)
test("the 4:3 area of a 16:9 window is centred, full height", roots.ui.x == 240 and roots.ui.w == 1440 and roots.ui.h == 1080
    and roots.ui.y == 0 and s == 1.5, show(roots.ui) .. " " .. s)
roots, s = anchor.roots(1280, 1024)
test("of a 5:4 window, the whole window, scaled by its width", roots.ui.x == 0 and roots.ui.w == 1280 and roots.ui.h == 1024
    and roots.ui.y == 0 and s == 1280 / 960, show(roots.ui))

local frames = {
    { id = "box", w = 100, h = 50, points = { { "TOPLEFT", "TOPLEFT", 10, 20 } } },
    { id = "mid", w = 100, h = 50, points = { { "CENTER", "CENTER" } } },
    { id = "corner", w = 40, h = 30, points = { { "BOTTOMRIGHT", "BOTTOMRIGHT", -5, -5 } } },
    { id = "bar", to = "screen", h = 30, points = { { "TOPLEFT", "TOPLEFT" }, { "TOPRIGHT", "TOPRIGHT" } } },
    { id = "below", to = "box", w = 20, h = 10, points = { { "TOP", "BOTTOM", 0, 4 } } },
    { id = "span", h = 10, points = { { "LEFT", "RIGHT", 0, 0, to = "box" }, { "RIGHT", "LEFT", 0, 0, to = "corner" } } },
    { id = "fill", to = "screen", points = { { "TOPLEFT", "BOTTOMLEFT", 0, 0, to = "bar" }, { "BOTTOMRIGHT", "BOTTOMRIGHT" } } },
}
local r = anchor.resolve(frames, 960, 720)
test("one point and a size: TOPLEFT with an offset", r and same(r.box, { x = 10, y = 20, w = 100, h = 50 }), show(r and r.box))
test("CENTER to CENTER", r and same(r.mid, { x = 430, y = 335, w = 100, h = 50 }), show(r and r.mid))
test("BOTTOMRIGHT, offset up and left", r and same(r.corner, { x = 915, y = 685, w = 40, h = 30 }), show(r and r.corner))
test("two points stretch across the window", r and same(r.bar, { x = 0, y = 0, w = 960, h = 30 }), show(r and r.bar))
test("anchored to another frame, below it", r and same(r.below, { x = 50, y = 74, w = 20, h = 10 }), show(r and r.below))
test("between two frames: from one's right to the other's left", r and r.span.x == 110 and r.span.x + r.span.w == 915
    and r.span.h == 10, show(r and r.span))
local half = anchor.resolve({ { id = "x", h = 10, points = { { "LEFT", "LEFT", 100, 0 }, { "CENTER", "CENTER" } } } }, 960, 720)
test("a left point and a centre point: twice the distance across", half and half.x.x == 100 and half.x.w == 760,
    show(half and half.x))
test("both axes from two corners", r and same(r.fill, { x = 0, y = 30, w = 960, h = 690 }), show(r and r.fill))
r = anchor.resolve(frames, 1920, 1080)
test("at 1920 x 1080 the 4:3 frames scale by 1.5 and move in by 240", r and same(r.box, { x = 255, y = 30, w = 150, h = 75 }),
    show(r and r.box))
test("and the stretched bar still spans the window", r and same(r.bar, { x = 0, y = 0, w = 1920, h = 45 }), show(r and r.bar))
local rr = anchor.resolve({ { id = "a", w = 10.4, h = 1, points = { { "TOPLEFT", "TOPLEFT", 0.3, 0 } } },
    { id = "b", w = 10.4, h = 1, to = "a", points = { { "TOPLEFT", "TOPRIGHT" } } } }, 960, 720)
test("edges are rounded each on its own, so neighbours meet", rr and rr.a.x + rr.a.w == rr.b.x, rr and (show(rr.a) .. " " .. show(rr.b)))

local function why(fr) return select(2, anchor.resolve(fr, 960, 720)) or "" end
test("no point: refused, saying which", why({ { id = "x", w = 1, h = 1 } }):find("x has no point", 1, true), why({ { id = "x", w = 1, h = 1 } }))
test("one point and no size: refused", why({ { id = "x", w = 1, points = { { "TOP", "TOP" } } } }):find("needs a h", 1, true))
test("an unknown point", why({ { id = "x", w = 1, h = 1, points = { { "MIDDLE", "TOP" } } } }):find("no point MIDDLE", 1, true))
test("an unknown frame", why({ { id = "x", w = 1, h = 1, to = "nope", points = { { "TOP", "TOP" } } } }):find("no frame nope", 1, true))
test("frames anchored in a circle", why({ { id = "a", w = 1, h = 1, to = "b", points = { { "TOP", "TOP" } } },
    { id = "b", w = 1, h = 1, to = "a", points = { { "TOP", "TOP" } } } }):find("circle", 1, true))
test("two frames of one name", why({ { id = "a", w = 1, h = 1, points = { { "TOP", "TOP" } } },
    { id = "a", w = 1, h = 1, points = { { "TOP", "TOP" } } } }):find("two frames are called a", 1, true))
test("a frame can't be called ui", why({ { id = "ui", w = 1, h = 1, points = { { "TOP", "TOP" } } } }):find("other than screen or ui", 1, true))
test("points that cross", why({ { id = "x", h = 1, points = { { "LEFT", "RIGHT" }, { "RIGHT", "LEFT" } } } }):find("cross", 1, true))

local cache = anchor.cache(frames)
cache:get(1280, 720) cache:get(1280, 720) cache:get(1280, 720)
test("the cache works a size out once", cache.computed == 1)
local before = cache.rects
cache:get(1920, 1080)
test("and again when the size changes", cache.computed == 2 and cache.rects ~= before)
cache:get(1920, 1080)
test("not again for the same size", cache.computed == 2)
-- }}}

-- {{{ 506b: the console
print("506b: the console")
local SIZES = { { 1024, 768 }, { 800, 600 }, { 1280, 720 }, { 1920, 1080 }, { 2560, 1080 }, { 1280, 1024 }, { 3840, 2160 } }
local PARTS = { "minimap", "portrait", "vitals", "info", "card_area" }
local all_ok, problems = true, {}
for _, sz in ipairs(SIZES) do
    local w, h = sz[1], sz[2]
    local c = console.compute(w, h)
    local function bad(what) all_ok = false problems[#problems + 1] = w .. "x" .. h .. ": " .. what end
    local everything = { c.top, c.console, c.clock, c.resources, c.minimap, c.portrait, c.vitals, c.info, c.card_area,
                         c.idle, c.panel }
    for _, l in ipairs({ c.menu, c.minimap_buttons, c.inventory, c.card, c.heroes }) do
        for _, x in ipairs(l) do everything[#everything + 1] = x end
    end
    for i, x in ipairs(everything) do if not within(x, w, h) then bad("part " .. i .. " off screen " .. show(x)) end end
    if c.console.w ~= w or c.console.x ~= 0 or c.console.y + c.console.h ~= h then bad("console not across the bottom") end
    if c.top.w ~= w or c.top.y ~= 0 then bad("top bar not across the top") end
    -- the console's parts sit on the console and apart
    local parts = { c.minimap, c.portrait, c.info, c.card_area }
    for _, x in ipairs(c.inventory) do parts[#parts + 1] = x end
    for _, x in ipairs(c.minimap_buttons) do parts[#parts + 1] = x end
    for i = 1, #parts do
        if parts[i].y < c.console.y then bad("part " .. i .. " above the console") end
        for j = i + 1, #parts do if overlap(parts[i], parts[j]) then bad("parts " .. i .. " and " .. j .. " overlap") end end
    end
    if overlap(c.portrait, c.vitals) or c.vitals.y + c.vitals.h > h then bad("vitals") end
    for i = 1, 12 do
        for j = i + 1, 12 do if overlap(c.card[i], c.card[j]) then bad("buttons " .. i .. " and " .. j) end end
        local a = c.card_area
        local b = c.card[i]
        if b.x < a.x or b.y < a.y or b.x + b.w > a.x + a.w or b.y + b.h > a.y + a.h then bad("button " .. i .. " outside the card") end
    end
    -- the top's parts apart, and above the console
    local tops = { c.clock, c.resources }
    for _, m in ipairs(c.menu) do tops[#tops + 1] = m end
    for i = 1, #tops do for j = i + 1, #tops do if overlap(tops[i], tops[j]) then bad("top parts " .. i .. " and " .. j) end end end
    if c.idle.y + c.idle.h > c.console.y or c.heroes[3].y + c.heroes[3].h > c.idle.y then bad("hero or idle buttons") end
end
test("at 4:3, 16:9, 21:9, 5:4 and 4K: every part on screen, the console's apart and on it", all_ok, table.concat(problems, "; "))

local a43, b43 = console.compute(1024, 768), console.compute(800, 600)
-- (both are rounded to whole pixels, so up to 2 apart)
local function scaled(p, q, k) return math.abs(p.x - q.x * k) <= 2 and math.abs(p.y - q.y * k) <= 2 and math.abs(p.w - q.w * k) <= 2
    and math.abs(p.h - q.h * k) <= 2 end
test("at 4:3 the layout scales with the window", scaled(a43.minimap, b43.minimap, 1024 / 800)
    and scaled(a43.card[12], b43.card[12], 1024 / 800) and scaled(a43.info, b43.info, 1024 / 800),
    show(a43.card[12]) .. " / " .. show(b43.card[12]))
local wide, narrow = console.compute(1920, 1080), console.compute(1440, 1080)
local kept = true
for _, k in ipairs({ "minimap", "portrait", "info", "card_area", "clock", "resources", "idle", "panel" }) do
    kept = kept and wide[k].x == narrow[k].x + 240 and wide[k].y == narrow[k].y and wide[k].w == narrow[k].w
end
for i = 1, 12 do kept = kept and wide.card[i].x == narrow.card[i].x + 240 end
test("on a wide window every part keeps its 4:3 place, moved in", kept, show(wide.card_area) .. " / " .. show(narrow.card_area))
test("while the bars stretch", wide.console.w == 1920 and narrow.console.w == 1440 and wide.top.w == 1920)
test("the command card sits at the right of the 4:3 area", wide.card_area.x + wide.card_area.w == 240 + 1440 - 12,
    show(wide.card_area))
local c960 = console.compute(960, 720)
test("at 960 x 720, the buttons 58 across with 4 between", c960.card[1].w == 58 and c960.card[2].x - c960.card[1].x == 62
    and c960.card[5].y - c960.card[1].y == 62 and c960.card[4].x + 58 == c960.card_area.x + c960.card_area.w,
    show(c960.card[1]) .. " " .. show(c960.card[2]))
test("the message lines grow with the scale", wide.messages.line == 30 and c960.messages.line == 20, wide.messages.line)
test("its buttons in four columns and three rows", wide.card[1].y == wide.card[4].y and wide.card[5].y > wide.card[1].y
    and wide.card[2].x > wide.card[1].x and wide.card[1].x == wide.card[9].x)
local c1280 = console.compute(1280, 720)
test("layout.compute's keys are all there", c1280.menu[4].key == "F12" and c1280.menu[1].panel == "quests"
    and c1280.minimap_buttons[2].id == "terrain" and c1280.minimap_buttons[2].alt == "T" and c1280.inventory[1].key == "KP_7"
    and c1280.heroes[1].key == "F1" and c1280.idle.key == "F8" and c1280.tooltip.bottom and c1280.messages.line == 20)
local lk = {}
for k in pairs(layout.compute(1280, 720)) do lk[#lk + 1] = k end
local missing = {}
for _, k in ipairs(lk) do if c1280[k] == nil then missing[#missing + 1] = k end end
test("nothing layout.compute gives is missing", #missing == 0, table.concat(missing, ", "))
test("the tooltip's place is above the console, at the right of the 4:3 area", c1280.tooltip.bottom < c1280.console.y
    and c1280.tooltip.x + c1280.tooltip.w == c1280.ui.x + c1280.ui.w - 8, c1280.tooltip.x .. " " .. c1280.tooltip.bottom)

local cc = console.cache()
local first = cc:get(1280, 720)
cc:get(1280, 720)
test("the console is worked out on resize only", cc.computed == 1 and cc:get(1280, 720) == first)
cc:get(1920, 1080)
test("and again after one", cc.computed == 2 and cc:get(1920, 1080).w == 1920)
-- }}}

-- {{{ the hud on the anchored console
print("the hud on the anchored console")
local function fake_game()
    local g = { player = 0, orders = {}, camera_at = { 0, 0 } }
    local function unit(id, spec, player, x, y) return { id = id, spec = spec, player = player, x = x, y = y, z = 0, name = id } end
    g.units = { unit("hfoo", { design = "unit", archetype = "infantry" }, 0, 3000, -3000),
                unit("Hpal", { design = "unit", archetype = "infantry", hero = true }, 0, 3600, -3000) }
    g.db = {
        unit_list = function(id, code) if code == "uhab" and id == "Hpal" then return { "AHhb" } end return {} end,
        unit_button = function(id) return { name = names.unit(id) or id } end,
        ability_button = function(id) return { name = names.ability(id) or id } end,
    }
    g.to_screen = function(x, y) return x / 10, -y / 10, true end
    g.to_ground = function(sx, sy) return sx * 10, -sy * 10 end
    g.camera = function() return g.camera_at[1], g.camera_at[2], 1650 end
    g.set_camera = function(x, y) g.camera_at = { x, y } end
    g.order = function(list, kind, x, y) g.orders[#g.orders + 1] = { list = list, kind = kind, x = x, y = y } end
    g.resources = function() return { gold = 500, lumber = 150, food = 12, food_cap = 30 } end
    g.time_of_day = function() return 8 end
    g.minimap = { x0 = -10000, y0 = -10000, x1 = 10000, y1 = 10000 }
    g.players = { { number = 0, name = "Red", team = 1 } }
    g.quests = { main = {}, optional = {} }
    g.portrait = function() end
    return g
end
local g = fake_game()
local hud = hud_mod.new(g, 1920, 1080)
hud.r = console.compute(1920, 1080)
hud:select({ g.units[1] })
local ui, calls, texts = recorder()
local drew = pcall(hud.draw, hud, ui)
test("the hud draws with the anchored console in place of layout.lua's", drew)
local attack = hud.r.card[commands.slot(3, 0)]
hud:update({ mx = attack.x + 5, my = attack.y + 5, lp = true, ld = true, lr = true, keys = {} }, 0.02)
test("and its Attack button, where the anchored card puts it, is pressed by a click", hud.targeting == "attack", hud.targeting)
-- }}}

-- {{{ 506c: hit testing
print("506c: hit testing")
local els = {
    { id = "console", x = 0, y = 500, w = 800, h = 100, order = 1, kind = "panel" },
    { id = "button", x = 700, y = 510, w = 40, h = 40, order = 3, kind = "button", hotkey = "A" },
    { id = "same_order_later", x = 0, y = 500, w = 50, h = 50, order = 1, kind = "panel" },
    { id = "hidden", x = 0, y = 0, w = 800, h = 600, order = 20, visible = false },
    { id = "message", x = 0, y = 0, w = 800, h = 600, order = 30, passthrough = true },
    { id = "chat", x = 100, y = 450, w = 300, h = 20, order = 5, kind = "text_entry" },
    { id = "off", x = 750, y = 510, w = 40, h = 40, order = 3, kind = "button", hotkey = "S", disabled = true },
}
local function at_(x, y) local e = hit.test(els, x, y) return e and e.id end
test("over the world: nothing", at_(400, 100) == nil, at_(400, 100))
test("over the console: the console", at_(400, 550) == "console")
test("over a button on the console: the button, drawn above", at_(710, 520) == "button")
test("of two at one order, the one drawn later", at_(10, 510) == "same_order_later")
test("a hidden element is never hit", at_(400, 100) == nil)
test("nor a passthrough one, drawn on top", at_(710, 520) == "button")
test("edges: the left and top in, the right and bottom out", at_(700, 510) == "button" and at_(740, 520) == "console"
    and at_(0, 600) == nil)
test("a hotkey finds its button, either case", hit.hotkey(els, "a") and hit.hotkey(els, "a").id == "button")
test("but not a disabled one", hit.hotkey(els, "S") == nil)

local t = hit.tracker()
local function frame(input) input.keys = input.keys or {} return t:update(els, input) end
local function names_of(ev) local o = {} for _, e in ipairs(ev) do o[#o + 1] = e[1] .. ":" .. (e[2] and e[2].id or "") end return table.concat(o, " ") end
local ev = frame({ mx = 400, my = 100 })
test("the world under the mouse: the interface doesn't own it", not t.ui_owns_mouse and #ev == 0)
ev = frame({ mx = 710, my = 520 })
test("moving onto a button: enter, hovered", names_of(ev) == "enter:button" and els[2].state == "hovered", names_of(ev))
test("and the mouse is the interface's", t.ui_owns_mouse)
ev = frame({ mx = 710, my = 520, lp = true, ld = true })
test("pressing it: press, pressed", names_of(ev) == "press:button" and els[2].state == "pressed", names_of(ev))
ev = frame({ mx = 710, my = 520, lr = true })
test("letting go on it: release and click", names_of(ev) == "release:button click:button", names_of(ev))
frame({ mx = 710, my = 520, lp = true, ld = true })
ev = frame({ mx = 400, my = 100, ld = true })
test("pressed, then dragged off: leave, and it shows normal", names_of(ev) == "leave:button" and els[2].state == "normal", names_of(ev))
test("the drag still belongs to the interface, off it", t.ui_owns_mouse)
ev = frame({ mx = 400, my = 100, lr = true })
test("let go off it: released, no click", names_of(ev) == "release:button", names_of(ev))
frame({ mx = 400, my = 100 })
test("then the world has the mouse again", not t.ui_owns_mouse)
frame({ mx = 400, my = 100, lp = true, ld = true })
ev = frame({ mx = 710, my = 520, ld = true })
test("a drag begun on the world stays the world's over the interface", not t.ui_owns_mouse)
frame({ mx = 710, my = 520, lr = true })
ev = frame({ mx = 760, my = 520, lp = true, ld = true })
test("a disabled button: hit, shown disabled, no press", names_of(ev) == "leave:button enter:off" and els[7].state == "disabled"
    and t.ui_owns_mouse, names_of(ev))
frame({ mx = 760, my = 520, lr = true })
ev = frame({ mx = 400, my = 100, keys = { "A" } })
test("a hotkey with no text focus presses its button", names_of(ev):find("hotkey:button", 1, true), names_of(ev))
ev = frame({ mx = 200, my = 455, lp = true, ld = true })
test("clicking the chat line gives it focus", names_of(ev):find("focus:chat", 1, true) and t.focus == els[6], names_of(ev))
frame({ mx = 200, my = 455, lr = true })
ev = frame({ mx = 200, my = 455, keys = { "A" }, chars = "a" })
test("with focus, keys are typing, not hotkeys", names_of(ev) == "text:chat" and ev[1][3] == "a", names_of(ev))
ev = frame({ mx = 200, my = 455, keys = { "ENTER" } })
test("Enter sends it and drops focus", names_of(ev) == "submit:chat" and t.focus == nil, names_of(ev))
frame({ mx = 200, my = 455, lp = true, ld = true }) frame({ mx = 200, my = 455, lr = true })
ev = frame({ mx = 200, my = 455, keys = { "ESCAPE" } })
test("Esc drops it too", names_of(ev) == "blur:chat" and t.focus == nil, names_of(ev))
frame({ mx = 200, my = 455, lp = true, ld = true }) frame({ mx = 200, my = 455, lr = true })
ev = frame({ mx = 400, my = 550, lp = true, ld = true })
test("a click elsewhere takes the focus away", names_of(ev):find("blur:chat", 1, true) and t.focus == nil, names_of(ev))
frame({ mx = 400, my = 550, lr = true })
frame({ mx = 710, my = 520 })
els[2].visible = false
ev = frame({ mx = 710, my = 520 })
test("an element hidden under the mouse: left, and what is under it entered", t.hover and t.hover.id == "console"
    and names_of(ev) == "leave:button enter:console", names_of(ev))
els[2].visible = true

local lr_ = layout.compute(1280, 720)
local lels = hit.from_layout(lr_)
test("from the layout: the top bar and console block the world", hit.test(lels, 640, 10) and hit.test(lels, 640, 700)
    and hit.test(lels, 640, 300) == nil)
test("its buttons carry their hotkeys", hit.hotkey(lels, "F9").id == "menu1" and hit.hotkey(lels, "F8").id == "idle"
    and hit.hotkey(lels, "KP_7").id == "inventory1")
test("the minimap is its own", hit.test(lels, lr_.minimap.x + 5, lr_.minimap.y + 5).kind == "minimap")
lels = hit.from_layout(lr_, nil, true)
test("an open panel is on top of the world", hit.test(lels, 640, 300) and hit.test(lels, 640, 300).id == "panel")
local cels = hit.from_layout(console.compute(1920, 1080))
test("the anchored console gives the same elements", #cels == #hit.from_layout(lr_) and hit.test(cels, 960, 1060))
-- }}}

-- {{{ 506e: the command grid as elements
print("506e: the command grid as elements")
local foot = g.units[1]
local card = commands.card(foot, g.db, "main")
card[commands.slot(1, 2)] = { id = "x", label = "Not now", hotkey = "Z", disabled = true, action = "ability" }
local gels = commands.elements(card, lr_.card)
local count = 0
for s_ = 1, 12 do if card[s_] then count = count + 1 end end
test("one element for each filled slot", #gels == count and count >= 5, #gels .. " " .. count)
local atk = gels[1]
for _, e in ipairs(gels) do if e.button.action == "attack" then atk = e end end
test("at its slot's rectangle, with its hotkey and button", same(atk, lr_.card[commands.slot(3, 0)]) and atk.hotkey == "A"
    and atk.slot == commands.slot(3, 0) and atk.order == 3)
local all = hit.from_layout(lr_, gels)
test("above the console it sits on", hit.test(all, atk.x + 2, atk.y + 2) == atk)
local zz
for _, e in ipairs(gels) do if e.button.id == "x" then zz = e end end
test("a disabled button stays disabled", zz and zz.disabled == true and hit.hotkey(all, "Z") == nil)
local tr = hit.tracker()
local pressed = {}
local function run_(input)
    input.keys = input.keys or {}
    for _, e in ipairs(tr:update(all, input)) do
        if e[1] == "click" or e[1] == "hotkey" then pressed[#pressed + 1] = e[2].button and e[2].button.action end
    end
end
run_({ mx = atk.x + 2, my = atk.y + 2, lp = true, ld = true })
run_({ mx = atk.x + 2, my = atk.y + 2, lr = true })
run_({ mx = 640, my = 300, keys = { "A" } })
test("a click and the hotkey reach the same button", pressed[1] == "attack" and pressed[2] == "attack", table.concat(pressed, ","))
-- }}}

-- {{{ 506f: tooltips
print("506f: tooltips")
local strings = { TRIGSTR_012 = "Train |cffffcc00F|rootman", TRIGSTR_13 = "A sturdy fighter.|nGood against |cffff0000archers|r." }
local function resolve(k) return strings[k] end
test("TRIGSTR_ references are looked up", tooltip.resolve("TRIGSTR_012", resolve) == strings.TRIGSTR_012)
test("inside other text too", tooltip.resolve("[TRIGSTR_13]", resolve) == "[" .. strings.TRIGSTR_13 .. "]")
test("one not found stays as it is", tooltip.resolve("TRIGSTR_999 x", resolve) == "TRIGSTR_999 x")
test("a resolver that gives two values (gsub's) is fine", tooltip.resolve("TRIGSTR_012",
    function(k) return ("%s"):format(strings[k]):gsub("x", "x") end) == strings.TRIGSTR_012)
test("text without references is left alone", tooltip.resolve("plain", function() error("asked") end) == "plain")
local c = tooltip.content({ label = "TRIGSTR_012", tip = "TRIGSTR_13", hotkey = "F", cost = { gold = 135, lumber = 0, food = 2 } },
    { resolve = resolve })
test("a title that marks its hotkey in colour gets no second mark", c.title == strings.TRIGSTR_012, c.title)
test("the text resolved, codes kept", c.body == strings.TRIGSTR_13)
test("costs: gold and food, no zero lumber", c.costs == "|cffffcc00Gold|r 135  |cffffcc00Food|r 2", c.costs)
c = tooltip.content({ label = "Stop", hotkey = "ESCAPE" })
test("a plain title gets its hotkey after it", c.title == "Stop (|cffffcc00Esc|r)", c.title)
test("and no costs line", c.costs == nil and c.body == nil)
c = tooltip.content({ label = "Holy Light", ubertip = "Heals.", tip = "short", cost = { mana = 65 }, cooldown_seconds = 5 })
test("ubertip before tip; mana and cooldown", c.body == "Heals." and c.costs == "|cffffcc00Mana|r 65  |cffffcc00Cooldown|r 5 s", c.costs)

local ui2, calls2, texts2 = recorder()
local near = { x = 1000, y = 520, w = 58, h = 58 }
local tip = tooltip.build(ui2, { label = "TRIGSTR_012", tip = "TRIGSTR_13", hotkey = "F", cost = { gold = 135, food = 2 } },
    near, 1280, 720, { resolve = resolve })
test("the box sits above the button, right edges together", tip.y + tip.h == near.y - tooltip.GAP and tip.x + tip.w == near.x + near.w,
    show(tip))
test("the text's own line break is kept", #tip.lines == 2, #tip.lines)
tooltip.draw(ui2, tip)
local red, gold_title = false, false
for _, x in ipairs(texts2) do
    if x.s == "archers" and x.c[1] == 255 and x.c[2] == 0 then red = true end
    if x.s == "F" and x.c[1] == 255 and x.c[2] == 204 then gold_title = true end
end
test("colour codes are drawn as colours", red and gold_title)
local plain_codes = false
for _, x in ipairs(texts2) do if x.s:find("|c", 1, true) or x.s:find("|r", 1, true) then plain_codes = true end end
test("and never shown as text", not plain_codes)
test("a frame and a back are drawn", calls2[1][1] == "ui_rect" and calls2[2][1] == "ui_frame")
local corner = tooltip.build(ui2, { label = "Long", tip = string.rep("word ", 200) }, { x = 1262, y = 10, w = 30, h = 30 }, 1280, 720)
test("near the top right: put below the button and inside the right edge", corner.y == 10 + 30 + tooltip.GAP and
    corner.x + corner.w == 1280 - tooltip.MARGIN and not corner.cut, show(corner))
corner = tooltip.build(ui2, { label = "Long", tip = string.rep("word ", 1000) }, { x = 1262, y = 10, w = 30, h = 30 }, 1280, 720)
test("too long for the screen: cut, ending with ...", corner.cut and corner.lines[#corner.lines] == "..."
    and corner.y + corner.h <= 720 - tooltip.MARGIN and corner.y >= tooltip.MARGIN, show(corner))
local wrapped = tooltip.build(ui2, { label = "Wrap", tip = string.rep("abc ", 60) }, near, 1280, 720)
local widest = 0
for _, l in ipairs(wrapped.lines) do widest = math.max(widest, ui2.ui_text_width(l, wrapped.size)) end
test("lines are wrapped to the box's width", #wrapped.lines > 1 and widest <= wrapped.w - 2 * tooltip.PAD, widest)
local tiny = tooltip.build(ui2, { label = "Tiny", tip = "x" }, { x = 0, y = 0, w = 10, h = 10 }, 200, 100)
test("on a tiny screen: no wider than the screen, on it", tiny.w <= 200 - 2 * tooltip.MARGIN and tiny.x >= tooltip.MARGIN
    and tiny.y + tiny.h <= 100, show(tiny))
local x1, y1 = tooltip.place(100, 50, { x = 2, y = 300, w = 20, h = 20 }, 800, 600)
test("near the left edge: pushed right onto the screen", x1 == tooltip.MARGIN and y1 == 300 - tooltip.GAP - 50, x1 .. "," .. y1)
local x2, y2 = tooltip.place(100, 50, { x = 400, y = 570, w = 20, h = 20 }, 800, 40)
test("a screen too short for it: kept from the top edge", y2 == tooltip.MARGIN, y2)

local tm = tooltip.timer(0.25)
local b1, b2 = {}, {}
test("not at once", tm:update(b1, 0.1) == false)
test("not before the delay", tm:update(b1, 0.1) == false)
test("after it", tm:update(b1, 0.2) == true)
test("another button starts again", tm:update(b2, 0.3) == false and tm:update(b2, 0.1) == false and tm:update(b2, 0.2) == true)
test("no button: nothing", tm:update(nil, 1) == false and tm:update(nil, 1) == false)
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("interface layout, input and tooltips: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
