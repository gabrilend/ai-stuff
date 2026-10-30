-- rate.lua - the viewer's own few lines for a film's card: read the tier
-- that counts, and append one rating.
--
-- In general terms: every film has a card beside it (NAME.gif.card, issue
-- 701e) with its ratings appended one per line. Pressing 1 to 5 in the
-- viewer adds a line. The maker (src/055-cards.lua) and the viewer share no
-- code; what they agree on is the card's text, in docs/card-format.md. Plain
-- Lua, no LÖVE, so the tests can run it on its own.

local rate = {}

-- {{{ function rate.card_path()
function rate.card_path(gif_path) return gif_path .. ".card" end
-- }}}

-- {{{ function rate.tier()
-- The tier that counts for the film as it is now: the last rating after the
-- last "refilmed" line. Returns nil when not rated; false when there is no
-- card at all.
function rate.tier(card_path)
    local handle = io.open(card_path, "r")
    if not handle then return false end
    local tier = nil
    for line in handle:lines() do
        local given = line:match("^%- (%d) by %S+ on %S+")
        if given then
            tier = tonumber(given)
        elseif line:match("^%- refilmed on ") then
            tier = nil
        end
    end
    handle:close()
    return tier
end
-- }}}

-- {{{ function rate.append()
-- One rating by a person, appended to the card. A film with no card is not
-- rated (the maker writes cards; `./count-films --write` makes the missing
-- ones), so this returns false and says why.
function rate.append(card_path, tier, date)
    if tier % 1 ~= 0 or tier < 1 or tier > 5 then
        return false, "a tier is 1 to 5"
    end
    local probe = io.open(card_path, "r")
    if not probe then return false, "no card yet: ./count-films --write" end
    probe:close()
    local handle = io.open(card_path, "a")
    if not handle then return false, "the card cannot be written" end
    handle:write(string.format("- %d by person on %s\n", tier, date or os.date("%Y-%m-%d")))
    handle:close()
    return true
end
-- }}}

return rate
