-- test-zip.lua — the zip library (my-libs issue 801): round trips between
-- its packer and reader and with the real zip programs, and every
-- refusal on the rubric, each with a zip built by hand to break exactly
-- one rule.  Built for rao-chat issue 216e; runs on LuaJIT and Lua 5.4.
--
-- The system zip and unzip programs are used here only: to make zips
-- the reader must read (so a bug shared by the two halves cannot hide),
-- and to test that the real unzip accepts what the packer writes.
--
-- Usage: <luajit | lua5.4> test-zip.lua [LIB] [SCRATCH]
--   LIB      the library folder (default below); its src/ is loaded
--   SCRATCH  a folder for throwaway files (default: in /dev/shm, RAM)
-- Prints PASS or FAIL per check and "counts <passed> <failed>".

local LIB = arg[1] or "/home/ritz/programming/ai-stuff/my-libs/zip"
local SCRATCH = arg[2] or ("/dev/shm/zip-library-tests/" .. (jit and "luajit" or _VERSION:gsub(" ", "")))
package.path = LIB .. "/src/?.lua;" .. package.path
local inflate = require("zip-inflate")
local reader = require("zip-reader")
local writer = require("zip-writer")

-- {{{ the checking kit
local kit = { passed = 0, failed = 0 }
-- {{{ function kit.check
function kit.check(name, fn)
    local ok, problem = pcall(fn)
    -- Path: ran through — a pass.  Raised — a failure, with why.
    if ok then
        kit.passed = kit.passed + 1
        print("    PASS " .. name)
    else
        kit.failed = kit.failed + 1
        print("    FAIL " .. name .. ": " .. tostring(problem))
    end
end
-- }}}
-- {{{ function kit.same
function kit.same(got, want, what)
    if got ~= want then
        error((what or "value") .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2)
    end
end
-- }}}
-- {{{ function kit.refuses
-- Runs fn; it must raise an error whose text holds `fragment`.
function kit.refuses(fn, fragment, what)
    local ok, problem = pcall(fn)
    if ok then
        error((what or "call") .. ": expected an error holding '" .. fragment .. "', got none", 2)
    end
    if not tostring(problem):find(fragment, 1, true) then
        error((what or "call") .. ": expected an error holding '" .. fragment .. "', got: " .. tostring(problem), 2)
    end
end
-- }}}
-- {{{ function kit.finish
function kit.finish()
    print("counts " .. kit.passed .. " " .. kit.failed)
    os.exit(kit.failed == 0 and 0 or 1)
end
-- }}}
-- {{{ function kit.read_file
function kit.read_file(path)
    local handle = assert(io.open(path, "rb"))
    local bytes = handle:read("*a")
    handle:close()
    return bytes
end
-- }}}
-- {{{ function kit.mtime
function kit.mtime(path)
    local pipe = io.popen("stat -c %Y '" .. path .. "'")
    local text = pipe:read("*l")
    pipe:close()
    return tonumber(text)
end
-- }}}
-- }}}

local scratch = SCRATCH
os.execute("rm -rf '" .. scratch .. "' && mkdir -p '" .. scratch .. "'")
local count = 0

-- {{{ local function write_file
local function write_file(path, bytes)
    local handle = assert(io.open(path, "wb"))
    handle:write(bytes)
    handle:close()
end
-- }}}

-- {{{ local function fresh
-- A new empty folder under scratch.
local function fresh(name)
    count = count + 1
    local path = scratch .. "/" .. name .. "-" .. count
    os.execute("mkdir -p '" .. path .. "'")
    return path
end
-- }}}

-- {{{ local function succeeds
local function succeeds(command)
    local a, b, c = os.execute(command)
    return a == true or a == 0 or (b == "exit" and c == 0)
end
-- }}}

-- {{{ local function leftovers
-- What is left in a folder (after a refusal, nothing should be).
local function leftovers(folder)
    local pipe = io.popen("find '" .. folder .. "' -mindepth 1")
    local all = pipe:read("*a")
    pipe:close()
    return all
end
-- }}}

-- {{{ local function le16
local function le16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
-- }}}
-- {{{ local function le32
local function le32(n)
    return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
-- }}}

-- {{{ local function build
-- A zip built by hand.  entries: { name, data, [type] (0x8000 file,
-- 0x4000 folder, 0xA000 link, ... default file), [mode] (default 0644),
-- [size] (claimed unpacked size, default #data), [flags], [method] (0),
-- [inside] (index of an earlier entry whose data holds this entry's local
-- header and data: the overlapping bomb), [time] }.  Stored only; a
-- deflated body can be passed as data with method 8 and a claimed size.
local function build(entries)
    local body, central = {}, {}
    local offset = 0
    local locals = {}
    -- {{{ local function local_bytes
    local function local_bytes(e)
        local crc = e.crc or (inflate.crc32_string(0, e.data) % 4294967296)
        local size = e.size or #e.data
        local extra = le16(0x5455) .. le16(5) .. string.char(1) .. le32((e.time or 1600000000) % 4294967296)
        return "PK\3\4" .. le16(10) .. le16(e.flags or 0x800) .. le16(e.method or 0) .. le16(0) .. le16(33)
            .. le32(crc) .. le32(#e.data) .. le32(size) .. le16(#e.name) .. le16(#extra) .. e.name .. extra .. e.data,
            #e.name + #extra + 30, crc, size, extra
    end
    -- }}}
    for index, e in ipairs(entries) do
        local bytes, header_len, crc, size, extra = local_bytes(e)
        local at
        if e.inside then
            at = locals[e.inside] + locals[e.inside .. "h"]
        else
            at = offset
            body[#body + 1] = bytes
            offset = offset + #bytes
        end
        locals[index], locals[index .. "h"] = at, header_len
        local attributes = ((e.type or 0x8000) + (e.mode or 420)) * 65536
        central[#central + 1] = "PK\1\2" .. le16(0x031E) .. le16(10) .. le16(e.flags or 0x800) .. le16(e.method or 0)
            .. le16(0) .. le16(33) .. le32(crc) .. le32(#e.data) .. le32(size) .. le16(#e.name) .. le16(#extra)
            .. le16(0) .. le16(0) .. le16(0) .. le32(attributes) .. le32(at) .. e.name .. extra
    end
    local directory = table.concat(central)
    return table.concat(body) .. directory .. "PK\5\6" .. le16(0) .. le16(0) .. le16(#entries) .. le16(#entries)
        .. le32(#directory) .. le32(offset) .. le16(0)
end
-- }}}

-- {{{ local function extract_built
-- Writes a built zip and extracts it; gives the folder.  size: the agreed
-- size (default: the claimed total).
local function extract_built(name, bytes, size)
    local folder = fresh(name)
    local zip = folder .. ".zip"
    write_file(zip, bytes)
    local _, total = reader.list(zip)
    reader.extract(zip, folder, { size = size or total, now = os.time(), exact = true })
    return folder
end
-- }}}

-- {{{ local function refused
-- A built zip must be refused with this reason, and leave nothing behind.
local function refused(name, bytes, reason, size)
    local folder = fresh(name)
    local zip = folder .. ".zip"
    write_file(zip, bytes)
    kit.refuses(function()
        local _, total = reader.list(zip)
        reader.extract(zip, folder, { size = size or total, now = os.time(), exact = true })
    end, "refused " .. reason)
    kit.same(leftovers(folder), "", "nothing left behind")
end
-- }}}

-- A sample tree: nested folders, an empty folder, an executable, a link,
-- an empty file, a file dated 2021.
local tree_parent = fresh("tree")
local tree = tree_parent .. "/tree"
os.execute("mkdir -p '" .. tree .. "/album/deep' '" .. tree .. "/empty'")
write_file(tree .. "/album/code.txt", kit.read_file(LIB .. "/src/zip-reader.lua"))
write_file(tree .. "/album/deep/one.txt", "x")
write_file(tree .. "/nothing.txt", "")
write_file(tree .. "/run.sh", "#!/bin/sh\necho hi\n")
os.execute("chmod 4755 '" .. tree .. "/run.sh'")
os.execute("touch -d '2021-06-01 12:00:00 UTC' '" .. tree .. "/album/code.txt'")
os.execute("ln -s /etc/passwd '" .. tree .. "/album/sneaky'")

kit.check("our zip passes the real unzip's test, and the real unzip makes the same tree", function()
    local zip = fresh("ours") .. ".zip"
    local result = writer.pack(tree, zip)
    kit.same(result.entries, 9, "entries")
    kit.same(succeeds("unzip -tq '" .. zip .. "' > /dev/null"), true, "unzip -t")
    local out = fresh("via-unzip")
    kit.same(succeeds("unzip -q '" .. zip .. "' -d '" .. out .. "'"), true, "unzip")
    kit.same(succeeds("diff -r --no-dereference '" .. tree .. "' '" .. out .. "/tree'"), true, "same tree")
end)

kit.check("our reader makes our zip back: bytes, empty folder, empty file, date, link as a note", function()
    local zip = fresh("round") .. ".zip"
    local result = writer.pack(tree, zip)
    local out = fresh("round-out")
    local tops = reader.extract(zip, out, { size = result.size, now = os.time(), exact = true })
    kit.same(table.concat(tops, ","), "tree", "the top name")
    kit.same(kit.read_file(out .. "/tree/album/code.txt"), kit.read_file(tree .. "/album/code.txt"), "bytes")
    kit.same(kit.read_file(out .. "/tree/nothing.txt"), "", "the empty file")
    kit.same(kit.read_file(out .. "/tree/album/deep/one.txt"), "x")
    kit.same(succeeds("test -d '" .. out .. "/tree/empty'"), true, "the empty folder")
    kit.same(kit.mtime(out .. "/tree/album/code.txt"), 1622548800, "the 2021 date")
    kit.same(succeeds("test -L '" .. out .. "/tree/album/sneaky'"), false, "no link made")
    local note = kit.read_file(out .. "/tree/album/sneaky.symlink.txt")
    kit.same(note:sub(1, 42), "This was a symbolic link to: /etc/passwd\nI", "the note")
end)

kit.check("the executable bit travels; set-user-id does not", function()
    local zip = fresh("modes") .. ".zip"
    local result = writer.pack(tree, zip)
    local out = fresh("modes-out")
    reader.extract(zip, out, { size = result.size, now = os.time(), exact = true })
    local pipe = io.popen("stat -c '%a' '" .. out .. "/tree/run.sh'")
    local mode = pipe:read("*l")
    pipe:close()
    kit.same(mode, "755")
end)

kit.check("the packed path, when a link, is followed once; links below it are not", function()
    local link = fresh("follow") .. "/linked"
    os.execute("ln -s '" .. tree .. "' '" .. link .. "'")
    local zip = fresh("follow-zip") .. ".zip"
    local result = writer.pack(link, zip)
    local out = fresh("follow-out")
    reader.extract(zip, out, { size = result.size, now = os.time(), exact = true })
    kit.same(kit.read_file(out .. "/linked/album/deep/one.txt"), "x", "the folder behind the link")
    kit.same(succeeds("test -f '" .. out .. "/linked/album/sneaky.symlink.txt'"), true, "the inner link as a note")
end)

kit.check("zips made by the real zip program are read: deflated text, stored, random", function()
    local folder = fresh("theirs")
    write_file(folder .. "/text.txt", string.rep(kit.read_file(LIB .. "/src/zip-inflate.lua"), 3))
    local random = io.open("/dev/urandom", "rb"):read(200000)
    write_file(folder .. "/random.bin", random)
    for _, flag in ipairs({ "", "-0" }) do
        local zip = fresh("theirs-zip") .. ".zip"
        kit.same(succeeds("cd '" .. folder .. "' && zip -q " .. flag .. " '" .. zip .. "' text.txt random.bin"), true)
        local list, total = reader.list(zip)
        kit.same(list[1].method, flag == "" and 8 or 0, "method")
        local out = fresh("theirs-out")
        reader.extract(zip, out, { size = total, now = os.time(), exact = true })
        kit.same(kit.read_file(out .. "/text.txt"), kit.read_file(folder .. "/text.txt"), "text " .. flag)
        kit.same(kit.read_file(out .. "/random.bin"), random, "random " .. flag)
    end
end)

kit.check("a bomb: a directory claiming 1000 bytes for 2 MB of zeros stops at 1000, nothing left", function()
    local folder = fresh("bomb-src")
    write_file(folder .. "/zeros", string.rep("\0", 2000000))
    local zip = fresh("bomb-zip") .. ".zip"
    kit.same(succeeds("cd '" .. folder .. "' && zip -q '" .. zip .. "' zeros"), true)
    local bytes = kit.read_file(zip)
    -- patch the unpacked size, in the local header (offset 22) and the
    -- directory entry (offset 24 of it), to 1000
    local dir_at = bytes:find("PK\1\2", 1, true)
    bytes = bytes:sub(1, 22) .. le32(1000) .. bytes:sub(27, dir_at + 23) .. le32(1000) .. bytes:sub(dir_at + 28)
    refused("bomb", bytes, "unpacks-larger", 1000)
end)

kit.check("not exact (rmail): the size is only a ceiling — less is taken, more is refused", function()
    local bytes = build({ { name = "a.txt", data = "hello" } })
    local folder = fresh("ceiling")
    local zip = folder .. ".zip"
    write_file(zip, bytes)
    reader.extract(zip, folder, { size = 5000, now = os.time(), exact = false })
    kit.same(kit.read_file(folder .. "/a.txt"), "hello", "taken under the ceiling")
    kit.refuses(function()
        reader.extract(zip, fresh("ceiling-over"), { size = 4, now = os.time(), exact = false })
    end, "refused unpacks-larger")
    kit.refuses(function()
        reader.extract(zip, fresh("no-exact"), { size = 5, now = os.time() })
    end, "options.exact must be true or false")
end)

kit.check("the agreed size must be met exactly: one more or one less is refused", function()
    local bytes = build({ { name = "a.txt", data = "hello" } })
    refused("larger", bytes, "unpacks-larger", 4)
    refused("smaller", bytes, "unpacks-smaller", 6)
end)

kit.check("an entry that makes fewer bytes than it claims is refused", function()
    -- stored: 5 bytes of data, claiming 6 unpacked
    refused("short", build({ { name = "a.txt", data = "hello", size = 6 } }), "unpacks-smaller")
end)

kit.check("overlapping entries (one kernel, two names) are refused", function()
    local inner = { name = "b.txt", data = "the kernel" }
    local outer_data = "PK\3\4" .. string.rep("\0", 100)   -- replaced below
    -- the outer entry's data is exactly the inner entry's header and data
    local inner_zip = build({ inner })
    local inner_local = inner_zip:sub(1, inner_zip:find("PK\1\2", 1, true) - 1)
    outer_data = inner_local
    refused("overlap", build({ { name = "a.bin", data = outer_data }, { name = "b.txt", data = "the kernel", inside = 1 } }),
        "overlap")
end)

kit.check("names that climb out, start at the root, or hide characters are refused", function()
    refused("dotdot", build({ { name = "../evil", data = "x" } }), "bad-name")
    refused("inner-dotdot", build({ { name = "a/../../evil", data = "x" } }), "bad-name")
    refused("absolute", build({ { name = "/etc/evil", data = "x" } }), "bad-name")
    refused("backslash", build({ { name = "a\\b", data = "x" } }), "bad-name")
    refused("control", build({ { name = "a\nb", data = "x" } }), "bad-name")
    refused("empty-piece", build({ { name = "a//b", data = "x" } }), "bad-name")
    refused("no-utf8-flag", build({ { name = "caf\195\169", data = "x", flags = 0 } }), "bad-name")
end)

kit.check("two entries on one path, or a file used as a folder, are refused", function()
    refused("twice", build({ { name = "a", data = "x" }, { name = "a", data = "y" } }), "duplicate")
    refused("under-file", build({ { name = "a", data = "x" }, { name = "a/b", data = "y" } }), "duplicate")
end)

kit.check("a link becomes a one-line note, even with a line break in its target", function()
    local folder = extract_built("note", build({ { name = "x", data = "/tmp/a\nb", type = 0xA000, mode = 511 } }))
    local note = kit.read_file(folder .. "/x.symlink.txt")
    kit.same(note:match("^[^\n]*"), "This was a symbolic link to: /tmp/a\\x0Ab", "one line")
    -- a link name that fits alone but not with ".symlink.txt" after it
    refused("long-link", build({ { name = string.rep("n", 235), data = "/x", type = 0xA000, mode = 511 } }), "bad-name")
end)

kit.check("devices, pipes and sockets in a zip are refused", function()
    refused("device", build({ { name = "dev", data = "", type = 0x2000 } }), "special-file")
end)

kit.check("a flipped byte fails the CRC and leaves nothing", function()
    local bytes = build({ { name = "a.txt", data = "hello world" } })
    local at = bytes:find("hello", 1, true)
    refused("crc", bytes:sub(1, at - 1) .. "j" .. bytes:sub(at + 1), "damaged")
end)

kit.check("encrypted entries, other methods and ZIP64 are refused", function()
    refused("encrypted", build({ { name = "a", data = "x", flags = 0x801 } }), "encrypted")
    refused("method", build({ { name = "a", data = "x", method = 12 } }), "unsupported")
    local bytes = build({ { name = "a", data = "x" } })
    -- the end record's last fields: directory offset (4 bytes), comment
    -- length (2); an offset of all ones is ZIP64's mark
    refused("zip64", bytes:sub(1, -7) .. le32(4294967295) .. bytes:sub(-2), "zip64")
end)

kit.check("not a zip at all is refused", function()
    refused("plain", "just some text, no zip here", "damaged")
    refused("empty", build({}), "damaged: a zip with no entries")
end)

kit.check("dates past 2038 loop: each lap read back exactly, a future date drops one lap", function()
    local LAP = 4294967296
    for _, when in ipairs({ -315619200, 1622548800, 2137000000, 2208988800, 4102444800 }) do
        kit.same(reader.lap_time(when % LAP, when + 1000), when, "the date " .. when)
    end
    kit.same(reader.lap_time(1622548800 % LAP, 1622548800 - 1000), 1622548800 - LAP, "a future date")
end)

kit.check("a date past 2038 travels through the packer and back", function()
    local folder = fresh("future")
    write_file(folder .. "/later.txt", "later")
    os.execute("touch -d '2040-03-01 00:00:00 UTC' '" .. folder .. "/later.txt'")
    local zip = fresh("future-zip") .. ".zip"
    local result = writer.pack(folder .. "/later.txt", zip)
    local out = fresh("future-out")
    -- the arrival: a day later, in 2040
    reader.extract(zip, out, { size = result.size, now = 2214259200, exact = true })
    kit.same(kit.mtime(out .. "/later.txt"), 2214172800)
end)

kit.check("progress is reported while making, never past the budget, and done at the end", function()
    local folder = fresh("progress")
    write_file(folder .. "/big.bin", string.rep("abcdefgh", 400000))
    local zip = fresh("progress-zip") .. ".zip"
    local result = writer.pack(folder .. "/big.bin", zip)
    local out = fresh("progress-out")
    local reports = {}
    reader.extract(zip, out, { size = result.size, now = os.time(), exact = true, progress = function(s)
        reports[#reports + 1] = { out = s.bytes_out, budget = s.budget, done = s.done }
    end })
    kit.same(#reports >= 2, true, "at least a report while making and one at the end")
    for _, r in ipairs(reports) do
        kit.same(r.out <= r.budget, true, "never past the budget")
    end
    kit.same(reports[#reports].done, true, "the last says done")
    kit.same(reports[#reports].out, 3200000, "all of it")
end)

kit.check("the packer refuses what it cannot send, and a file that changes while read", function()
    local folder = fresh("pipe")
    os.execute("mkfifo '" .. folder .. "/pipe'")
    kit.refuses(function() writer.pack(folder, fresh("pipe-zip") .. ".zip") end, "device, pipe or socket")
    -- a /proc file is listed with 0 bytes and reads as more: the torn case
    kit.refuses(function() writer.pack("/proc/version", fresh("proc-zip") .. ".zip") end, "changed while it was packed")
    -- a path that is not there makes no zip at all, not an empty one
    local gone = fresh("gone")
    kit.refuses(function() writer.pack(gone .. "/nothing-here", gone .. ".zip") end, "could not list")
    kit.same(io.open(gone .. ".zip", "rb"), nil, "no zip left behind")
end)

-- {{{ local function bits_to_bytes
-- A deflate stream from a list of bits in the order the inflater reads
-- them (each byte filled from its lowest bit).
local function bits_to_bytes(list)
    local out, value, filled = {}, 0, 0
    for _, b in ipairs(list) do
        value = value + b * 2 ^ filled
        filled = filled + 1
        if filled == 8 then
            out[#out + 1] = string.char(value)
            value, filled = 0, 0
        end
    end
    if filled > 0 then out[#out + 1] = string.char(value) end
    return table.concat(out)
end
-- }}}

-- {{{ local function run_stream
local function run_stream(stream, budget)
    local given = false
    return inflate.run(8, function()
        if given then return nil end
        given = true
        return stream
    end, function() end, budget or 1000)
end
-- }}}

kit.check("broken recipes are refused by name: reserved block, copy before the start, over-full table", function()
    kit.refuses(function() run_stream(bits_to_bytes({ 1, 1, 1 })) end, "block type 3")
    -- fixed codes: length code 257 (7 bits 0000001) with distance code 0
    -- (5 bits 00000) before any byte was made, then end of block
    local copy_first = { 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    kit.refuses(function() run_stream(bits_to_bytes(copy_first)) end, "before anything was made")
    -- dynamic: 257 lengths, 1 distance, 4 code-length codes all of 1 bit:
    -- four codes of one bit cannot exist
    local over_full = { 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0 }
    kit.refuses(function() run_stream(bits_to_bytes(over_full)) end, "over-full or incomplete")
end)

kit.check("a stream cut short, or with bytes after its end, is refused", function()
    -- fixed codes: literal 'a' (8 bits 10010001), end of block (0000000)
    local good = bits_to_bytes({ 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 })
    kit.same(run_stream(good), 1, "the good stream makes one byte")
    kit.refuses(function() run_stream(good:sub(1, 1)) end, "ends before")
    kit.refuses(function() run_stream(good .. "x") end, "bytes left")
end)

kit.finish()
