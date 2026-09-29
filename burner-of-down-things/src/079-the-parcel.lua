-- 079-the-parcel.lua
--
-- What arrives at the switchboard: one or more files dropped in a folder,
-- read as one unit (docs/068, issue 901a). Reading a tag (901b), issuing a
-- number (901c) and refusing a reused one (901d) are later pieces built on
-- this read.

local fs = require("017-the-filesystem")

local parcel = {}

-- {{{ function parcel.read
-- Reads every file currently in `folder` as one parcel. An empty or
-- missing folder reads as no parcel (nil) — nothing has arrived yet, which
-- is the ordinary case between drops, not an error.
function parcel.read(folder)
    if not fs.is_folder(folder) then
        return nil
    end
    local names = fs.list(folder)
    if #names == 0 then
        return nil
    end
    local files = {}
    for _, name in ipairs(names) do
        files[#files + 1] = { name = name, path = folder .. "/" .. name }
    end
    return { folder = folder, files = files }
end
-- }}}

-- {{{ function parcel.tag
-- Reads a parcel's tag: its first file's first line (files are name-sorted
-- by 017's list), `language model prompt <number>: <what is wanted>`. A
-- first line that does not open with those words carries no tag at all --
-- ordinary, and the router works it out from contents alone (902/904), so
-- this returns nil. One that opens with them but does not fit the rest is a
-- malformed attempt, not a crash: nil, and a finding naming the right form.
-- A well-formed tag reads as number, wish.
function parcel.tag(p)
    local line = fs.read(p.files[1].path):match("^([^\n]*)")
    -- %f[%A] is a word-boundary check, so "language model promptly ..."
    -- (a different word) does not read as an attempted, malformed tag.
    if not line:match("^language model prompt%f[%A]") then
        return nil
    end
    local number, wish = line:match("^language model prompt (%d+): (.+)$")
    if not number then
        return nil, "a tag must read 'language model prompt <number>: <what is wanted>', not '" .. line .. "'"
    end
    return tonumber(number), wish
end
-- }}}

return parcel
