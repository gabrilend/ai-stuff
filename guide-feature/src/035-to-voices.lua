-- 035-to-voices.lua - each new version, mailed to the voices.
--
-- In plain terms: step 1 of docs/datapath-round-trip.md. A publisher in the
-- blitter's list (016) writes every new version as the body of one living
-- rmail message, outbox/the-canvas in kuvalu's guide mailbox (031), with one
-- `to:` line per voice. kuvalu is its author, so each rewrite travels as an
-- edit, and each voice's inbox/the-canvas always holds the newest version;
-- a voice that was offline is sent only the newest when it is reached. The
-- file is written under a dot name (rmail skips those) and renamed into
-- place, so rmail never reads half a canvas. (issue 303)
--
-- The body is the canvas in its to-voices form (docs/canvas-format.md):
-- headers canvas, size, mode, project, endpoint, written; the rows; the
-- marks; and, when tell-the-voice is on, a `cuts:` section listing each
-- voice's cut words from its latest turn that landed, so every voice gets
-- the same body and reads its own lines. The project's commit is read from
-- its git checkout at every version.
--
--   local to_voices = dofile(DIR .. "/src/035-to-voices.lua")
--   local publisher = to_voices.publisher({ root = DIR, voices = { ... } })
--   blitter.new({ publishers = { blitter.log_publisher, publisher } })
--   to_voices.body(record, settings, commit, cuts)    -- the to-voices text
--   to_voices.message(voices, body)                    -- the outbox file's text
--
-- Settings in input/to-voices. The receipt counts versions-to-voices.
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")

local M = {}
M.SUBJECT = "the-canvas"

-- {{{ M.SETTINGS
-- input/to-voices, read once when the blitter starts.
M.SETTINGS = {
    ["send"]             = { type = "choice", of = { "on", "off" }, required = true },
    ["mailbox"]          = { type = "text", required = true },   -- the guide mailbox's folder
    ["tell-the-voice"]   = { type = "choice", of = { "on", "off" }, required = true },
    ["endpoint"]         = { type = "text", required = true },   -- "name address", until 402
    ["project-checkout"] = { type = "text", required = true },   -- the project's git checkout
}
-- }}}

-- {{{ small helpers
local function quote(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function home(path) return (string.gsub(path, "^~", os.getenv("HOME") or "~")) end
local function fail(text) error("to-voices: " .. text, 0) end

-- The commit a checkout is at, seven hex digits, or nil.
function M.commit_of(checkout)
    local pipe = io.popen("git -C " .. quote(checkout) .. " rev-parse --short=7 HEAD 2>/dev/null")
    local commit = pipe:read("*l")
    pipe:close()
    return commit and string.match(commit, "^%x+$") and commit or nil
end
-- }}}

-- {{{ function M.body()
-- The to-voices text of a version (a for-viewers record from the blitter).
-- `cuts` is nil when tell-the-voice is off, else a list of cut lines.
function M.body(record, values, commit, cuts)
    local endpoint = canvas.HEADERS.endpoint.read(values["endpoint"])
    local copy = {
        set = "to-voices", width = record.width, height = record.height, rows = record.rows,
        marks = record.marks,
        headers = {
            canvas = record.headers.canvas, size = record.headers.size,
            mode = record.headers.mode,
            project = { name = record.headers.project.name, commit = commit },
            endpoint = endpoint, written = record.headers.written,
        },
        cuts = cuts,
    }
    return canvas.write(copy, "to-voices")
end
-- }}}

-- {{{ function M.message()
-- The outbox file: one `to:` line per voice, a blank line, the body.
function M.message(voices, body)
    local lines = {}
    for index, voice in ipairs(voices) do lines[index] = "to: " .. voice end
    return table.concat(lines, "\n") .. "\n\n" .. body
end
-- }}}

-- {{{ function M.publisher()
-- The publisher for the blitter's list, or nil and the reason when
-- input/to-voices says not to send. opts: root, voices (the blitter's
-- voices, each of which must be a contact of the mailbox). Refuses to start
-- when the mailbox or a voice's contact is missing, or the endpoint or
-- checkout cannot be used, rather than send versions nowhere.
function M.publisher(opts)
    local root = opts.root or DIR
    local values = settings.read("to-voices", M.SETTINGS, { root = root })
    if values.send == "off" then
        return nil, "versions are not mailed to the voices (send is off in input/to-voices)"
    end
    if not canvas.HEADERS.endpoint.read(values["endpoint"]) then
        fail("input/to-voices: the endpoint must be a name and an address, like "
            .. "\"voice-small http://192.168.1.100:20166\"; found " .. values["endpoint"])
    end
    local checkout = home(values["project-checkout"])
    if not M.commit_of(checkout) then
        fail("input/to-voices: " .. checkout .. " is not a git checkout, so the project's "
            .. "commit cannot be read for the voices")
    end
    local folder = home(values["mailbox"])
    local contacts = mailboxes.read_contacts(folder .. "/contacts")
    if not contacts then
        fail("there is no mailbox at " .. folder .. " (no contacts file); make it with "
            .. "scripts/make-mailboxes")
    end
    for _, voice in ipairs(opts.voices or {}) do
        if not contacts[voice] then
            fail("the mailbox at " .. folder .. " has no contact called " .. voice
                .. ", so the canvas could not reach it")
        end
    end
    local outbox = folder .. "/outbox"
    os.execute("mkdir -p " .. quote(outbox))

    -- each voice's cuts from its latest turn that landed: { version, list }
    local latest_cuts = {}
    return function(blitter, record, report, voice)
        local version = record.headers.canvas
        if voice and report then
            local list = {}
            for _, cut in ipairs(report.cut or {}) do
                list[#list + 1] = { voice = voice, version = version, row = cut.row,
                                    column = cut.column, text = cut.text }
            end
            latest_cuts[voice] = list
        end
        local cuts
        if values["tell-the-voice"] == "on" then
            cuts = {}
            for _, name in ipairs(blitter.settings.voices) do
                for _, cut in ipairs(latest_cuts[name] or {}) do cuts[#cuts + 1] = cut end
            end
        end
        local commit = M.commit_of(checkout) or record.headers.project.commit
        local text = M.message(blitter.settings.voices, M.body(record, values, commit, cuts))
        local part = outbox .. "/." .. M.SUBJECT .. ".part"
        local handle = assert(io.open(part, "w"))
        handle:write(text)
        handle:close()
        assert(os.rename(part, outbox .. "/" .. M.SUBJECT))
        blitter.run:count("versions-to-voices")
    end
end
-- }}}

return M
