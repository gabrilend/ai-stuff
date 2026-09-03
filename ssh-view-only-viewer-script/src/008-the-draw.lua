-- 008-the-draw.lua
--
-- Hands out one file at a time, chosen at random, from a directory a
-- person has decided to lend.  It is asked "give me something for this
-- viewer" and answers with a path, or with a refusal saying the well ran
-- dry.  It never learns who the viewer is beyond a name, never reads the
-- file it names, and never returns anything from outside the one folder
-- it was pointed at.  Both halves of this project ask it the same
-- question; neither can tell the other has been asking.
--
-- LuaJIT (5.1) syntax.  No 5.4 constructs.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if arg and arg[1] then DIR = arg[1] end

local draw = {}

-- {{{ local function shell_quote()
-- Every path this module hands to a subprocess goes through here first.
-- Single-quoting is the only form the shell will not re-interpret, and
-- an embedded single quote is closed, escaped, and reopened.  Paths in a
-- lent corpus are attacker-adjacent by definition -- the person choosing
-- filenames is not necessarily the person running this.
local function shell_quote(text)
    if type(text) ~= "string" then
        error("shell_quote: expected a string, got " .. type(text))
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function read_command()
-- Runs one read-only command and returns its whole output.  Commands are
-- never chained here; each call is a single program, so a failure is
-- attributable to exactly one thing.
local function read_command(command)
    local pipe = io.popen(command, "r")
    if not pipe then
        error("could not run: " .. command)
    end
    local output = pipe:read("*a")
    pipe:close()
    return output
end
-- }}}

-- {{{ local function resolve()
-- Turns any path into its real, absolute, symlink-free form.
--
-- This is deliberately the operating system's answer rather than string
-- arithmetic of our own.  Normalising "a/../b" by hand is easy; deciding
-- what "a/../b" means when "a" is a symlink into another filesystem is
-- not, and getting it wrong is precisely how a corpus boundary leaks.
--
-- The flag is -e, not -f, and the difference is the whole point.  Both
-- resolve symlinks in every component; -f additionally *succeeds* when
-- only the final component is missing, handing back a path to a file
-- that is not there.  That made a never-written filename inside the
-- corpus resolve cleanly and test as "inside" -- a name the corpus does
-- not contain, reported as lendable.  -e requires every component to
-- exist, so a missing file resolves to nothing and is refused.
--
-- Returns nil when the path does not exist.  A caller that treats a
-- missing path as "outside the corpus" is correct; one that treats it as
-- "inside" is the bug this function exists to prevent.
local function resolve(path)
    local output = read_command("readlink -e -- " .. shell_quote(path))
    local resolved = output:gsub("%s+$", "")
    if resolved == "" then return nil end
    return resolved
end
-- }}}

-- {{{ function draw.is_under()
-- Answers whether a path genuinely lives beneath a root, after both have
-- been resolved.  This is the whole security boundary of the project.
--
-- The comparison appends a separator to the root before testing the
-- prefix.  Without that, "/srv/lend" would appear to contain
-- "/srv/lending-secrets" -- a sibling directory that merely shares a
-- prefix as a string.  That is the failure this trailing slash exists to
-- prevent, and it is why the test is not a plain string.find.
--
-- The root itself is not under itself.  Handing out a directory is not a
-- thing this project does, so the equal case answers false.
function draw.is_under(root, path)
    local real_root = resolve(root)
    local real_path = resolve(path)

    -- Either side failing to resolve means something was removed or was
    -- never there.  Refusing is the only safe reading: an unresolvable
    -- path cannot be shown to be inside, so it is treated as outside.
    if not real_root then return false end
    if not real_path then return false end

    if real_root:sub(-1) ~= "/" then real_root = real_root .. "/" end
    return real_path:sub(1, #real_root) == real_root
end
-- }}}

-- {{{ local function random_below()
-- A uniform integer in [1, ceiling], seeded from the kernel rather than
-- from the clock.
--
-- os.time() has one-second resolution, so two viewers served in the same
-- second would otherwise be handed the same file from the same seed.
-- /dev/urandom has no such structure.  Four bytes is far more entropy
-- than a corpus-sized range needs; the excess costs nothing.
local function random_below(ceiling)
    if ceiling < 1 then
        error("random_below: ceiling must be at least 1, got " .. tostring(ceiling))
    end

    local source = io.open("/dev/urandom", "rb")
    if not source then
        error("cannot open /dev/urandom -- refusing to fall back to a clock seed")
    end
    local bytes = source:read(4)
    source:close()

    if not bytes or #bytes < 4 then
        error("short read from /dev/urandom -- refusing to proceed with partial entropy")
    end

    local value = 0
    for index = 1, 4 do
        value = value * 256 + bytes:byte(index)
    end

    return (value % ceiling) + 1
end
-- }}}

-- {{{ function draw.build_roll()
-- Walks the corpus once and returns the list of candidate files.
--
-- Each entry is a table: path (absolute, resolved), size (bytes), drawn
-- (times handed out, starts at 0), last (unix seconds of most recent
-- draw, starts at 0).
--
-- find is asked for regular files only, following symlinks, and every
-- result is then re-checked against the boundary.  Following links and
-- then checking is deliberate: a link pointing out of the corpus is a
-- thing we want to notice and say aloud, not a thing we want to silently
-- not-follow.  It is the boundary being probed, whether by accident or
-- not, and silence would make it look like the file simply was not there.
function draw.build_roll(corpus_root)
    local real_root = resolve(corpus_root)
    if not real_root then
        error("corpus root does not exist: " .. tostring(corpus_root))
    end

    local listing = read_command(
        "find -L " .. shell_quote(real_root) .. " -type f -printf '%s\\t%p\\n'")

    local roll = {}
    local escaped = {}

    for line in listing:gmatch("[^\n]+") do
        local size, path = line:match("^(%d+)\t(.+)$")
        if size and path then
            if draw.is_under(real_root, path) then
                roll[#roll + 1] = {
                    path  = resolve(path),
                    size  = tonumber(size),
                    drawn = 0,
                    last  = 0,
                }
            else
                -- Reported, never silently dropped.  A link out of the
                -- corpus is the one event this module exists to catch.
                escaped[#escaped + 1] = path
            end
        end
    end

    return roll, escaped
end
-- }}}

-- {{{ function draw.pick()
-- Chooses one entry for a viewer, or explains why it cannot.
--
-- Two filters run before the choice:
--
--   already held -- this viewer has been given this file before.  Keeps
--                   a viewer who deletes repeatedly from being handed
--                   the same thing twice, which would read as the system
--                   being broken rather than as chance.
--
--   ceiling      -- this file has been handed out this many times across
--                   all viewers.  This is the rate bound: without it, a
--                   viewer whose only verb is delete eventually receives
--                   the entire corpus, and a random sampler has quietly
--                   become a slow complete copy.
--
-- Returns the entry on success.  Returns nil plus a reason string when
-- there is nothing to give -- which is a correct outcome, not a failure,
-- and callers are expected to tell the viewer the well ran dry rather
-- than to retry.
function draw.pick(roll, held, ceiling)
    if type(roll) ~= "table" then
        error("pick: roll must be a table, got " .. type(roll))
    end
    if type(held) ~= "table" then
        error("pick: held must be a table, got " .. type(held))
    end
    if type(ceiling) ~= "number" then
        error("pick: ceiling must be a number, got " .. type(ceiling))
    end

    local survivors = {}
    for _, entry in ipairs(roll) do
        local seen_by_viewer = held[entry.path] == true
        local worn_out       = entry.drawn >= ceiling
        if not seen_by_viewer and not worn_out then
            survivors[#survivors + 1] = entry
        end
    end

    if #roll == 0 then
        return nil, "the corpus is empty"
    end
    if #survivors == 0 then
        return nil, "this viewer has seen everything the corpus will lend"
    end

    return survivors[random_below(#survivors)]
end
-- }}}

-- {{{ function draw.stamp()
-- Records that a file went to a viewer, before the caller is told which
-- file it was.
--
-- The order matters.  A caller that receives a path and then dies must
-- not be able to ask again and be handed the same file -- from the
-- viewer's side that would look like the deletion never registered.
-- Stamping first means a crash costs one file, which is the cheaper of
-- the two wrong answers.
function draw.stamp(entry, held, now)
    held[entry.path] = true
    entry.drawn = entry.drawn + 1
    entry.last  = now
    return entry
end
-- }}}

return draw
