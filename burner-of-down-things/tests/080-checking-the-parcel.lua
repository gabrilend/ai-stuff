-- 080-checking-the-parcel.lua
--
-- Checks issue 901a: a folder with three files reads as one parcel of
-- three; an empty folder reads as no parcel, not an error.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local parcel = require("079-the-parcel")

local folder = kit.scratch("parcel")
kit.write_file(folder .. "/a.txt", "one")
kit.write_file(folder .. "/b.txt", "two")
kit.write_file(folder .. "/c.txt", "three")

local read = parcel.read(folder)
kit.check(read ~= nil, "a folder with files reads as a parcel")
kit.equal(#read.files, 3, "three files read as a parcel of three")

local empty_folder = kit.scratch("empty-parcel")
kit.equal(parcel.read(empty_folder), nil, "an empty folder reads as no parcel")
kit.equal(parcel.read(empty_folder .. "/missing"), nil, "a missing folder reads as no parcel, not an error")

kit.finish()
