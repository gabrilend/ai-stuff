-- mastodon-typed-text.lua
-- Reconstructs what an author typed into the Mastodon compose box from the
-- rendered HTML stored in an ActivityPub archive, and counts that text the
-- way the compose box counts it. The archive stores what the server RENDERED,
-- not what was typed: markdown emphasis delimiters are consumed into tags
-- (*love* becomes <em>love</em>), so a naive tag-strip silently loses those
-- characters. This module puts the delimiters back before stripping tags,
-- which is both a display-fidelity fix and the heart of golden poem (exactly
-- 1024 characters as composed) qualification. See issue 4-003.

local M = {}

-- {{{ local function restore_delimiters
-- Puts back the typed markdown delimiters that server-side rendering consumed.
-- Plain-string gsubs (no pattern magic beyond the literal <>) so "<b>" cannot
-- accidentally match "<br>" and "<s>" cannot match "<span>". Underscore-style
-- emphasis (_x_) is indistinguishable from asterisk-style in the rendered HTML,
-- so everything restores as asterisks: identical length, near-identical intent.
local DELIMITER_RESTORATIONS = {
    { "<strong>", "**" }, { "</strong>", "**" },
    { "<b>", "**" },      { "</b>", "**" },
    { "<em>", "*" },      { "</em>", "*" },
    { "<i>", "*" },       { "</i>", "*" },
    { "<del>", "~~" },    { "</del>", "~~" },
    { "<s>", "~~" },      { "</s>", "~~" },
    { "<code>", "`" },    { "</code>", "`" },
}

local function restore_delimiters(html)
    for _, pair in ipairs(DELIMITER_RESTORATIONS) do
        -- <, /, > are not Lua-pattern magic characters, and * is only special
        -- in patterns (never in the replacement), so plain gsub is exact here
        html = html:gsub(pair[1], pair[2])
    end
    return html
end
-- }}}

-- {{{ function M.restore
-- HTML from the archive in, reconstructed typed text out. Used for both the
-- displayed poem content and the golden poem content.
function M.restore(html)
    local text = restore_delimiters(html)

    -- paragraph and line-break structure back to the newlines that were typed
    text = text:gsub("<p>", "\n\n")
    -- all BR variants (<br>, <br/>, <br />): Mastodon emits XHTML-style <br />
    text = text:gsub("<br%s*/?>", "\n")

    -- entity decoding: specific entities FIRST, &amp; LAST. Decoding &amp;
    -- first would turn a typed "&lt;" (stored as "&amp;lt;") into a bare "<"
    -- by decoding it twice.
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&quot;", "\"")
    text = text:gsub("&#39;", "'")
    text = text:gsub("&apos;", "'")
    text = text:gsub("&amp;", "&")

    -- legacy mojibake repairs carried over from the original cleaner: specific
    -- observed damage to ^_^ emoticons in this archive. Length-neutral.
    text = text:gsub(" _^", "^_^")
    text = text:gsub("^^_^", "^_^")

    -- NOTE: the original cleaner also deleted backslashes before quotes
    -- (gsub('\\"', '"')). That destroyed typed text: 15 archived poems contain
    -- intentional programming-style \" sequences ("the \"or\" operator").
    -- Deliberately NOT reproduced here. See issue 4-003, August 2026.

    -- everything not already translated is markup the author never typed
    text = text:gsub("<[^>]+>", "")

    -- the first <p> opens the text with newlines the author never typed;
    -- trailing newlines cannot survive Mastodon's own posting whitespace-strip
    text = text:gsub("^\n+", ""):gsub("\n+$", "")
    return text
end
-- }}}

-- {{{ function M.composer_length
-- Length of a UTF-8 string as the compose box counter reported it to the
-- author: one per character regardless of byte width (a curly quote is 3
-- bytes but counted 1), one per emoji even from the astral plane, and zero
-- for the invisible glue codepoints (variation selectors, zero-width joiner)
-- that emoji pickers attach -- the author saw one heart, the counter charged
-- one. Empirically anchored: two archived poems sit at exactly 1024 under
-- this model and at 1025 under UTF-16-unit counting, and nothing above 1024
-- could be typed into the box at all. Approximates grapheme clustering;
-- multi-person ZWJ emoji sequences may still count their visible components.
function M.composer_length(s)
    local count, i, len = 0, 1, #s
    while i <= len do
        local b = s:byte(i)
        if b < 0x80 then
            i = i + 1
            count = count + 1
        elseif b < 0xE0 then
            i = i + 2
            count = count + 1
        elseif b < 0xF0 then
            -- 3-byte char: decode enough to spot the invisible glue
            local b2, b3 = s:byte(i + 1), s:byte(i + 2)
            local cp = (b % 0x10) * 0x1000 + (b2 % 0x40) * 0x40 + (b3 % 0x40)
            local invisible = (cp >= 0xFE00 and cp <= 0xFE0F) -- variation selectors
                or cp == 0x200D                               -- zero-width joiner
            i = i + 3
            if not invisible then
                count = count + 1
            end
        else
            i = i + 4
            count = count + 1 -- astral emoji: one visible character, count 1
        end
    end
    return count
end
-- }}}

-- {{{ local function price_anchors
-- Applies the compose box's link accounting before tags are stripped.
-- Mention anchors (class="u-url mention") flatten to their visible "@user"
-- text, which is exactly what the compose box charged for a typed
-- @user@domain. Hashtag anchors keep their visible "#tag" text. Every other
-- anchor is a URL, and the compose box charges a flat 23 characters no
-- matter how long the URL is -- so the whole anchor (including the invisible
-- spans holding the untruncated URL) becomes a 23-character placeholder.
local URL_PLACEHOLDER = string.rep("x", 23)

local function price_anchors(html)
    return html:gsub("<a%s([^>]*)>(.-)</a>", function(attrs, inner)
        if attrs:find("mention", 1, true) or attrs:find("hashtag", 1, true) then
            return inner -- visible text survives; tags inside stripped later
        end
        return URL_PLACEHOLDER
    end)
end
-- }}}

-- {{{ function M.compose_box_count
-- The number the author watched while composing: reconstructed typed text
-- plus content warning text, in composer characters, with URLs priced at 23
-- and mentions at their local part. Golden poems are the ones where this
-- reached exactly 1024.
function M.compose_box_count(html, content_warning)
    local text = M.restore(price_anchors(html))

    -- plain-text mentions the server never linkified (@user@domain typed in
    -- the box) are still priced at @user by the compose counter; the domain
    -- part rides free. Anchor-form mentions already flattened to bare @user.
    -- Character set mirrors the privacy code's mention pattern.
    text = text:gsub("@([%w%.%-_]+)@[%w%.%-]+%.%w+", "@%1")

    local count = M.composer_length(text)
    if content_warning and content_warning ~= "" then
        count = count + M.composer_length(content_warning)
    end
    return count
end
-- }}}

return M
