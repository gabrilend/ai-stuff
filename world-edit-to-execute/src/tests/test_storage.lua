#!/usr/bin/env luajit
-- test_storage.lua - what the player's maps and asset packs take up (issue 605)
--
-- In plain terms: two maps and an asset pack that share some files are put
-- into a fresh player data folder. Each one's size, its own (unique) bytes
-- and its shared bytes come out exactly; deleting a map frees exactly its
-- own bytes once collected, and nothing another map or pack still uses;
-- last-used times are kept across a restart; and the command-line tool
-- shows the same numbers, asks before deleting, and deletes nothing when
-- the answer is no.
--
-- Run: luajit src/tests/test_storage.lua [DIR]
-- Issue: issues/completed/605-local-storage-manager.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local storage = require("assets.storage")
arg = { [0] = "test" }
local cli = dofile(DIR .. "/src/cli/storage.lua")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function run(cmd)
    local p = io.popen("( " .. cmd .. " ) 2>&1; echo \"exit $?\"")
    local out = p:read("*a")
    p:close()
    local body, code = out:match("^(.-)exit (%d+)\n$")
    return body, tonumber(code)
end
local function errors(f, ...)
    local ok, err = pcall(f, ...)
    return not ok, tostring(err)
end
local function find(list, name)
    for _, info in ipairs(list) do if info.name == name then return info end end
end

local SCRATCH = os.tmpname()
os.remove(SCRATCH)
local DATA = SCRATCH .. "/player-data"

-- Three distinct files: grass (100 bytes), sword (1,000), castle (10,000);
-- and each map's own script.
local GRASS, SWORD, CASTLE = string.rep("g", 100), string.rep("s", 1000), string.rep("c", 10000)

-- {{{ Putting files in
print("\n=== Putting maps and packs in ===")
local S = storage.open(DATA)
S:put("map", "Castle Fight", "Textures/grass.blp", GRASS)
S:put("map", "Castle Fight", "Units/castle.mdx", CASTLE)
S:put("map", "Castle Fight", "war3map.j", "castle fight's script")      -- 21 bytes, its own
S:put("map", "Footmen Frenzy", "Textures/grass.blp", GRASS)
S:put("map", "Footmen Frenzy", "Textures/grass-copy.blp", GRASS)       -- the same file twice in one map
S:put("map", "Footmen Frenzy", "war3map.j", "footmen frenzy's script") -- 23 bytes
S:put("pack", "medieval", "units/sword.mdx", SWORD)
S:put("pack", "medieval", "units/castle.mdx", CASTLE)
test("each file is stored once", #S.store:list() == 5)
test("the maps and packs are listed by name", table.concat(S:names("map"), ",") == "Castle Fight,Footmen Frenzy"
    and table.concat(S:names("pack"), ",") == "medieval")
-- }}}

-- {{{ Sizes
print("\n=== Sizes ===")
local cf = S:info("map", "Castle Fight")
test("a map's size: each of its files once", cf.total_bytes == 100 + 10000 + 21, tostring(cf.total_bytes))
test("its own bytes: only its script (grass and castle are used elsewhere)", cf.unique_bytes == 21, tostring(cf.unique_bytes))
test("shared + unique = total", cf.shared_bytes + cf.unique_bytes == cf.total_bytes)
test("files and blobs counted", cf.file_count == 3 and cf.blob_count == 3)
local ff = S:info("map", "Footmen Frenzy")
test("a file linked twice in one map counts once", ff.total_bytes == 100 + 23 and ff.file_count == 3, tostring(ff.total_bytes))
local med = S:info("pack", "medieval")
test("a pack: the sword is its own, the castle shared", med.unique_bytes == 1000 and med.shared_bytes == 10000)
test("no such map: nil", S:info("map", "Nowhere") == nil)

local o = S:overview()
test("total: each stored file once", o.total_bytes == 100 + 10000 + 21 + 23 + 1000, tostring(o.total_bytes))
test("without keeping each file once: every link a copy",
    o.naive_bytes == 100 * 3 + 10000 * 2 + 21 + 23 + 1000, tostring(o.naive_bytes))
test("savings", o.savings_bytes == o.naive_bytes - o.total_bytes
    and o.savings_percent == math.floor(o.savings_bytes * 100 / o.naive_bytes + 0.5))
test("shared: the files two or more sources use (grass, castle)", o.shared_bytes == 10100, tostring(o.shared_bytes))
test("nothing unused yet", o.orphan_count == 0)
test("the lists", #o.maps == 2 and #o.packs == 1 and find(o.maps, "Castle Fight").unique_bytes == 21)

S.store:pin(S.store:list()[4])   -- the 23-byte script
test("a pinned file isn't counted as freeable", S:info("map", "Footmen Frenzy").unique_bytes == 0)
S.store:unpin(S.store:list()[4])

-- A plain file in a map's folder (not a link) is the map's own
local f = io.open(DATA .. "/maps/Castle Fight/notes.txt", "wb"); f:write("12345"); f:close()
test("a plain file counts as its own", S:info("map", "Castle Fight").unique_bytes == 26
    and S:overview().total_bytes == o.total_bytes + 5)
-- }}}

-- {{{ Names
print("\n=== Names that can't be folders ===")
test("a name with a slash", (errors(S.put, S, "map", "a/b", "x", "y")))
test("a name of ..", (errors(S.put, S, "map", "..", "x", "y")))
test("a path leaving its map", (errors(S.put, S, "map", "ok", "../x", "y")))
test("an absolute path", (errors(S.put, S, "map", "ok", "/etc/x", "y")))
test("an unknown kind", (errors(S.info, S, "server", "x")))
-- }}}

-- {{{ Last used
print("\n=== Last used ===")
S:touch("map", "Castle Fight", 1704067200)
test("touch records the time", S:info("map", "Castle Fight").last_used == 1704067200)
test("put marks a source used now", math.abs((S:info("pack", "medieval").last_used or 0) - os.time()) < 60)
local R = storage.open(DATA)
test("kept across a restart", R:info("map", "Castle Fight").last_used == 1704067200)
-- }}}

-- {{{ Deleting
print("\n=== Deleting ===")
local freed = R:delete("map", "Castle Fight")
test("delete returns the map's own bytes", freed == 26, tostring(freed))
test("its folder is gone", not os.rename(DATA .. "/maps/Castle Fight", DATA .. "/maps/Castle Fight"))
test("its last-used line is gone", storage.open(DATA).used["map\tCastle Fight"] == nil)
test("its script is now unused; grass and castle aren't", #R:orphans() == 1)
local removed, gc_bytes = R:gc()
test("gc frees exactly its own stored bytes", removed == 1 and gc_bytes == 21, removed .. ", " .. gc_bytes)
test("the others still read", io.open(DATA .. "/maps/Footmen Frenzy/Textures/grass.blp"):read("*a") == GRASS
    and io.open(DATA .. "/asset-packs/medieval/units/castle.mdx"):read("*a") == CASTLE)
test("the castle is now the pack's own", R:info("pack", "medieval").unique_bytes == 11000)
test("deleting what isn't there", R:delete("map", "Castle Fight") == nil)
-- }}}

-- {{{ The command line
print("\n=== The command line ===")
local TOOL = "luajit " .. sh(DIR .. "/src/cli/storage.lua") .. " --dir " .. sh(DIR) .. " --data " .. sh(DATA)
local out, code = run(TOOL)
test("the overview runs", code == 0 and out:find("MAPS", 1, true) and out:find("ASSET PACKS", 1, true), out)
test("it names each map and pack with its size", out:find("Footmen Frenzy%s+123 B") and out:find("medieval%s+10.7 KB"), out)
local rows = {}
for line in out:gmatch("[^\n]+") do
    if line:find("Footmen Frenzy", 1, true) or line:find("medieval", 1, true) then rows[#rows + 1] = #line end
end
test("its rows line up", #rows == 2 and rows[1] == rows[2], table.concat(rows, ","))
out = run(TOOL .. " report")
test("report adds files and shared bytes", out:find("3 files (2 different)", 1, true) ~= nil, out)

out, code = run("echo n | " .. TOOL .. " delete pack medieval")
test("asked, answered no: nothing deleted", code ~= 0 and out:find("Nothing deleted", 1, true)
    and storage.open(DATA):info("pack", "medieval") ~= nil, out)
out, code = run(TOOL .. " delete pack medieval < /dev/null")
test("no answer at all: nothing deleted", code ~= 0 and storage.open(DATA):info("pack", "medieval") ~= nil, out)
out, code = run("echo y | " .. TOOL .. " delete pack medieval")
test("asked, answered yes: deleted and collected", code == 0 and out:find("freed 10.7 KB", 1, true)
    and storage.open(DATA):info("pack", "medieval") == nil, out)
out, code = run(TOOL .. " delete map 'Footmen Frenzy' --force")
test("--force deletes without asking", code == 0 and not out:find("[y/N]", 1, true)
    and storage.open(DATA):info("map", "Footmen Frenzy") == nil, out)
out, code = run(TOOL .. " delete map Nowhere --force")
test("deleting what isn't there says so", code ~= 0 and out:find("No map named Nowhere", 1, true), out)
local lone = storage.open(DATA)
lone.store:store("left behind")
out = run(TOOL .. " orphans")
test("orphans lists what gc would remove", out:match("^sha256:%x+\n$") ~= nil, out)
out = run(TOOL .. " gc")
test("gc says what it removed", out:find("Removed 1 stored file nothing used", 1, true) ~= nil, out)
out, code = run(TOOL .. " frobnicate")
test("an unknown command is refused", code == 2, out)

-- the render function, called directly, on an empty folder
local empty = storage.open(SCRATCH .. "/empty")
test("an empty folder renders, with no division by zero", cli.render(empty):find("(none)", 1, true) ~= nil)
-- }}}

-- {{{ Read-only stored files, edited copy-on-write
print("\n=== Stored files are read-only; editing makes a private copy ===")
local function mode(path) return run("stat -L -c %a " .. sh(path)):match("%d+") end
local function slurp(path) local fh = io.open(path, "rb"); if not fh then return nil end
    local t = fh:read("*a"); fh:close(); return t end
local function islink(path) return run("test -L " .. sh(path) .. " && echo yes"):match("yes") ~= nil end
local CD = SCRATCH .. "/cow"
local W = storage.open(CD)
local hg = W:put("map", "A", "grass.blp", GRASS)
W:put("map", "B", "grass.blp", GRASS)
W:put("pack", "art", "Textures/grass.blp", GRASS)
W:put("pack", "art", "sword.mdx", SWORD)
local blob = W.store:path(hg)
test("a stored file is read-only (0444)", mode(blob) == "444", mode(blob))
test("a pack's file is a link to it", islink(CD .. "/asset-packs/art/Textures/grass.blp"))
-- An ordinary user's editor writing through the link is refused (root's
-- isn't: the mode doesn't bind root, so this runs as nobody when it can).
if run("id -u"):match("^0") and run("command -v setpriv"):match("setpriv") then
    local _, wcode = run("setpriv --reuid=65534 --regid=65534 --clear-groups sh -c "
        .. sh("echo painted > " .. sh(CD .. "/maps/A/grass.blp")))
    local rout, rcode = run("setpriv --reuid=65534 --regid=65534 --clear-groups cat " .. sh(CD .. "/maps/A/grass.blp"))
    test("an ordinary user can read through a link, but not write", rcode == 0 and rout == GRASS
        and wcode ~= 0 and slurp(blob) == GRASS, rout)
else
    print("  [SKIP] writing as an ordinary user (needs root and setpriv to switch to one)")
end
local done = W:edit("pack", "art", "Textures/grass.blp")
local mine = CD .. "/asset-packs/art/Textures/grass.blp"
test("edit makes that one file a private copy", done and #done == 1 and done[1] == "Textures/grass.blp"
    and not islink(mine) and mode(mine) == "644" and slurp(mine) == GRASS)
local fh = assert(io.open(mine, "wb")); fh:write("painted over"); fh:close()
test("writing the copy leaves the stored file and the other maps alone", slurp(blob) == GRASS
    and slurp(CD .. "/maps/A/grass.blp") == GRASS and slurp(CD .. "/maps/B/grass.blp") == GRASS
    and #W.store:verify() == 0)
test("the stored file is still shared by A and B", W.store:refcount(hg) == 2, tostring(W.store:refcount(hg)))
test("the copy counts as the pack's own", W:info("pack", "art").plain_bytes == #"painted over")
local again = W:edit("pack", "art", "Textures/grass.blp")
test("editing it again changes nothing", again and #again == 0)
local all = W:edit("pack", "art")
test("edit with no path: every remaining link in the pack", all and #all == 1 and all[1] == "sword.mdx"
    and not islink(CD .. "/asset-packs/art/sword.mdx"))
W:edit("map", "A")
W:edit("map", "B")
local removed = W:gc()
test("once nothing links to a stored file, gc removes it", removed == 2 and not W.store:exists(hg), tostring(removed))
test("edit names a map or pack that isn't there", W:edit("map", "Nowhere") == nil)
test("edit refuses a path outside the folder", errors(W.edit, W, "map", "A", "../B/grass.blp"))
local nothing, why = W.store:unshare(CD .. "/maps/A/no-such.blp")
test("unshare of nothing says so", nothing == nil and why:find("nothing at", 1, true), why)
os.execute("ln -s /etc/hostname " .. sh(CD .. "/maps/A/elsewhere"))
local other, why2 = W.store:unshare(CD .. "/maps/A/elsewhere")
test("unshare leaves a link that leads outside the store", other == nil and why2:find("not into this store", 1, true)
    and islink(CD .. "/maps/A/elsewhere"), why2)

-- a store from before: blobs writable, protect fixes them
local old = W:put("map", "C", "x.blp", "an older blob")
os.execute("chmod 644 " .. sh(W.store:path(old)))
test("protect makes a writable stored file read-only, and counts it", W:protect() == 1 and mode(W.store:path(old)) == "444")
test("protect again: nothing to do", W:protect() == 0)

-- the tool
local CTOOL = "luajit " .. sh(DIR .. "/src/cli/storage.lua") .. " --dir " .. sh(DIR) .. " --data " .. sh(CD)
W:put("pack", "art", "shield.mdx", "a shield")
local cout, ccode = run(CTOOL .. " edit pack art shield.mdx")
test("the tool's edit names the copy to change", ccode == 0 and cout:find("Made 1 file in art its own", 1, true)
    and cout:find(CD .. "/asset-packs/art/shield.mdx", 1, true), cout)
cout, ccode = run(CTOOL .. " edit pack art shield.mdx")
test("and says when there was nothing to do", ccode == 0 and cout:find("already its own copy", 1, true), cout)
cout, ccode = run(CTOOL .. " edit pack")
test("edit without a name is refused", ccode == 2, cout)
os.execute("chmod 644 " .. sh(W.store:path(old)))
cout = run(CTOOL .. " protect")
test("the tool's protect says how many", cout:find("Made 1 stored file read-only", 1, true) ~= nil, cout)
-- }}}

-- {{{ The default folder
print("\n=== The default folder ===")
local ROOT = SCRATCH .. "/project"
os.execute("mkdir -p " .. sh(ROOT .. "/config"))
local conf = io.open(ROOT .. "/config/player-data.lua", "wb")
conf:write('return { folder = "' .. SCRATCH .. '/elsewhere" }')
conf:close()
local moved = storage.open(require("assets.player_data").folder(ROOT))
test("opened through the config file, the store is where it says", moved.folder == SCRATCH .. "/elsewhere"
    and os.rename(SCRATCH .. "/elsewhere/blobs", SCRATCH .. "/elsewhere/blobs"))
-- }}}

os.execute("rm -rf " .. sh(SCRATCH))
print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
