-- sources.lua - the public sites maps and models could be fetched from (issue 603)
--
-- For the owner to review before anything is fetched from any of them. Each
-- site is listed with what it is thought to host. Its terms and robots.txt
-- are to be read and quoted here at the review; until then "terms" and
-- "robots" are nil, and the site's access is "unreviewed".
--
-- access:
--   "unreviewed"    never fetched (the starting state of every site)
--   "visit by hand" never fetched: its terms forbid automated access
--   "allowed"       reviewed by the owner; fetched only when the player asks
--                   and passes --network
--
-- The addresses are the sites' home pages, to be confirmed at the review.
-- Candidates from issue 603's open question 1 (Hive Workshop first, owner
-- 2026-09-26).

return {
    {
        name = "hive-workshop",
        title = "Hive Workshop",
        base = "https://www.hiveworkshop.com",
        hosts = { "maps", "models" },
        terms = nil,
        robots = nil,
        feed = nil,
        access = "unreviewed",
        note = "the owner's first choice (2026-09-26)",
    },
    {
        name = "epic-war",
        title = "Epic War",
        base = "https://www.epicwar.com",
        hosts = { "maps" },
        access = "unreviewed",
    },
    {
        name = "wc3maps",
        title = "WC3Maps",
        base = "https://www.wc3maps.com",
        hosts = { "maps" },
        access = "unreviewed",
    },
    {
        name = "xgm",
        title = "XGM",
        base = "https://xgm.guru",
        hosts = { "maps", "models" },
        access = "unreviewed",
        note = "Russian-language modding community",
    },
    {
        name = "moddb",
        title = "ModDB",
        base = "https://www.moddb.com",
        hosts = { "maps" },
        access = "unreviewed",
        note = "some total conversions",
    },
    {
        name = "internet-archive",
        title = "Internet Archive",
        base = "https://archive.org",
        hosts = { "maps" },
        access = "unreviewed",
        note = "collections of old map packs",
    },
}
