-- 060-the-case-viewer.lua
--
-- A case as one HTML page: the viewing side of everything, built from the
-- case folder alone (the survey's tables, the outline, the issue files, the
-- ledger) and never from the source. The page is self-contained — inline
-- style and script, no outside requests — so it opens from the disk in any
-- browser, and keeps working if the case folder moves.
--
-- What the page does for itself, in its own script:
--   * checks the ledger's chain, line by line, with its own SHA-256, and
--     shows its head hash beside the one the machine wrote in, so a reader
--     does not have to trust the machine's word;
--   * recomputes the center at any point in the ledger (a slider), with the
--     same keep factor and weights as src/058-the-center.lua, handed over as
--     data;
--   * highlights a request's touched issues and reach on the graph when the
--     request is pointed at, and shows an issue's text when it is clicked.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local graph = require("043-the-graph")
local issue_files = require("044-issue-files")
local summary = require("030-the-survey-summary")
local center = require("058-the-center")

local viewer = {}

-- {{{ local function json
-- A small JSON writer: strings, numbers, booleans, arrays (tables with
-- 1..n) and objects (other tables, keys sorted so the page is the same
-- bytes for the same case).
local json
local function json_string(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
        return map[c] or string.format("\\u%04x", c:byte())
    end):gsub("</", "<\\/") .. '"'
end
function json(v)
    local t = type(v)
    if t == "string" then return json_string(v) end
    if t == "number" then return string.format("%.17g", v) end
    if t == "boolean" then return tostring(v) end
    if t == "nil" then return "null" end
    if #v > 0 or next(v) == nil then
        local parts = {}
        for i, x in ipairs(v) do parts[i] = json(x) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for i, k in ipairs(keys) do parts[i] = json_string(k) .. ":" .. json(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
-- }}}

-- {{{ local function gather
-- Everything the page shows, as plain data.
local function gather(record)
    local lines = ledger.read(record.ledger)
    local index = ledger.index(lines)
    local data = {
        name = record.name, source = record.source, harness = record.harness,
        target = record.target or "", hold = record.hold or "foundation",
        balance = center.BALANCE, issues = {}, levels = {}, requests = {},
        raw_ledger = {}, survey = nil,
    }
    for line in io.lines(record.ledger) do
        data.raw_ledger[#data.raw_ledger + 1] = line
    end
    data.machine_head = lines[#lines] and lines[#lines].hash or ""
    if fs.exists(record.survey .. "/files.tsv") then
        local s = summary.compute(record.survey)
        data.survey = {
            totals = s.totals, languages = s.by_language, foundations = s.foundations,
            entry_points = s.entry_points, outside = #s.outside,
        }
    end
    local outline_path = record.blueprint .. "/outline.tsv"
    if fs.exists(outline_path) then
        local g = graph.build((text_tables.read(outline_path)))
        -- An issue's state: the latest of what the ledger says happened to it.
        local failed = {}
        for _, id in ipairs(g.ids) do
            local state = "planned"
            if ledger.has(index, "described", id) then state = "described" end
            if ledger.has(index, "describe-failed", id) then state = "failed"; failed[#failed + 1] = id end
            if ledger.has(index, "built", id) then state = "built" end
            if ledger.has(index, "build-failed", id) and index["build-failed"][id].seq > (index.built and index.built[id] and index.built[id].seq or 0) then
                state = "failed"; failed[#failed + 1] = id
            end
            local path = issue_files.find(record.issues, id)
            data.issues[id] = {
                id = id, name = g.nodes[id].name, level = g.nodes[id].level,
                blocked_by = g.nodes[id].blocked_by, state = state,
                text = path and fs.read(path) or "(no file yet)",
            }
        end
        for _, id in ipairs(graph.reach(g, failed)) do
            if data.issues[id].state ~= "failed" then data.issues[id].state = "held" end
        end
        data.levels = graph.levels(g)
        for _, l in ipairs(lines) do
            if l.kind == "request-received" and not data.requests[l.about] then
                data.requests[l.about] = { name = l.about, seq = l.seq, state = "waiting", touched = {}, reach = {} }
            end
        end
        for name, r in pairs(data.requests) do
            local graded = index.graded and index.graded[name]
            if graded then
                r.grade = graded.text:match("^(%a+);")
                for id in (graded.text:match("touched ([^;]*)") or ""):gmatch("%d%d%d") do r.touched[#r.touched + 1] = id end
                for id in (graded.text:match("reach ([^;]*)") or ""):gmatch("%d%d%d") do r.reach[#r.reach + 1] = id end
            end
            if ledger.has(index, "held", name) then r.state = "held" end
            if ledger.has(index, "request-done", name) then r.state = "done" end
            if ledger.has(index, "request-failed", name) then r.state = "failed" end
            local path = record.input .. "/" .. name
            r.words = fs.exists(path) and fs.read(path) or ""
        end
    end
    local list = {}
    for _, r in pairs(data.requests) do list[#list + 1] = r end
    table.sort(list, function(a, b) return a.seq < b.seq end)
    data.requests = list
    return data
end
-- }}}

local PAGE = [==[<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Case {{NAME}}</title>
<style>
:root {
  --paper: #f7f5f0; --ink: #1d1b18; --faint: #6f6a61; --rule: #d9d4c8; --card: #ffffff;
  --built: #2f7d4f; --described: #3b6ea8; --failed: #b3322b; --held: #b07a14; --planned: #8a857b;
  --reach: #e9b949; --touch: #b3322b; --bar: #3b6ea8;
}
@media (prefers-color-scheme: dark) {
  :root {
    --paper: #16171a; --ink: #e9e6df; --faint: #9a958b; --rule: #34363b; --card: #1f2125;
    --built: #5fbf85; --described: #7aa9e0; --failed: #ef6b62; --held: #e2ad45; --planned: #8f8a80;
    --reach: #e2ad45; --touch: #ef6b62; --bar: #7aa9e0;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--paper); color: var(--ink); font: 15px/1.5 "DejaVu Sans Mono", ui-monospace, monospace; }
main { max-width: 1100px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 22px; margin: 0 0 4px; } h2 { font-size: 16px; margin: 32px 0 10px; border-bottom: 1px solid var(--rule); padding-bottom: 4px; }
.faint { color: var(--faint); } .ok { color: var(--built); } .bad { color: var(--failed); }
.row { display: flex; gap: 12px; flex-wrap: wrap; }
.card { background: var(--card); border: 1px solid var(--rule); border-radius: 6px; padding: 10px 12px; }
.bars div { display: grid; grid-template-columns: 11em 1fr 5em; gap: 8px; align-items: center; margin: 3px 0; }
.bar { height: 12px; background: var(--bar); border-radius: 2px; }
.levels { display: flex; gap: 14px; overflow-x: auto; padding-bottom: 6px; }
.level { min-width: 190px; } .level > .faint { margin-bottom: 6px; }
.issue { border: 2px solid var(--rule); border-left: 8px solid var(--planned); border-radius: 5px; padding: 6px 8px; margin: 0 0 8px; background: var(--card); cursor: pointer; }
.issue.built { border-left-color: var(--built); } .issue.described { border-left-color: var(--described); }
.issue.failed { border-left-color: var(--failed); } .issue.held { border-left-color: var(--held); }
.issue.touch { border-color: var(--touch); } .issue.reach { border-color: var(--reach); }
.issue .on { font-size: 12px; color: var(--faint); }
.legend span { margin-right: 14px; } .dot { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 4px; vertical-align: middle; }
pre { white-space: pre-wrap; word-break: break-word; margin: 0; font: 13px/1.45 inherit; }
#issue-text { max-height: 420px; overflow: auto; }
.request { cursor: default; margin-bottom: 8px; }
.chip { display: inline-block; padding: 0 6px; border-radius: 3px; border: 1px solid var(--rule); font-size: 12px; margin-left: 6px; }
table { border-collapse: collapse; width: 100%; font-size: 12.5px; } td, th { text-align: left; padding: 2px 6px; border-bottom: 1px solid var(--rule); vertical-align: top; }
td.hash { color: var(--faint); } tr.broken td { color: var(--failed); }
.ledger-wrap { max-height: 480px; overflow: auto; }
input[type=range] { width: 100%; }
</style>
</head>
<body>
<main>
<h1>Case {{NAME}}</h1>
<div class="faint" id="about"></div>

<h2>The ledger's fingerprint</h2>
<div class="card" id="chain"></div>

<h2>The survey</h2>
<div class="row" id="survey"></div>

<h2>The blueprint, level by level</h2>
<div class="legend faint" id="legend"></div>
<div class="levels" id="levels"></div>
<div class="card" id="issue-text"><span class="faint">Click an issue to read it.</span></div>

<h2>Requests</h2>
<div id="requests"></div>

<h2>The center</h2>
<div class="faint">What the machine attends to first, recomputed here from the ledger alone. Slide back through the ledger to watch it move.</div>
<input type="range" id="slider" min="1" value="1">
<div class="faint" id="slider-label"></div>
<div class="bars card" id="center"></div>

<h2>The ledger</h2>
<div class="ledger-wrap card"><table id="ledger"></table></div>
</main>
<script>
const DATA = {{DATA}};

// SHA-256, so the page checks the chain itself (FIPS 180-4).
function sha256(text) {
  const bytes = new TextEncoder().encode(text);
  const K = [0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  const H = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19];
  const len = bytes.length, total = ((len + 9 + 63) >> 6) << 6, m = new Uint8Array(total);
  m.set(bytes); m[len] = 0x80;
  const bits = len * 8;
  for (let i = 0; i < 8; i++) m[total - 1 - i] = Math.floor(bits / Math.pow(2, 8 * i)) & 0xff;
  const W = new Uint32Array(64), r = (x, n) => (x >>> n) | (x << (32 - n));
  for (let o = 0; o < total; o += 64) {
    for (let i = 0; i < 16; i++) W[i] = (m[o+4*i] << 24) | (m[o+4*i+1] << 16) | (m[o+4*i+2] << 8) | m[o+4*i+3];
    for (let i = 16; i < 64; i++) {
      const s0 = r(W[i-15],7) ^ r(W[i-15],18) ^ (W[i-15] >>> 3), s1 = r(W[i-2],17) ^ r(W[i-2],19) ^ (W[i-2] >>> 10);
      W[i] = (W[i-16] + s0 + W[i-7] + s1) | 0;
    }
    let [a,b,c,d,e,f,g,h] = H;
    for (let i = 0; i < 64; i++) {
      const t1 = (h + (r(e,6) ^ r(e,11) ^ r(e,25)) + ((e & f) ^ (~e & g)) + K[i] + W[i]) | 0;
      const t2 = ((r(a,2) ^ r(a,13) ^ r(a,22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
      h = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
    }
    H[0]=(H[0]+a)|0; H[1]=(H[1]+b)|0; H[2]=(H[2]+c)|0; H[3]=(H[3]+d)|0; H[4]=(H[4]+e)|0; H[5]=(H[5]+f)|0; H[6]=(H[6]+g)|0; H[7]=(H[7]+h)|0;
  }
  return H.map(x => (x >>> 0).toString(16).padStart(8, "0")).join("");
}
function unescape(field) { return field.replace(/\\(.)/g, (_, c) => ({ t: "\t", n: "\n", r: "\r", "\\": "\\" })[c]); }
function el(tag, attrs, text) { const e = document.createElement(tag); Object.assign(e, attrs || {}); if (text !== undefined) e.textContent = text; return e; }

// The ledger, checked line by line exactly as the machine checks it.
const lines = DATA.raw_ledger.map(raw => raw.split("\t"));
let prev = "0".repeat(64), firstBad = null;
const parsed = lines.map((f, i) => {
  const own = sha256(f.slice(0, 6).join("\t"));
  const ok = f.length === 7 && Number(f[0]) === i + 1 && f[5] === prev && own === f[6];
  if (!ok && firstBad === null) firstBad = i + 1;
  prev = f[6];
  return { seq: Number(f[0]), time: f[1], kind: unescape(f[2]), about: unescape(f[3]), text: unescape(f[4]), hash: f[6], ok };
});
const pageHead = parsed.length ? parsed[parsed.length - 1].hash : "";
const chain = document.getElementById("chain");
chain.append(el("div", {}, "machine's head hash:  " + DATA.machine_head));
chain.append(el("div", {}, "page's own check:     " + (firstBad === null ? "every line of " + parsed.length + " verified, head " + pageHead : "BROKEN at line " + firstBad)));
chain.append(el("div", { className: firstBad === null && pageHead === DATA.machine_head ? "ok" : "bad" },
  firstBad === null && pageHead === DATA.machine_head ? "they agree" : "they do not agree"));

document.getElementById("about").textContent = "source " + DATA.source + " · harness " + DATA.harness +
  " · hold " + DATA.hold + (DATA.target ? " · target: " + DATA.target : "");

// The survey.
const survey = document.getElementById("survey");
if (DATA.survey) {
  const t = DATA.survey.totals, card = el("div", { className: "card bars", style: "flex: 2; min-width: 300px" });
  card.append(el("div", { className: "faint" }, t.files + " files · " + t.lines + " lines · " + t.links_inside + " links inside · " + t.links_outside + " outside"));
  const most = Math.max(...DATA.survey.languages.map(l => l.lines), 1);
  for (const l of DATA.survey.languages) {
    const row = el("div"); row.append(el("span", {}, l.name));
    const bar = el("div", { className: "bar" }); bar.style.width = (100 * l.lines / most) + "%"; row.append(bar);
    row.append(el("span", { className: "faint" }, l.lines + " lines")); card.append(row);
  }
  survey.append(card);
  const side = el("div", { className: "card", style: "flex: 1; min-width: 220px" });
  side.append(el("div", { className: "faint" }, "most leaned on"));
  for (const f of DATA.survey.foundations.slice(0, 6)) side.append(el("div", {}, f.included_by + "  " + f.path));
  side.append(el("div", { className: "faint", style: "margin-top: 8px" }, "entry points: " + DATA.survey.entry_points.length + " · outside dependencies: " + DATA.survey.outside));
  survey.append(side);
} else survey.append(el("div", { className: "faint" }, "not surveyed yet"));

// The graph.
const legend = document.getElementById("legend");
for (const s of ["built", "described", "planned", "failed", "held"]) {
  const span = el("span"); const dot = el("span", { className: "dot" }); dot.style.background = "var(--" + s + ")";
  span.append(dot, document.createTextNode(s)); legend.append(span);
}
const boxes = {};
const levels = document.getElementById("levels");
DATA.levels.forEach((ids, i) => {
  const col = el("div", { className: "level" }); col.append(el("div", { className: "faint" }, "level " + i));
  for (const id of ids) {
    const issue = DATA.issues[id];
    const box = el("div", { className: "issue " + issue.state, title: issue.state });
    box.append(el("div", {}, id + " " + issue.name));
    box.append(el("div", { className: "on" }, issue.blocked_by.length ? "← " + issue.blocked_by.join(" ") : "foundation"));
    box.onclick = () => { const t = document.getElementById("issue-text"); t.textContent = ""; t.append(el("pre", {}, issue.text)); };
    boxes[id] = box; col.append(box);
  }
  levels.append(col);
});
if (!DATA.levels.length) levels.append(el("div", { className: "faint" }, "no blueprint yet"));

// Requests: pointing at one lights its touched issues and its reach.
const requests = document.getElementById("requests");
for (const r of DATA.requests) {
  const card = el("div", { className: "card request" });
  const head = el("div", {}, r.name); head.append(el("span", { className: "chip" }, r.grade || "not graded"));
  head.append(el("span", { className: "chip" }, r.state)); card.append(head);
  card.append(el("div", { className: "faint" }, r.words.trim()));
  if (r.reach.length) card.append(el("div", { className: "faint" }, "touches " + r.touched.join(" ") + " · rebuilds " + r.reach.join(" ")));
  card.onmouseenter = () => { for (const id of r.reach) boxes[id] && boxes[id].classList.add("reach"); for (const id of r.touched) boxes[id] && boxes[id].classList.add("touch"); };
  card.onmouseleave = () => { for (const b of Object.values(boxes)) b.classList.remove("reach", "touch"); };
  requests.append(card);
}
if (!DATA.requests.length) requests.append(el("div", { className: "faint" }, "no requests yet"));

// The center, recomputed at any ledger line with the machine's own numbers.
function centerAt(n) {
  const w = {}, last = {}, B = DATA.balance;
  for (let i = 0; i < n; i++) {
    const l = parsed[i];
    for (const k in w) w[k] *= B.keep;
    const add = B.weights[l.kind];
    if (add && l.about !== "-") { w[l.about] = (w[l.about] || 0) + add; last[l.about] = l.kind; }
    if (l.kind === "graded") {
      const m = l.text.match(/touched ([^;]*)/);
      for (const id of (m ? m[1].match(/\d{3}/g) || [] : [])) { w[id] = (w[id] || 0) + B.graded_per_issue; last[id] = "graded"; }
    }
  }
  return Object.entries(w).sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).slice(0, 10).map(([k, v]) => [k, v, last[k]]);
}
const slider = document.getElementById("slider"), centerBox = document.getElementById("center");
slider.max = parsed.length; slider.value = parsed.length;
function drawCenter() {
  const n = Number(slider.value), top = centerAt(n);
  document.getElementById("slider-label").textContent = "after ledger line " + n + " of " + parsed.length + (parsed[n - 1] ? " (" + parsed[n - 1].kind + " " + parsed[n - 1].about + ")" : "");
  centerBox.textContent = "";
  const most = top.length ? top[0][1] : 1;
  for (const [about, weight, why] of top) {
    const row = el("div"); const name = DATA.issues[about] ? about + " " + DATA.issues[about].name : about;
    row.append(el("span", { title: why || "" }, name.slice(0, 22)));
    const bar = el("div", { className: "bar" }); bar.style.width = (100 * weight / most) + "%"; row.append(bar);
    row.append(el("span", { className: "faint" }, weight.toFixed(2))); centerBox.append(row);
  }
  if (!top.length) centerBox.append(el("div", { className: "faint" }, "nothing weighs anything yet"));
}
slider.oninput = drawCenter; drawCenter();

// The ledger itself.
const table = document.getElementById("ledger");
const header = el("tr"); for (const h of ["#", "time", "kind", "about", "text", "hash"]) header.append(el("th", {}, h)); table.append(header);
for (const l of parsed) {
  const tr = el("tr", { className: l.ok ? "" : "broken" });
  for (const v of [l.seq, l.time, l.kind, l.about, l.text]) tr.append(el("td", {}, String(v)));
  tr.append(el("td", { className: "hash" }, l.hash.slice(0, 12) + "…" + (l.ok ? "" : " ✗")));
  table.append(tr);
}
</script>
</body>
</html>
]==]

-- {{{ function viewer.write
-- Writes cases/<case>/view.html; returns its path.
function viewer.write(record)
    local data = gather(record)
    local html = PAGE:gsub("{{NAME}}", function() return (record.name:gsub("[<>&\"]", "")) end)
        :gsub("{{DATA}}", function() return json(data) end)
    local path = record.folder .. "/view.html"
    fs.write(path, html)
    return path, data
end
-- }}}

viewer.json = json

return viewer
