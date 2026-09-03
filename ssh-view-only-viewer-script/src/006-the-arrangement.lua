-- 006-the-arrangement.lua
--
-- Decides whether an arriving packet is a genuine request for a look at
-- this machine, and if so, who is asking.  It is handed the bytes of one
-- datagram and answers with a name or with a refusal.  It creates
-- nothing, opens nothing, and remembers nothing, so it can be reasoned
-- about and tested entirely on its own -- which matters, because every
-- privileged thing this project does happens only because this file said
-- yes.
--
-- LuaJIT (5.1) syntax.  No 5.4 constructs.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if arg and arg[1] then DIR = arg[1] end

local arrangement = {}

-- How long one time window lasts, in seconds.  Both ends divide the
-- clock by this and round down, so they agree on a number without
-- agreeing on a second.  This value IS the replay exposure: a copied
-- packet stays good until its window ends.  Shortening it tightens that
-- and raises the chance of refusing an honest sender whose clock drifts.
arrangement.WINDOW_SECONDS = 30

-- The longest an account name may be.  Linux itself stops at 32 for a
-- user name; the lower cap leaves room for any prefix the grant decides
-- to add without silently truncating somebody's name into somebody
-- else's.
arrangement.NAME_MAX = 24

-- {{{ function arrangement.name_is_permissible()
-- Answers whether a string may be used as an account name.
--
-- This runs before anything else, on every packet, because the name is
-- the one field that travels from a stranger's datagram out to a command
-- line.  The pattern is a small allowlist rather than a list of things to
-- reject: lowercase letters, digits, hyphen, underscore, and a letter
-- first.  Anything not named here is refused, so a character nobody
-- thought about is refused by default rather than permitted by default.
--
-- The leading-letter rule is not decoration.  A name beginning with a
-- digit is accepted by some tools and rejected by others, and one
-- beginning with a hyphen would be read as an option rather than an
-- argument by every command it is ever passed to.
function arrangement.name_is_permissible(name)
    if type(name) ~= "string" then return false end
    if #name < 1 then return false end
    if #name > arrangement.NAME_MAX then return false end

    -- Anchored at both ends.  Without the anchors, a name containing a
    -- newline would match on its first line and the rest would be
    -- carried along unexamined.
    if not name:match("^[a-z][a-z0-9_%-]*$") then return false end

    return true
end
-- }}}

-- {{{ function arrangement.window_of()
-- The window number a given moment falls in.
function arrangement.window_of(unix_seconds)
    if type(unix_seconds) ~= "number" then
        error("window_of: expected a number, got " .. type(unix_seconds))
    end
    return math.floor(unix_seconds / arrangement.WINDOW_SECONDS)
end
-- }}}

-- {{{ function arrangement.acceptable_windows()
-- The windows a receiver will honour at a given moment.
--
-- The current one and the one before it.  Accepting the previous window
-- covers a sender whose clock is a little behind and a packet that spent
-- time in flight; without it, a packet sent in the last moment of a
-- window would be refused for no reason the sender could see.
--
-- The next window is deliberately NOT accepted.  Honouring a future
-- window would let a sender with a fast clock -- or one who simply chose
-- a large number -- mint a packet good for longer than a window lasts.
function arrangement.acceptable_windows(unix_seconds)
    local current = arrangement.window_of(unix_seconds)
    return { current, current - 1 }
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    if type(text) ~= "string" then
        error("shell_quote: expected a string, got " .. type(text))
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function sha256_of()
-- The sha256 of a string, as 64 lowercase hex characters.
--
-- The text is passed to sha256sum on standard input rather than as an
-- argument, because arguments are visible to every process on the
-- machine through the process list and standard input is not.  The
-- secret is always part of this text, so that distinction is the
-- difference between a secret and a published one.
local function sha256_of(text)
    local command = "printf '%s' " .. shell_quote(text) .. " | sha256sum"
    local pipe = io.popen(command, "r")
    if not pipe then
        error("could not run sha256sum")
    end
    local output = pipe:read("*a")
    pipe:close()

    local hex = output:match("^(%x+)")
    if not hex or #hex ~= 64 then
        error("sha256sum returned something unexpected: " .. tostring(output))
    end

    return hex
end
-- }}}

-- {{{ function arrangement.digest()
-- The sha256 of the secret, the name and the window, joined.
--
-- The separator is the pipe character, and the reason is that
-- name_is_permissible forbids it.  Without a separator that cannot occur
-- in a name, the name "ab" with window 1 and the name "a" with window
-- "b1" would join to the same string and produce the same digest -- two
-- different requests that a receiver could not tell apart.
function arrangement.digest(secret, name, window)
    if type(secret) ~= "string" or #secret == 0 then
        error("digest: a non-empty secret is required")
    end
    if not arrangement.name_is_permissible(name) then
        error("digest: refusing to sign an impermissible name")
    end
    if type(window) ~= "number" then
        error("digest: window must be a number, got " .. type(window))
    end

    return sha256_of(secret .. "|" .. name .. "|" .. tostring(window))
end
-- }}}

-- {{{ function arrangement.digests_match()
-- Compares two digests without letting the time taken reveal how much of
-- a guess was correct.
--
-- A plain equality test stops at the first differing byte, so a guess
-- sharing a longer prefix takes measurably longer to reject.  Repeated
-- often enough, that difference lets a digest be discovered one byte at a
-- time without ever being known.  This walks the whole string every time
-- and folds every difference into one accumulator.
function arrangement.digests_match(left, right)
    if type(left) ~= "string" or type(right) ~= "string" then
        return false
    end
    if #left ~= #right then
        return false
    end

    local difference = 0
    for index = 1, #left do
        -- Bitwise xor is unavailable in 5.1, so differences are summed.
        -- Any differing byte contributes a non-zero amount and nothing
        -- can subtract from it, so the total is zero only when every
        -- byte matched.
        local gap = left:byte(index) - right:byte(index)
        if gap < 0 then gap = -gap end
        difference = difference + gap
    end

    return difference == 0
end
-- }}}

-- {{{ function arrangement.build()
-- Shapes a packet.  The sending half, kept here beside the checking half
-- so the two can never drift into disagreeing about the format.
function arrangement.build(secret, name, unix_seconds)
    local window = arrangement.window_of(unix_seconds)
    local hex = arrangement.digest(secret, name, window)
    return name .. " " .. tostring(window) .. " " .. hex
end
-- }}}

-- {{{ function arrangement.password_for()
-- The password the account will be given, derived rather than sent.
--
-- This is what removes the need for a reply.  Whoever shaped the packet
-- already holds the secret and knows which window they used, so they can
-- compute this themselves the moment they knock; the listening machine
-- computes the same thing and sets it.  Nothing about the password ever
-- crosses the network, and there is no return channel to arrange, block,
-- or spoof.
--
-- The label "password" is folded in so this can never equal the knock
-- digest for the same name and window.  Without it, the digest a
-- stranger watched go past on the wire would BE the password.
--
-- Truncated to 32 hex characters -- 128 bits, far past anything worth
-- guessing, and short enough to type.
function arrangement.password_for(secret, name, window)
    if type(secret) ~= "string" or #secret == 0 then
        error("password_for: a non-empty secret is required")
    end
    if not arrangement.name_is_permissible(name) then
        error("password_for: refusing to derive for an impermissible name")
    end
    if type(window) ~= "number" then
        error("password_for: window must be a number, got " .. type(window))
    end

    -- The label sits between the secret and the name, in the same
    -- pipe-joined shape the knock digest uses.  Because a permissible
    -- name can never contain a pipe, no name can impersonate the label
    -- and make its knock digest come out as somebody's password.
    local full = sha256_of(
        secret .. "|password|" .. name .. "|" .. tostring(window))
    return full:sub(1, 32)
end
-- }}}

-- {{{ function arrangement.verdict()
-- Reads one received packet and decides.
--
-- Returns the name on success.  Returns nil plus a reason otherwise, and
-- the reason is for the machine's own operator -- it is never sent back
-- to whoever knocked, because telling a stranger which of their guesses
-- was closer is how a secret gets found one field at a time.
--
-- The checks run cheapest-first, and every one of them refuses rather
-- than repairs.  There is no path through this function that fixes up a
-- malformed packet and carries on.
function arrangement.verdict(secret, packet, unix_seconds)
    if type(secret) ~= "string" or #secret == 0 then
        error("verdict: a non-empty secret is required")
    end
    if type(packet) ~= "string" then
        return nil, "packet was not text"
    end

    -- A datagram large enough to be interesting is not one of ours.  The
    -- longest legitimate packet is a name, two spaces, a window and 64
    -- hex characters; the cap is generous against that and still refuses
    -- anything trying to be a payload rather than a request.
    if #packet > 256 then
        return nil, "packet too long"
    end

    local name, window_text, hex = packet:match("^(%S+) (%S+) (%S+)$")
    if not name then
        return nil, "packet was not three fields separated by single spaces"
    end

    if not arrangement.name_is_permissible(name) then
        return nil, "name is not a permissible account name"
    end

    if not hex:match("^%x+$") or #hex ~= 64 then
        return nil, "digest was not 64 hex characters"
    end

    local window = tonumber(window_text)
    if not window or window ~= math.floor(window) then
        return nil, "window was not a whole number"
    end

    local allowed = false
    for _, candidate in ipairs(arrangement.acceptable_windows(unix_seconds)) do
        if window == candidate then allowed = true end
    end
    if not allowed then
        return nil, "window is not one this machine is currently honouring"
    end

    local expected = arrangement.digest(secret, name, window)
    if not arrangement.digests_match(expected, hex) then
        return nil, "digest does not match"
    end

    return name
end
-- }}}

return arrangement
