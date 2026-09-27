-- 062-checking-the-center-and-the-loop.lua
--
-- Checks phase 7 (issues 701–704): the center's arithmetic against a hand
-- computation, its determinism, ordering by it, its paragraph reaching every
-- turn; `run` taking a fresh case from source to a delivered design and then
-- to its requests in one command, and doing nothing the second time; and the
-- case viewer — its data, and (under any JavaScript engine that starts) its own script run
-- with a stand-in document, checking that the page's chain check agrees with
-- the machine's head hash and that its center matches the machine's.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local ledger = require("016-ledger")
local center = require("058-the-center")
local running = require("059-running")
local viewer = require("060-the-case-viewer")
local updating = require("055-updating")

-- The arithmetic, by hand: keep 0.97 before each line.
local lines = {
    { seq = 1, kind = "case-opened", about = "-", text = "" },
    { seq = 2, kind = "request-received", about = "wish", text = "" },
    { seq = 3, kind = "graded", about = "wish", text = "middle; touched 201 202; reach 201 202 301" },
    { seq = 4, kind = "build-failed", about = "202", text = "" },
    { seq = 5, kind = "built", about = "201", text = "" },
}
local c = center.compute(lines)
local k = 0.97
kit.check(math.abs(c.weights.wish - 3 * k * k * k) < 1e-9, "the request's weight: 3, kept three times")
kit.check(math.abs(c.weights["202"] - (1 * k * k + 2 * k)) < 1e-9, "202: touched, then failed")
kit.check(math.abs(c.weights["201"] - (1 * k * k + 0.5)) < 1e-9, "201: touched, then built")
kit.equal(c.weights["-"], nil, "nothing weighs '-'")
local again = center.compute(lines)
kit.check(again.weights.wish == c.weights.wish and again.weights["202"] == c.weights["202"], "the same ledger gives the same center")
kit.equal(center.heaviest(c, 1)[1].about, "202", "the failing issue is heaviest")

-- Ordering: a newer request touching a heavy issue goes before an older one.
local waiting = { { name = "old", seq = 10 }, { name = "new", seq = 20 } }
local index = { graded = { new = { text = "surface; touched 202; reach 202" } } }
local ordered = center.order_requests({ weights = { ["202"] = 5, old = 1, new = 0.5 } }, waiting, index)
kit.equal(ordered[1].name, "new", "the request touching the heavy issue goes first")
local tied = center.order_requests({ weights = {} }, waiting, {})
kit.equal(tied[1].name, "old", "ties go to the oldest")
kit.equal(table.concat(center.order_ids({ weights = { ["102"] = 2 } }, { "101", "102", "103" }), " "), "102 101 103",
    "a wave starts with its heaviest issue")
kit.check(center.paragraph(center.compute({}), nil):find("Nothing has been asked", 1, true) ~= nil, "an empty ledger says so")

-- `run`: one command from source to delivered, then the request.
local project, record = kit.fixture_case("run", "with_requests = true")
-- kit.fixture_case surveys the case; `run` must see that and not survey again.
ledger.append(record.ledger, "surveyed", "-", "surveyed by the check kit")
kit.write_file(record.input .. "/count-in-list", fs.read(kit.project.fixtures .. "/tiny-notes-requests/count-in-list/request"))
ledger.append(record.ledger, "request-received", "count-in-list", "noticed")
kit.equal(table.concat(running.waiting_steps(record), " "), "describe build update", "a surveyed case waits for describe, build, update")
local said = {}
local done = running.run(project, record, function(s) said[#said + 1] = s end)
kit.equal(#done, 3, "three steps ran")
local all_ok = true
for _, d in ipairs(done) do if not d.ok then all_ok = false end end
kit.check(all_ok, "all finished")
local idx = ledger.index(ledger.read(record.ledger))
kit.check(ledger.has(idx, "delivered", "-") and ledger.has(idx, "request-done", "count-in-list"), "delivered, and the request done")
kit.equal(#running.waiting_steps(record), 0, "then nothing waits")
kit.check(fs.exists(record.folder .. "/center.txt"), "the center's view is written")
local lines_before = #ledger.read(record.ledger)
running.run(project, record, function() end)
kit.equal(#ledger.read(record.ledger), lines_before, "a second run changes nothing")

-- The center's paragraph reaches every turn.
local newest_instructions
for _, name in ipairs(fs.list(record.turns)) do
    if name:match("%-build%-301$") then newest_instructions = record.turns .. "/" .. name .. "/instructions.md" end
end
kit.check(newest_instructions and fs.read(newest_instructions):find("What the person has been attending to", 1, true) ~= nil,
    "a build turn's instructions carry the center's paragraph")

-- A held request is the person's, not run's.
kit.write_file(record.input .. "/file-header", fs.read(kit.project.fixtures .. "/tiny-notes-requests/file-header/request"))
ledger.append(record.ledger, "request-received", "file-header", "noticed")
running.run(project, record, function() end)
kit.check(ledger.has(ledger.index(ledger.read(record.ledger)), "held", "file-header"), "a foundation request is held by run")
kit.equal(#running.waiting_steps(record), 0, "and run then leaves it to the person")
kit.equal(#updating.waiting(ledger.read(record.ledger)), 1, "though it still waits for --go")

-- The viewer: its data.
local path, data = viewer.write(record)
local html = fs.read(path)
kit.check(html:find(ledger.head(record.ledger), 1, true) ~= nil, "the page carries the machine's head hash")
for _, id in ipairs({ "101", "102", "103", "201", "202", "301" }) do
    kit.check(data.issues[id] ~= nil and html:find('"' .. id .. '"', 1, true) ~= nil, "the page carries issue " .. id)
end
kit.equal(#data.raw_ledger, #ledger.read(record.ledger), "every ledger line is in the page")
kit.equal(data.issues["301"].state, "built", "states come from the ledger")
kit.check(not html:find("</script>", html:find("const DATA", 1, true), true) or
    html:find("</script>", html:find("const DATA", 1, true), true) > html:find("// The ledger itself.", 1, true),
    "no ledger text can close the page's script early")

-- The viewer: its own script, run outside a browser with a stand-in
-- document. Any JavaScript engine that starts will do: node, or gjs (the
-- GNOME engine) — on the machine this was written on, node is installed but
-- cannot start (a system library mismatch), so the check names the engine
-- it used rather than quietly using whichever answered.
-- {{{ local function javascript_engine
local function javascript_engine()
    for _, engine in ipairs({ "node", "gjs" }) do
        if fs.run("command -v " .. engine .. " > /dev/null && " .. engine .. " --version > /dev/null 2>&1") then
            return engine
        end
    end
    return nil
end
-- }}}
local engine = javascript_engine()
if engine then
    io.write("  (the page's script runs under " .. engine .. ")\n")
    local script = html:match("<script>\n(.-)</script>")
    local folder = kit.scratch("viewer")
    local STUB = [[
const say = (typeof print === "function") ? print : console.log;
if (typeof TextEncoder === "undefined") {
  globalThis.TextEncoder = class { encode(s) {
    const out = [];
    for (const ch of s) { let c = ch.codePointAt(0);
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63)); }
    return new Uint8Array(out); } };
}
function fake(id) {
  return { id, children: [], textContent: "", style: {}, classList: { add() {}, remove() {} },
    append(...xs) { for (const x of xs) this.children.push(x); } };
}
const byId = {};
globalThis.document = {
  getElementById(id) { return byId[id] || (byId[id] = fake(id)); },
  createElement(tag) { return fake(tag); },
  createTextNode(t) { return { textContent: t }; },
};
]]
    local REPORT = [[
say(JSON.stringify({ agree: firstBad === null && pageHead === DATA.machine_head, firstBad, center: centerAt(parsed.length) }));
]]
    kit.write_file(folder .. "/page.js", STUB .. script .. REPORT)
    local out, ok = fs.capture(engine .. " " .. fs.quote(folder .. "/page.js") .. " 2>&1")
    kit.check(ok and out:find('"agree":true', 1, true) ~= nil, "the page's own chain check agrees with the machine: " .. out:sub(1, 200))
    local machine_top = center.heaviest(center.compute(ledger.read(record.ledger)), 1)[1]
    local page_top_name, page_top_weight = out:match('"center":%[%["([^"]+)",([%d%.e%-]+)')
    kit.check(page_top_name == machine_top.about and math.abs(tonumber(page_top_weight) - machine_top.weight) < 1e-9,
        "the page's center matches the machine's heaviest (" .. machine_top.about .. ")")
    -- A tampered page: one character of ledger line 2's text changed inside
    -- the page (line 2 is the check's own "surveyed by the check kit").
    local whole = STUB .. script .. REPORT
    local at = whole:find("surveyed by the check kit", 1, true)
    kit.check(at ~= nil, "line 2's text is in the page")
    local tampered = whole:sub(1, at - 1) .. "S" .. whole:sub(at + 1)
    kit.write_file(folder .. "/tampered.js", tampered)
    local out2 = fs.capture(engine .. " " .. fs.quote(folder .. "/tampered.js") .. " 2>&1")
    kit.check(out2:find('"firstBad":2', 1, true) ~= nil, "a page with line 2 tampered finds line 2: " .. out2:sub(1, 120))
else
    kit.check(false, "no JavaScript engine starts here (tried node, gjs): the page's own script could not be checked")
end

kit.finish()
