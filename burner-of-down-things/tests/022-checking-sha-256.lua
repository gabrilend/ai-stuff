-- 022-checking-sha-256.lua
--
-- Checks SHA-256 (issue 103) against the standard's own test vectors, and
-- file hashing against the system's sha256sum at every size near a block
-- boundary, where padding mistakes hide.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local sha_256 = require("015-sha-256")
local fs = kit.fs

local VECTORS = {
    { "", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" },
    { "abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" },
    { "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1" },
    { "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
        "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1" },
    { string.rep("a", 1000000), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0" },
}
for i, v in ipairs(VECTORS) do
    kit.equal(sha_256.of_string(v[1]), v[2], "standard vector " .. i)
end

kit.raises(function() sha_256.of_string(42) end, "must be a string", "a number is refused")

local folder = kit.scratch("sha")
for _, size in ipairs({ 0, 1, 55, 56, 63, 64, 65, 119, 120, 128, 65535, 65536, 65537, 1048576 }) do
    local path = folder .. "/f" .. size
    local bytes = {}
    for i = 1, size do
        bytes[i] = string.char((i * 7 + 3) % 256)
    end
    kit.write_file(path, table.concat(bytes))
    local out = fs.capture("sha256sum " .. fs.quote(path))
    kit.equal(sha_256.of_file(path), out:match("^(%x+)"), "file of " .. size .. " bytes matches sha256sum")
end
kit.raises(function() sha_256.of_file(folder .. "/missing") end, "cannot open", "a missing file is refused")

kit.finish()
