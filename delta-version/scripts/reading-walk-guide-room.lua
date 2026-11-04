#!/usr/bin/env luajit
-- reading-walk-guide-room.lua - Gives a reading-walk guide a room of its own,
-- with the person's consent, and checks that a room's ledgers are in order.
--
-- In plain terms: a guide's record of the walks it led belongs to the guide
-- (issue 065: "the guide explained it a certain way, and they have a right to
-- their words"). This makes a separate system account for one guide -- an
-- account nobody can log into -- and a folder owned by that account that
-- everyone may look into but only the guide may write. It does nothing until
-- the person types "yes": that is the consent step, the person deciding what
-- the machine agrees to. Each guide gets its own account and its own room;
-- there can be as many as the person allows.
--
-- What this does and does not hide: the reader cannot write the room, and the
-- guide's files are encrypted by its own cipher (issue 065f). The machine's
-- administrator (root) can still read and change anything; keeping a room
-- private from the owner is privacy by agreement, unless hardware confidential
-- computing is used, which this does not do.
--
-- Usage:
--   reading-walk-guide-room.lua create <guide-name>            -- show the plan, ask, then make it (uses sudo)
--   reading-walk-guide-room.lua create <guide-name> --dry-run  -- show the plan only
--   reading-walk-guide-room.lua check <room-folder>            -- every ledger rule; exit 1 on any problem
--   reading-walk-guide-room.lua list <room-folder>             -- what the guide made public
--   ... --rooms=PATH    -- where rooms live (default /var/lib/reading-walk-guides)
--   ... --dir=PATH      -- delta-version's home
--
-- See reading-walk-guide-room.info.md and issues/065e-the-guides-room.md.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local ROOMS = "/var/lib/reading-walk-guides"
local DRY_RUN = false
local positional = {}
for _, argument in ipairs(arg) do
    local dir_value = argument:match("^%-%-dir=(.+)$")
    local rooms_value = argument:match("^%-%-rooms=(.+)$")
    -- each option sets one setting; the rest are the command and its target
    if dir_value then DIR = dir_value
    elseif rooms_value then ROOMS = rooms_value
    elseif argument == "--dry-run" then DRY_RUN = true
    else positional[#positional + 1] = argument end
end
local room_library = dofile(DIR .. "/scripts/libs/guide-room.lua")
-- }}}

-- {{{ local function fail()
local function fail(message)
    io.stderr:write("reading-walk-guide-room: ", message, "\n")
    os.exit(1)
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function account_exists()
local function account_exists(account)
    local pipe = io.popen("getent passwd " .. shell_quote(account))
    local found = pipe:read("*l")
    pipe:close()
    return found ~= nil
end
-- }}}

-- {{{ local function create_room()
-- The plan, one command per step, shown in full before anything runs. Each
-- step runs on its own, so a refusal names the step that failed.
local function create_room(guide_name)
    if not guide_name then fail("which guide? usage: create <guide-name>") end
    -- an account name: lower case, starting with a letter, short enough that
    -- "guide-" plus it fits the 32-character limit on account names
    if not guide_name:match("^[a-z][a-z0-9%-]*$") or #guide_name > 24 then
        fail("a guide name is lower-case letters, digits and dashes, starting with a letter, at most 24 long")
    end
    local account = "guide-" .. guide_name
    local room = ROOMS .. "/" .. guide_name
    if account_exists(account) then fail("the account " .. account .. " already exists; its room is " .. room) end

    local steps = {
        { why = "an account for the guide that nobody can log into",
          command = string.format("sudo useradd --system --no-create-home --home-dir %s --shell /usr/bin/nologin %s",
              shell_quote(room), shell_quote(account)) },
        { why = "the folder all rooms live in",
          command = string.format("sudo install -d -m 0755 %s", shell_quote(ROOMS)) },
        { why = "the guide's room: the guide writes, everyone may look",
          command = string.format("sudo install -d -o %s -g %s -m 0755 %s", shell_quote(account), shell_quote(account), shell_quote(room)) },
    }
    for _, ledger in ipairs({ "public", "private", "changes" }) do
        local file = room .. "/" .. room_library.ledger_files[ledger].file
        steps[#steps + 1] = { why = "the empty " .. room_library.ledger_files[ledger].file .. ", the guide's to write",
            command = string.format("sudo install -o %s -g %s -m 0644 /dev/null %s", shell_quote(account), shell_quote(account), shell_quote(file)) }
    end

    io.write("A room for the guide \"", guide_name, "\":\n\n")
    for number, step in ipairs(steps) do
        io.write(string.format("  %d. %s\n     %s\n", number, step.why, step.command))
    end
    io.write("\nThe reader will be able to read the room but not write it. The administrator (root)\n")
    io.write("can still read anything on this machine.\n\n")
    if DRY_RUN then io.write("(dry run: nothing was done)\n") return end

    io.write("Type yes to consent: ")
    io.flush()
    local answer = io.read("*l")
    if answer ~= "yes" then io.write("No consent given; nothing was done.\n") return end
    for number, step in ipairs(steps) do
        local status = os.execute(step.command)
        if status ~= 0 and status ~= true then
            fail(string.format("step %d failed (%s); the steps before it were done and are left in place", number, step.why))
        end
    end
    io.write("The room is ready: ", room, "\n")
end
-- }}}

-- {{{ local function check_room()
local function check_room(room_dir)
    if not room_dir then fail("which room? usage: check <room-folder>") end
    local ok, room = pcall(room_library.open, room_dir)
    if not ok then fail(room) end
    local problems = room_library.check(room)
    if #problems == 0 then io.write("the room's ledgers are in order: ", room_dir, "\n") return end
    for _, text in ipairs(problems) do io.write("  ", text, "\n") end
    io.write(#problems, " problem(s)\n")
    os.exit(1)
end
-- }}}

-- {{{ local function list_room()
local function list_room(room_dir)
    if not room_dir then fail("which room? usage: list <room-folder>") end
    local ok, room = pcall(room_library.open, room_dir)
    if not ok then fail(room) end
    local public = room_library.read(room, "public")
    local kept = room_library.read(room, "private")
    io.write("made public (", #public, "):\n")
    for _, entry in ipairs(public) do io.write("  ", entry.written, "  ", entry.path, "  -- ", entry.note or "", "\n") end
    io.write("kept to itself: ", #kept, " file(s)\n")
end
-- }}}

-- {{{ local function main()
local commands = { create = create_room, check = check_room, list = list_room }
local function main()
    local command = commands[positional[1] or ""]
    if not command then fail("usage: reading-walk-guide-room.lua create <guide-name> [--dry-run] | check <room> | list <room>") end
    command(positional[2])
end
-- }}}

main()
