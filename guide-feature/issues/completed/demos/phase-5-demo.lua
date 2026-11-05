-- phase-5-demo.lua - the body of phase-5-demo: looking into the project.
--
-- phase-5-demo makes a throwaway project and runs this in it. This:
--
--   1. makes kuvalu's side here: a monorepo with guide-feature's own code
--      in its guide-feature folder (src/, scripts/, libs/, input/ and the
--      demos, one commit), and builds that commit's embedding index with
--      the builder (src/061-build-embedding-index.lua) and a stand-in
--      embedding model (src/047-stand-in-llama.lua) on 127.0.0.1;
--   2. has the clone keeper (src/058-project-clone.lua) make a voice's clone
--      of it, in RAM if it fits, and copy the index in;
--   3. asks the look tool (src/064-look.lua) one question at focus 1, 0.75,
--      0.5, 0.25 and 0, and shows for each the pieces that came back, a
--      chart of their similarities, and where they sit among all the pieces;
--   4. runs the rehearsal (src/043-rehearsal.lua) with the real turn in all
--      three voices, each with its own stand-in model that looks before it
--      writes (focused one turn, broad the next, none the third), and shows
--      every look the turns' logs record, one answer as the model read it,
--      and where each voice's clone went, RAM or disk, and why.
--
-- usage (phase-5-demo does this):
--   luajit phase-5-demo.lua --dir PROJECT --root THROWAWAY --base FOLDER
--                           [--about WORDS] [--minutes M] [--plain]

-- {{{ arguments
local DIR, ROOT, BASE, PLAIN, MINUTES
local ABOUT = "canvas width"
local index = 1
while index <= #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1]; index = index + 1
    elseif arg[index] == "--root" then ROOT = arg[index + 1]; index = index + 1
    elseif arg[index] == "--base" then BASE = arg[index + 1]; index = index + 1
    elseif arg[index] == "--about" then ABOUT = arg[index + 1]; index = index + 1
    elseif arg[index] == "--minutes" then MINUTES = tonumber(arg[index + 1]); index = index + 1
    elseif arg[index] == "--plain" then PLAIN = true end
    index = index + 1
end
if not (DIR and ROOT and BASE) then
    io.stderr:write("usage: luajit phase-5-demo.lua --dir PROJECT --root THROWAWAY --base FOLDER "
        .. "[--about WORDS] [--minutes M] [--plain]\n")
    os.exit(2)
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int isatty(int fd);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
if not PLAIN and ffi.C.isatty(1) == 0 then PLAIN = true end
if os.getenv("NO_COLOR") and os.getenv("NO_COLOR") ~= "" then PLAIN = true end

local settings = dofile(ROOT .. "/src/001-settings.lua")
local goodbye = dofile(ROOT .. "/src/002-goodbye.lua")
local rehearsal = dofile(ROOT .. "/src/043-rehearsal.lua")
local caller = dofile(ROOT .. "/src/046-model-caller.lua")
local clone = dofile(ROOT .. "/src/058-project-clone.lua")
local builder = dofile(ROOT .. "/src/061-build-embedding-index.lua")
local look = dofile(ROOT .. "/src/064-look.lua")
local json = dofile(ROOT .. "/libs/dkjson.lua")

local MINUTES_RUN = MINUTES or 1
local FOCUSES = { 1, 0.75, 0.5, 0.25, 0 }

-- {{{ small helpers
local function plural(n, one, many) return n .. " " .. (n == 1 and one or many) end
local function say(...) io.write(...) io.write("\n") io.flush() end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body or text, tonumber(status)
end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function fail(text)
    io.stderr:write("phase-5-demo: ", text, "\n")
    os.exit(1)
end
local BLOCK = PLAIN and "#" or "\226\150\136"   -- a full block, U+2588
-- }}}

-- {{{ the stand-in models
-- One embedding model, and one chat model per voice. Each chat model looks
-- before it writes: "look focused" at a voice's first turn, "look broad" at
-- its second, nothing at its third, and so on; then it edits like a voice,
-- one word a turn, from its own words.
local function start(name, kind, replies)
    local folder = ROOT .. "/models/" .. name
    shell("mkdir -p " .. q(folder))
    local command = "luajit " .. q(ROOT .. "/src/047-stand-in-llama.lua") .. " --kind " .. kind
        .. " --dimensions 64 --port-file " .. q(folder .. "/port") .. " --requests "
        .. q(folder .. "/requests") .. " --parent $PPID"
    if replies then
        write(folder .. "/replies", json.encode(replies))
        command = command .. " --replies " .. q(folder .. "/replies")
    end
    shell(command .. " > " .. q(folder .. "/out") .. " 2>&1 &")
    local port
    for _ = 1, 100 do
        port = tonumber((slurp(folder .. "/port") or ""):match("%d+"))
        if port then break end
        sleep(0.05)
    end
    if not port then fail("the stand-in model " .. name .. " did not start") end
    return { name = name, folder = folder, url = "http://127.0.0.1:" .. port }
end
local EMBED = start("stand-in-embed", "embedding")
local VOICE_LOOKS = {
    ["fg-sora-1"] = { focused = "canvas width", broad = "blit rows marks", words = "lantern harbor kitten" },
    ["fg-sora-2"] = { focused = "fit check problems", broad = "turn runner waiting", words = "willow meadow heron" },
    ["fg-sora-3"] = { focused = "endpoint key file", broad = "mailbox outbox", words = "copper ember quarry" },
}
local CHATS = {}
for _, voice in ipairs(rehearsal.VOICES) do
    local plan, replies = VOICE_LOOKS[voice], {}
    for turn = 1, 200 do
        local step = (turn - 1) % 3
        if step == 0 then replies[#replies + 1] = "look focused: " .. plan.focused
        elseif step == 1 then replies[#replies + 1] = "look broad: " .. plan.broad end
        replies[#replies + 1] = { rewrite = plan.words }
    end
    CHATS[voice] = start("stand-in-" .. voice, "chat", replies)
end
local lines = { "# the demo's endpoints: stand-in llama.cpp servers on 127.0.0.1" }
for _, voice in ipairs(rehearsal.VOICES) do
    local name = CHATS[voice].name
    lines[#lines + 1] = name .. '.url = "' .. CHATS[voice].url .. '"'
    lines[#lines + 1] = name .. '.kind = "chat"'
    lines[#lines + 1] = name .. ".timeout = 30"
    lines[#lines + 1] = "use." .. voice .. ' = "' .. name .. '"'
end
lines[#lines + 1] = EMBED.name .. '.url = "' .. EMBED.url .. '"'
lines[#lines + 1] = EMBED.name .. '.kind = "embedding"'
lines[#lines + 1] = EMBED.name .. ".timeout = 30"
lines[#lines + 1] = 'use.embedder = "' .. EMBED.name .. '"'
write(ROOT .. "/endpoints", table.concat(lines, "\n") .. "\n")
-- }}}

-- {{{ kuvalu's checkout, here, and its index
say("Phase 5: looking into the project")
say("")
local TIER = os.getenv("ARTIFACT_TIER_ROOT") or "?"
local TIER_KIND = shell("stat -f -c %T " .. q(TIER))
say(string.format("The RAM tier for this run: %s, %s.", TIER, TIER_KIND == "tmpfs"
    and "a tmpfs, so in memory" or ("a " .. TIER_KIND .. " folder, since no tmpfs could be written")))
say("")
local KUVALU = BASE .. "/kuvalu/ai-stuff"
local PROJECT = KUVALU .. "/guide-feature"
shell("mkdir -p " .. q(PROJECT .. "/issues/completed"))
for _, name in ipairs({ "src", "scripts", "libs", "input" }) do
    shell("cp -rL " .. q(DIR .. "/" .. name) .. " " .. q(PROJECT .. "/" .. name))
end
shell("cp -rL " .. q(DIR .. "/issues/completed/demos") .. " " .. q(PROJECT .. "/issues/completed/demos"))
write(PROJECT .. "/.gitignore", "/.embedding-index*\n")
local _, made = shell("git -C " .. q(KUVALU) .. " init -q && git -C " .. q(KUVALU) .. " add -A && git -C "
    .. q(KUVALU) .. " -c user.name=demo -c user.email=demo@localhost commit -q -m 'guide-feature, as it is'")
if made ~= 0 then fail("cannot make the checkout standing in for kuvalu's at " .. KUVALU) end
local COMMIT = shell("git -C " .. q(KUVALU) .. " rev-parse --short=7 HEAD")
say("kuvalu's side, here: a monorepo at " .. KUVALU .. ", with guide-feature's own code")
say("(src/, scripts/, libs/, input/ and the demos) in its guide-feature folder, at commit " .. COMMIT .. ".")
local ok, built = pcall(builder.build, { root = PROJECT, url = EMBED.url, timeout = 30, log_root = ROOT })
if not ok then fail("the index could not be built: " .. tostring(built)) end
say("Its embedding index, built as on kuvalu by scripts/build-embedding-index:")
say("  " .. builder.describe(built))
say("  (the embedding model is a stand-in on 127.0.0.1: its vectors count shared names, so")
say("   many pieces tie at similarity 0; a real model's similarities spread out)")

-- the voices are sent kuvalu's checkout as the project; their clones come from it
local to_voices_text = slurp(ROOT .. "/input/to-voices")
write(ROOT .. "/input/to-voices", (to_voices_text:gsub("\nproject%-checkout%s*=[^\n]*",
    '\nproject-checkout = "' .. PROJECT .. '"')))
local cloning = slurp(ROOT .. "/input/project-clone")
cloning = cloning:gsub("\nrepository%.guide%-feature%s*=[^\n]*", '\nrepository.guide-feature = "' .. KUVALU .. '"')
write(ROOT .. "/input/project-clone", cloning)
-- }}}

-- {{{ a voice's clone, and one question at five focuses
say("")
local kept
ok, kept = pcall(clone.keep, { root = ROOT, voice = "demo",
    project = { name = "guide-feature", commit = COMMIT } })
if not ok then fail("the clone could not be made: " .. tostring(kept)) end
say("A voice's clone of it, made by the clone keeper:")
say("  " .. clone.describe(kept))
say("  " .. clone.describe_index(kept))

local values = look.read_settings(ROOT)
local counter = { name = "counter", url = CHATS["fg-sora-1"].url, kind = "chat", timeout = 30 }
local embedder = { name = EMBED.name, url = EMBED.url, kind = "embedding", timeout = 30 }
say("")
say(string.format("One question, \"%s\", asked of the look tool at five focuses (input/look: %d",
    ABOUT, values.nearest))
say(string.format("pieces at focus 1, %d at focus 0, reaching (1 - focus)^%g of the way down the ranks,",
    values.spread, values.curve))
say(string.format("up to %d tokens a look, counted by a chat model's tokenizer).", values.budget))
local WIDTH = 60
local answers = {}
for _, focus in ipairs(FOCUSES) do
    local name = focus == values.focused and "focused" or focus == values.broad and "broad" or nil
    local text, info = look.answer({ project = kept.project, commit = kept.full, embedder = embedder,
        words = ABOUT, focus = focus, name = name or string.format("%.2f", focus), values = values,
        count_tokens = function(piece) return caller.count_tokens(counter, piece) end })
    answers[#answers + 1] = { focus = focus, text = text, info = info }
    say("")
    if info.refused then
        say(string.format("focus %.2f: nothing to show: %s", focus, info.why))
    else
        say(string.format("focus %.2f%s: %d of %d pieces, nearest first, %d tokens%s", focus,
            name and (" (look " .. name .. ")") or "", info.pieces, info.count, info.tokens,
            info.left_out > 0 and string.format(", %d more left out by the budget", info.left_out) or ""))
        say(string.format("  %5s  %-10s  %-26s  %s", "rank", "similarity", "", "piece"))
        for _, piece in ipairs(info.shown) do
            local bar = string.rep(BLOCK, math.floor(math.max(0, piece.similarity) * 26 + 0.5))
            say(string.format("  %5d  %10.3f  %s%s  %s %d-%d (%s)", piece.rank, piece.similarity, bar,
                string.rep(" ", 26 - math.floor(math.max(0, piece.similarity) * 26 + 0.5)), piece.file,
                piece.first, piece.last, piece.kind))
        end
        -- where the chosen pieces sit among all of them, nearest on the left
        local strip = {}
        for column = 1, WIDTH do strip[column] = "." end
        for _, piece in ipairs(info.shown) do
            local column = math.floor((piece.rank - 1) * WIDTH / info.count) + 1
            strip[column] = BLOCK
        end
        say(string.format("  ranks 1 to %d:  |%s|", info.count, table.concat(strip)))
    end
end
say("")
say("The answer the model reads, for the focused look (its first lines):")
local shown_lines = 0
for line in string.gmatch(answers[1].text .. "\n", "([^\n]*)\n") do
    shown_lines = shown_lines + 1
    if shown_lines > 24 then
        say("  ...")
        break
    end
    say("  | " .. line)
end
-- }}}

-- {{{ the rehearsal: three voices that look before they write
say("")
say(string.format("Now the rehearsal, for %s minutes, with the real turn in all three voices.",
    MINUTES_RUN))
say("Each voice's model looks before it writes: focused at its first turn, broad at its second,")
say("not at its third, and so on. kuvalu's checkout above is the project they are sent.")
for _, voice in ipairs(rehearsal.VOICES) do
    local plan = VOICE_LOOKS[voice]
    say(string.format("  %s  look focused: %s / look broad: %s", voice, plan.focused, plan.broad))
end

local base = shell("mkdir -p " .. q(ROOT .. "/tmp/shared-memory/rehearsal") .. " && cd "
    .. q(ROOT .. "/tmp/shared-memory/rehearsal") .. " && pwd -P")
local WS_ROOT = base .. "/project/guide-feature"
local WS_SHM = base .. "/shm/guide-feature"
local LOOK_LINE = "^%S+ turn (%d+) on version (%d+), look (%S+) %((.-)%): (.*)$"
local function looks_of(voice, turn)
    local list = {}
    for line in string.gmatch(slurp(WS_SHM .. "/turn-" .. voice .. ".log") or "", "[^\n]+") do
        local number, version, focus, about, rest = line:match(LOOK_LINE)
        if number and (not turn or tonumber(number) == turn) then
            list[#list + 1] = { voice = voice, turn = tonumber(number), version = tonumber(version),
                focus = focus, about = about, rest = rest }
        end
    end
    return list
end
local drawn = 0
local result = rehearsal.run({ root = ROOT, minutes = MINUTES_RUN, keep = true,
    on_version = function(record, voice, b)
        drawn = drawn + 1
        if not voice then
            say(string.format("  version %d: the empty canvas", record.headers.canvas))
            return
        end
        local turn = b.last_turn[voice]
        local found = looks_of(voice, turn)
        local parts = {}
        for _, l in ipairs(found) do
            parts[#parts + 1] = string.format("looked %s (%s): %s", l.focus, l.about,
                (l.rest:gsub(", [%d.]+ seconds$", "")))
        end
        say(string.format("  version %d: %s's turn %d; %s", record.headers.canvas, voice, turn,
            #parts > 0 and table.concat(parts, "; ") or "no look"))
    end })
-- }}}

-- {{{ every look, from the turns' logs
say("")
say("Every look the models made, from the turns' own logs (tmp/shared-memory/turn-<voice>.log)")
say("")
say(string.format("  %-9s %4s %7s  %-7s  %-20s  %s", "voice", "turn", "version", "focus", "about",
    "what came back"))
local all = {}
for _, voice in ipairs(rehearsal.VOICES) do
    for _, l in ipairs(looks_of(voice)) do all[#all + 1] = l end
end
table.sort(all, function(a, b)
    if a.version ~= b.version then return a.version < b.version end
    if a.voice ~= b.voice then return a.voice < b.voice end
    return a.focus > b.focus
end)
for _, l in ipairs(all) do
    say(string.format("  %-9s %4d %7d  %-7s  %-20s  %s", l.voice, l.turn, l.version, l.focus, l.about,
        (l.rest:gsub(", [%d.]+ seconds$", ""))))
end
if #all == 0 then say("  none") end

-- one answer as the model read it, from the requests its stand-in model received
local requests_text = slurp(CHATS["fg-sora-1"].folder .. "/requests") or ""
for line in string.gmatch(requests_text, "[^\n]+") do
    local r = json.decode(line)
    local messages = r and r.body and r.body.messages
    local last = messages and messages[#messages]
    if last and last.role == "user" and last.content:match("^look broad %(") then
        say("")
        say("fg-sora-1's broad look, as its model read it in its next ask (the first lines):")
        local n = 0
        for text_line in string.gmatch(last.content .. "\n", "([^\n]*)\n") do
            n = n + 1
            if n > 16 then say("  ...") break end
            say("  | " .. text_line)
        end
        break
    end
end
-- }}}

-- {{{ each voice's clone, RAM or disk
say("")
say("Each voice's clone of the project, from its first turn's log:")
local CLONE_LINE = "^%S+ turn %d+ on version %d+: project %S+ at %S+: cloned (.-) at (%S+), ([^,]+), because (.*)$"
local INDEX_LINE = "^%S+ turn %d+ on version %d+: (the embedding index .*)$"
for _, voice in ipairs(rehearsal.VOICES) do
    local where, why, size, first_index
    for line in string.gmatch(slurp(WS_SHM .. "/turn-" .. voice .. ".log") or "", "[^\n]+") do
        local place, _, bytes, reason = line:match(CLONE_LINE)
        if place and not where then where, size, why = place, bytes, reason end
        local said = line:match(INDEX_LINE)
        if said and not first_index then first_index = said end
    end
    if where then
        say(string.format("  %s: %s, %s, because %s", voice,
            where:match("^in RAM") and "in RAM" or "on disk", size, (why:gsub("; fetched the commit.*$", ""):gsub(", [%d.]+ seconds$", ""))))
        if first_index then say("    and " .. first_index) end
    else
        say("  " .. voice .. ": no clone made in this run (see its log)")
    end
end
local tier = shell("stat -f -c %T " .. q(base))
say(string.format("  (the RAM tier here is %s, a %s)", base, tier == "tmpfs" and "tmpfs: in memory"
    or (tier .. " folder, since no tmpfs could be written")))
-- }}}

-- {{{ the receipts
say("")
say("The last turn's receipt of each voice, its look and index counts (output/goodbye-turn-<voice>)")
for _, voice in ipairs(rehearsal.VOICES) do
    -- a turn still running has moved the last receipt to .previous
    local path = WS_ROOT .. "/output/goodbye-turn-" .. voice
    local receipt, running = goodbye.read(path), false
    if not receipt then receipt, running = goodbye.read(path .. ".previous"), true end
    if receipt then
        local names = {}
        for name in pairs(receipt.counters) do
            if name:match("^look") or name:match("^index") or name:match("^clone") then
                names[#names + 1] = name
            end
        end
        table.sort(names)
        local parts = {}
        for _, name in ipairs(names) do parts[#parts + 1] = name .. " " .. receipt.counters[name] end
        say("  " .. voice .. ": " .. table.concat(parts, ", ")
            .. (running and " (the turn before the one still running)" or ""))
    else
        say("  " .. voice .. ": none")
    end
end
say("")
local p = result.per
for _, voice in ipairs(rehearsal.VOICES) do
    say(string.format("  %-9s %s received, %s run, %s sent", voice,
        plural(p[voice].received, "canvas", "canvases"), plural(p[voice].turns, "turn", "turns"),
        plural(p[voice].sent, "canvas", "canvases")))
end
say("")
say(string.format("%s, %s read from the turn logs. The workspace's logs and receipts are in "
    .. "tmp/shared-memory/rehearsal/ of the throwaway copy (kept with --keep).",
    plural(drawn, "version", "versions"), plural(#all, "look", "looks")))
-- }}}
