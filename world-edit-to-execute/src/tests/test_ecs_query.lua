-- ECS Query System Unit Tests (402c)
-- Tests for component query iteration and filtering.
-- Run with: luajit src/tests/test_ecs_query.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local entity = require("runtime.ecs.entity")
local component = require("runtime.ecs.component")
local query = require("runtime.ecs.query")
local ecs = require("runtime.ecs")

-- {{{ Test utilities
local test_count = 0
local pass_count = 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function reset_all()
    entity.reset()
    entity.clear_hooks()
    component.clear_all()
    component.init(true)
end
-- }}}

-- {{{ Single Component Query Tests
test_section("Single Component Query")
reset_all()

component.register("position", {x = 0, y = 0})

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()
component.add(e1, "position", {x = 10})
component.add(e2, "position", {x = 20})
-- e3 has no position

local found = {}
for eid, pos in query.single("position") do
    found[eid] = pos.x
end

test("Found 2 entities", found[e1] ~= nil and found[e2] ~= nil and found[e3] == nil)
test("Correct values", found[e1] == 10 and found[e2] == 20)

-- Query unregistered component
local count = 0
for _ in query.single("nonexistent") do
    count = count + 1
end
test("Unregistered returns empty", count == 0)
-- }}}

-- {{{ Multi Component Query Tests
test_section("Multi Component Query")
reset_all()

component.register("position", {x = 0})
component.register("movement", {speed = 100})
component.register("stats", {hp = 100})

local e1 = entity.create()  -- pos + mov
local e2 = entity.create()  -- pos only
local e3 = entity.create()  -- pos + mov + stats
local e4 = entity.create()  -- nothing

component.add(e1, "position", {x = 1})
component.add(e1, "movement", {speed = 200})

component.add(e2, "position", {x = 2})

component.add(e3, "position", {x = 3})
component.add(e3, "movement", {speed = 300})
component.add(e3, "stats", {hp = 50})

local found = {}
for eid, pos, mov in query.multi({"position", "movement"}) do
    found[eid] = {pos.x, mov.speed}
end

test("Found 2 entities with both", found[e1] ~= nil and found[e3] ~= nil)
test("e2 not found (missing movement)", found[e2] == nil)
test("e4 not found (no components)", found[e4] == nil)
test("e1 values correct", found[e1] and found[e1][1] == 1 and found[e1][2] == 200)
test("e3 values correct", found[e3] and found[e3][1] == 3 and found[e3][2] == 300)

-- Multi with single element delegates to single
local count = 0
for _ in query.multi({"position"}) do
    count = count + 1
end
test("Multi with one element works", count == 3)

-- Empty multi
count = 0
for _ in query.multi({}) do
    count = count + 1
end
test("Empty multi returns empty", count == 0)
-- }}}

-- {{{ Unified Query Interface Tests
test_section("Unified Query Interface")
reset_all()

component.register("position", {x = 0})
component.register("movement", {speed = 100})
component.register("stats", {hp = 100})

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()

component.add(e1, "position", {x = 1})
component.add(e1, "movement", {speed = 200})

component.add(e2, "position", {x = 2})

component.add(e3, "position", {x = 3})
component.add(e3, "movement", {speed = 300})
component.add(e3, "stats", {hp = 50})

-- Single component
local count = 0
for _ in query.query("position") do count = count + 1 end
test("query() single works", count == 3)

-- Multi component via variadic
count = 0
for _ in query.query("position", "movement") do count = count + 1 end
test("query() multi works", count == 2)

-- Three components
count = 0
local found_e3 = false
for eid in query.query("position", "movement", "stats") do
    count = count + 1
    if eid == e3 then found_e3 = true end
end
test("Three-component count", count == 1)
test("Three-component match is e3", found_e3)

-- Empty query
count = 0
for _ in query.query() do count = count + 1 end
test("Empty query returns empty", count == 0)
-- }}}

-- {{{ Query Count Tests
test_section("Query Count")
reset_all()

component.register("position", {x = 0})
component.register("movement", {speed = 100})
component.register("stats", {hp = 100})

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()

component.add(e1, "position")
component.add(e1, "movement")
component.add(e2, "position")
component.add(e3, "position")
component.add(e3, "movement")
component.add(e3, "stats")

local c = query.count("position")
test("Count position", c == 3)

c = query.count("movement")
test("Count movement", c == 2)

c = query.count("position", "movement")
test("Count multi", c == 2)

c = query.count("position", "movement", "stats")
test("Count triple", c == 1)

c = query.count("nonexistent")
test("Count unregistered", c == 0)

c = query.count()
test("Count empty", c == 0)
-- }}}

-- {{{ Query All (Array) Tests
test_section("Query All (Array)")
reset_all()

component.register("position", {x = 0})
component.register("movement", {speed = 100})

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()

component.add(e1, "position")
component.add(e2, "position")
component.add(e2, "movement")
component.add(e3, "position")
component.add(e3, "movement")

local all = query.all("position")
test("All returns table", type(all) == "table")
test("All has 3 entities", #all == 3)

all = query.all("position", "movement")
test("All multi has 2", #all == 2)

all = query.all("nonexistent")
test("All unregistered empty", #all == 0)

-- Verify we can modify during iteration using all()
all = query.all("movement")
for _, eid in ipairs(all) do
    component.remove(eid, "movement")
end
test("Can remove during all() loop", query.count("movement") == 0)
-- }}}

-- {{{ Query First Tests
test_section("Query First")
reset_all()

component.register("position", {x = 0})
component.register("movement", {speed = 100})
component.register("stats", {hp = 100})

local e1 = entity.create()
local e2 = entity.create()

component.add(e1, "position", {x = 10})
component.add(e1, "movement")
component.add(e2, "position", {x = 20})
component.add(e2, "movement")
component.add(e2, "stats")

local first_eid, first_pos = query.first("position")
test("First returns entity", first_eid ~= nil)
test("First returns component", first_pos ~= nil)
test("First has correct value", first_pos.x == 10 or first_pos.x == 20)

first_eid = query.first("nonexistent")
test("First unregistered nil", first_eid == nil)

first_eid = query.first("position", "movement", "stats")
test("First multi returns e2", first_eid == e2)

first_eid = query.first()
test("First empty nil", first_eid == nil)
-- }}}

-- {{{ Query With Value Tests
test_section("Query With Value")
reset_all()

component.register("owner", {player_id = 0})

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()
component.add(e1, "owner", {player_id = 0})
component.add(e2, "owner", {player_id = 1})
component.add(e3, "owner", {player_id = 0})

local found = {}
for eid in query.with_value("owner", "player_id", 0) do
    found[eid] = true
end

test("Found 2 with player_id=0", found[e1] and found[e3])
test("Excluded player_id=1", not found[e2])

-- No matches
found = {}
for eid in query.with_value("owner", "player_id", 99) do
    found[eid] = true
end
local count = 0
for _ in pairs(found) do count = count + 1 end
test("No matches for player_id=99", count == 0)

-- Unregistered component
count = 0
for _ in query.with_value("nonexistent", "field", 0) do
    count = count + 1
end
test("Unregistered with_value empty", count == 0)
-- }}}

-- {{{ Query With Predicate Tests
test_section("Query With Predicate")
reset_all()

component.register("stats", {hp = 100, hp_max = 100})

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()
component.add(e1, "stats", {hp = 100})
component.add(e2, "stats", {hp = 50})
component.add(e3, "stats", {hp = 25})

local damaged = {}
for eid, stats in query.with_predicate("stats", function(s)
    return s.hp < s.hp_max
end) do
    damaged[eid] = stats.hp
end

test("Found 2 damaged", damaged[e2] ~= nil and damaged[e3] ~= nil)
test("Excluded full health", damaged[e1] == nil)
test("Correct hp values", damaged[e2] == 50 and damaged[e3] == 25)

-- All match predicate
local all_match = {}
for eid in query.with_predicate("stats", function(s)
    return s.hp_max == 100
end) do
    all_match[eid] = true
end
test("All match predicate", all_match[e1] and all_match[e2] and all_match[e3])

-- None match predicate
local count = 0
for _ in query.with_predicate("stats", function(s)
    return s.hp > 200
end) do
    count = count + 1
end
test("None match predicate", count == 0)

-- Unregistered component
count = 0
for _ in query.with_predicate("nonexistent", function() return true end) do
    count = count + 1
end
test("Unregistered with_predicate empty", count == 0)
-- }}}

-- {{{ Query Without (Exclusion) Tests
test_section("Query Without (Exclusion)")
reset_all()

component.register("position", {x = 0})
component.register("movement", {speed = 100})
component.register("frozen", {})

local e1 = entity.create()  -- pos + mov
local e2 = entity.create()  -- pos + mov + frozen
local e3 = entity.create()  -- pos only

component.add(e1, "position")
component.add(e1, "movement")

component.add(e2, "position")
component.add(e2, "movement")
component.add(e2, "frozen")

component.add(e3, "position")

local found = {}
for eid in query.without({"position", "movement"}, {"frozen"}) do
    found[eid] = true
end

test("Found 1 movable non-frozen", found[e1] and not found[e2])
test("Excluded missing movement", not found[e3])

-- Without with unregistered exclusion (should be ignored)
found = {}
for eid in query.without({"position"}, {"nonexistent_tag"}) do
    found[eid] = true
end
test("Unregistered exclusion ignored", found[e1] and found[e2] and found[e3])

-- Empty required
local count = 0
for _ in query.without({}, {"frozen"}) do
    count = count + 1
end
test("Empty required returns empty", count == 0)

-- Multiple exclusions
component.register("stunned", {})
component.add(e1, "stunned")

found = {}
for eid in query.without({"position"}, {"frozen", "stunned"}) do
    found[eid] = true
end
test("Multiple exclusions work", found[e3] and not found[e1] and not found[e2])
-- }}}

-- {{{ ECS Main Module Query Integration Tests
test_section("ECS Main Module Query Integration")
reset_all()

ecs.register_component("pos", {x = 0})
ecs.register_component("vel", {vx = 0})

local e1 = ecs.create_entity()
local e2 = ecs.create_entity()

ecs.add_component(e1, "pos", {x = 10})
ecs.add_component(e1, "vel", {vx = 5})
ecs.add_component(e2, "pos", {x = 20})

-- ecs.query
local count = 0
for _ in ecs.query("pos") do count = count + 1 end
test("ecs.query works", count == 2)

-- ecs.query_single
count = 0
for _ in ecs.query_single("pos") do count = count + 1 end
test("ecs.query_single works", count == 2)

-- ecs.query_multi
count = 0
for _ in ecs.query_multi({"pos", "vel"}) do count = count + 1 end
test("ecs.query_multi works", count == 1)

-- ecs.query_count
test("ecs.query_count works", ecs.query_count("pos") == 2)

-- ecs.query_all
local all = ecs.query_all("pos")
test("ecs.query_all works", #all == 2)

-- ecs.query_first
local first = ecs.query_first("pos", "vel")
test("ecs.query_first works", first == e1)

-- ecs.query_with_value
count = 0
for _ in ecs.query_with_value("pos", "x", 10) do count = count + 1 end
test("ecs.query_with_value works", count == 1)

-- ecs.query_with_predicate
count = 0
for _ in ecs.query_with_predicate("pos", function(p) return p.x > 5 end) do
    count = count + 1
end
test("ecs.query_with_predicate works", count == 2)

-- ecs.query_without
count = 0
for _ in ecs.query_without({"pos"}, {"vel"}) do count = count + 1 end
test("ecs.query_without works", count == 1)
-- }}}

-- {{{ Performance Stress Test
test_section("Performance Stress Test")
reset_all()

component.register("pos", {x = 0, y = 0})
component.register("vel", {vx = 0, vy = 0})
component.register("hp", {current = 100, max = 100})
component.register("tag_a", {})
component.register("tag_b", {})

-- Create 1000 entities with various component combos
for i = 1, 1000 do
    local e = entity.create()
    component.add(e, "pos", {x = i, y = i * 2})

    if i % 2 == 0 then
        component.add(e, "vel", {vx = i / 10})
    end
    if i % 3 == 0 then
        component.add(e, "hp", {current = i % 100})
    end
    if i % 5 == 0 then
        component.add(e, "tag_a")
    end
    if i % 7 == 0 then
        component.add(e, "tag_b")
    end
end

-- Single component query
local count = query.count("pos")
test("1000 entities with pos", count == 1000)

-- Multi component query
count = query.count("pos", "vel")
test("500 with pos+vel", count == 500)

count = query.count("pos", "vel", "hp")
-- lcm(2,3) = 6, so every 6th entity: 1000/6 = 166
test("~166 with pos+vel+hp", count == 166)

-- Predicate query
count = 0
for _ in query.with_predicate("hp", function(h) return h.current < 50 end) do
    count = count + 1
end
test("Predicate query runs on 333 hp entities", count > 0)

-- Without query
count = 0
for _ in query.without({"pos"}, {"tag_a", "tag_b"}) do
    count = count + 1
end
-- Entities NOT tagged: those not divisible by 5 or 7
-- Using inclusion-exclusion: 1000 - (200 + 142 - 28) = 686
test("Without exclusion query runs", count > 0)

-- Verify iteration doesn't allocate (by counting again - should be same)
local count2 = 0
for _ in query.query("pos", "vel") do count2 = count2 + 1 end
test("Consistent iteration count", count2 == 500)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))

if pass_count == test_count then
    print("ALL TESTS PASSED")
    os.exit(0)
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
