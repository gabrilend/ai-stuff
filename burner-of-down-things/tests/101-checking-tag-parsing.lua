-- 101-checking-tag-parsing.lua
--
-- Checks issue 901b: a well-formed tag's number and wish are read; a
-- malformed one is a finding naming the right form; a parcel with no tag
-- at all is still accepted, not an error.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local parcel = require("079-the-parcel")

local tagged_folder = kit.scratch("tagged-parcel")
kit.write_file(tagged_folder .. "/a.txt", "language model prompt 42: draw a circle\nmore text\n")
local tagged = parcel.read(tagged_folder)
local number, wish = parcel.tag(tagged)
kit.equal(number, 42, "a well-formed tag's number is read")
kit.equal(wish, "draw a circle", "a well-formed tag's wish is read")

local malformed_folder = kit.scratch("malformed-tag-parcel")
kit.write_file(malformed_folder .. "/a.txt", "language model prompt: draw a circle\n")
local malformed = parcel.read(malformed_folder)
local malformed_number, finding = parcel.tag(malformed)
kit.equal(malformed_number, nil, "a malformed tag reads no number")
kit.check(finding ~= nil, "a malformed tag is a finding")
kit.check(finding ~= nil and finding:find("language model prompt <number>: <what is wanted>", 1, true) ~= nil,
    "the finding names the right form")

local promptly_folder = kit.scratch("promptly-parcel")
kit.write_file(promptly_folder .. "/a.txt", "language model promptly finish this\n")
local promptly = parcel.read(promptly_folder)
local promptly_number, promptly_second = parcel.tag(promptly)
kit.equal(promptly_number, nil, "a different word starting the same way reads no number")
kit.equal(promptly_second, nil, "a different word starting the same way is not a finding")

local untagged_folder = kit.scratch("untagged-parcel")
kit.write_file(untagged_folder .. "/a.txt", "just an ordinary source file\n")
local untagged = parcel.read(untagged_folder)
local untagged_number, untagged_second = parcel.tag(untagged)
kit.equal(untagged_number, nil, "no tag at all reads no number")
kit.equal(untagged_second, nil, "no tag at all is not a finding")

kit.finish()
