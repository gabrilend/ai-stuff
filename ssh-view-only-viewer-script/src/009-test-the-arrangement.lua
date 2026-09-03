-- 009-test-the-arrangement.lua
--
-- Proves the packet checker says yes only when it should.  The tests
-- that matter most are the refusals: each one is a different way of
-- presenting a packet that is not genuine, and every one must be turned
-- away with its own reason.  A wrong "yes" here is the worst thing this
-- project can do, because everything privileged happens downstream of it.
--
-- LuaJIT (5.1) syntax.  Run via 012-run-tests.sh.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if arg and arg[1] then DIR = arg[1] end

local arrangement = dofile(DIR .. "/src/006-the-arrangement.lua")

local SECRET = "a-shared-secret-for-testing-only"
local NOW    = 1756800000

local passed = 0
local failed = 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok    " .. name)
    else
        failed = failed + 1
        print("  FAIL  " .. name)
        if detail then print("        " .. tostring(detail)) end
    end
end
-- }}}

print("")
print("what may be an account name")

check("an ordinary name is permitted",
    arrangement.name_is_permissible("ritz") == true)

check("an empty name is refused",
    arrangement.name_is_permissible("") == false)

check("a name longer than the cap is refused",
    arrangement.name_is_permissible(string.rep("a", 25)) == false)

check("a name starting with a digit is refused",
    arrangement.name_is_permissible("2cool") == false,
    "accepted by some tools, rejected by others")

check("a name starting with a hyphen is refused",
    arrangement.name_is_permissible("-rf") == false,
    "would be read as an option, not an argument")

check("an uppercase name is refused",
    arrangement.name_is_permissible("Ritz") == false)

check("a name with a space is refused",
    arrangement.name_is_permissible("two words") == false)

check("a name with a newline is refused",
    arrangement.name_is_permissible("ritz\nroot") == false,
    "the pattern is anchored at both ends for exactly this")

check("a name with a shell metacharacter is refused",
    arrangement.name_is_permissible("ritz;id") == false)

check("a name with a dollar sign is refused",
    arrangement.name_is_permissible("ritz$USER") == false)

check("a name with a path separator is refused",
    arrangement.name_is_permissible("../root") == false)

check("a name with a NUL byte is refused",
    arrangement.name_is_permissible("ritz\0root") == false)

check("a name containing the digest separator is refused",
    arrangement.name_is_permissible("ritz|1") == false,
    "otherwise two different requests could share one digest")

print("")
print("windows")

check("a moment maps to a window",
    arrangement.window_of(NOW) == math.floor(NOW / arrangement.WINDOW_SECONDS))

check("two moments in the same window agree",
    arrangement.window_of(NOW) == arrangement.window_of(NOW + 1))

local windows = arrangement.acceptable_windows(NOW)
check("two windows are honoured at a time", #windows == 2, #windows)

check("the current window is honoured",
    windows[1] == arrangement.window_of(NOW))

check("the previous window is honoured",
    windows[2] == arrangement.window_of(NOW) - 1,
    "covers a slow clock and time spent in flight")

local future = arrangement.window_of(NOW) + 1
local honours_future = false
for _, w in ipairs(windows) do
    if w == future then honours_future = true end
end
check("a future window is not honoured", honours_future == false,
    "otherwise a fast clock mints a longer-lived packet")

print("")
print("comparing digests")

check("identical digests match",
    arrangement.digests_match(string.rep("a", 64), string.rep("a", 64)) == true)

check("digests differing in the last byte do not match",
    arrangement.digests_match(string.rep("a", 64),
                              string.rep("a", 63) .. "b") == false)

check("digests differing in the first byte do not match",
    arrangement.digests_match(string.rep("a", 64),
                              "b" .. string.rep("a", 63)) == false)

check("digests of different lengths do not match",
    arrangement.digests_match("abc", "abcd") == false)

print("")
print("a genuine packet")

local packet = arrangement.build(SECRET, "ritz", NOW)

check("a packet built here is accepted here",
    arrangement.verdict(SECRET, packet, NOW) == "ritz",
    "the sending and checking halves agree on the format")

check("it is still accepted one window later",
    arrangement.verdict(SECRET, packet, NOW + arrangement.WINDOW_SECONDS) == "ritz",
    "the previous window is honoured")

local stale, stale_reason =
    arrangement.verdict(SECRET, packet, NOW + arrangement.WINDOW_SECONDS * 2)
check("it is refused two windows later", stale == nil, stale_reason)
check("the staleness refusal names the window", stale_reason ~= nil, stale_reason)

print("")
print("packets that are not genuine")

-- {{{ local function refused()
-- Asserts a packet is turned away, and reports the reason given.
local function refused(label, bad_packet, at)
    local name, reason = arrangement.verdict(SECRET, bad_packet, at or NOW)
    check(label, name == nil, "unexpectedly accepted as: " .. tostring(name))
    if name == nil then
        print("        refused: " .. tostring(reason))
    end
end
-- }}}

refused("a packet from the wrong secret",
    arrangement.build("a-different-secret", "ritz", NOW))

local edited_name = packet:gsub("^ritz", "root")
refused("a packet whose name was edited", edited_name)

local edited_digest = packet:sub(1, #packet - 1) ..
    (packet:sub(-1) == "a" and "b" or "a")
refused("a packet whose digest was edited", edited_digest)

refused("a packet with too few fields", "ritz 58560000")
refused("a packet with too many fields", packet .. " extra")
refused("an empty packet", "")
refused("a packet of only spaces", "   ")
refused("a packet whose digest is not hex",
    "ritz " .. tostring(arrangement.window_of(NOW)) .. " " .. string.rep("z", 64))
refused("a packet whose digest is too short",
    "ritz " .. tostring(arrangement.window_of(NOW)) .. " " .. string.rep("a", 32))
refused("a packet whose window is not a number",
    "ritz soon " .. string.rep("a", 64))
refused("a packet whose window is fractional",
    "ritz 1.5 " .. string.rep("a", 64))
refused("a packet claiming an impermissible name",
    "-rf " .. tostring(arrangement.window_of(NOW)) .. " " .. string.rep("a", 64))
refused("an overlong packet", string.rep("x", 300))

local not_text = arrangement.verdict(SECRET, 12345, NOW)
check("a packet that is not text is refused", not_text == nil)

print("")
print("the derived password")

local pw = arrangement.password_for(SECRET, "ritz", arrangement.window_of(NOW))

check("a password is derived", type(pw) == "string" and #pw == 32, pw)
check("it is hex", pw:match("^%x+$") ~= nil, pw)

check("both ends derive the same password",
    pw == arrangement.password_for(SECRET, "ritz", arrangement.window_of(NOW)),
    "this is what removes the need for a reply packet")

check("a different window gives a different password",
    pw ~= arrangement.password_for(SECRET, "ritz", arrangement.window_of(NOW) + 1))

check("a different name gives a different password",
    pw ~= arrangement.password_for(SECRET, "kuvalu", arrangement.window_of(NOW)))

check("a different secret gives a different password",
    pw ~= arrangement.password_for("another-secret", "ritz", arrangement.window_of(NOW)))

local knock_digest = arrangement.digest(SECRET, "ritz", arrangement.window_of(NOW))
check("the password is not the digest that travelled on the wire",
    knock_digest:sub(1, 32) ~= pw,
    "otherwise watching one packet would hand over the password")

print("")
print("two names never share a digest")

local ab_then_one = arrangement.digest(SECRET, "ab", 1)
local a_then_b1   = arrangement.digest(SECRET, "a", 1)
check("joining is unambiguous", ab_then_one ~= a_then_b1,
    "the separator is a character no permissible name may contain")

print("")
print(string.format("%d passed, %d failed", passed, failed))
print("")

if failed > 0 then os.exit(1) end
