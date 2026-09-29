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

return parcel
