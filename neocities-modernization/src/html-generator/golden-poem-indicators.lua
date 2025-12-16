#!/usr/bin/env lua

-- Golden Poem Visual Indicators System
-- Provides functions for generating golden poem visual indicators and badges

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")

local M = {}

-- {{{ function M.escape_html
function M.escape_html(text)
    if not text then return "" end
    return tostring(text)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&#39;")
end
-- }}}

-- {{{ function M.generate_golden_indicator
function M.generate_golden_indicator(poem, display_type, options)
    display_type = display_type or "full"
    options = options or {}
    
    if not poem or not poem.is_fediverse_golden then
        return ""
    end
    
    local character_count = poem.character_count or poem.length or 1024
    
    if display_type == "full" then
        return string.format([[
<div class="golden-badge" role="banner" aria-label="Perfect Fediverse Length Poem">
    <span class="sr-only">This poem has achieved perfect fediverse formatting with exactly %d characters</span>
    <span class="golden-icon" aria-hidden="true">✨</span>
    <span class="golden-text">Perfect Fediverse Length</span>
    <span class="golden-count">%d characters</span>
</div>]], character_count, character_count)
        
    elseif display_type == "compact" then
        return string.format([[<span class="golden-compact" title="Perfect Fediverse Length: %d characters" aria-label="Golden poem indicator">
    <span class="golden-icon" aria-hidden="true">✨</span>Golden
</span>]], character_count)
        
    elseif display_type == "list" then
        return " ✨"
        
    elseif display_type == "icon" then
        return '<span class="golden-icon" title="Golden poem" aria-label="Golden poem indicator">✨</span>'
        
    else
        return ""
    end
end
-- }}}

-- {{{ function M.generate_character_count_display
function M.generate_character_count_display(poem, options)
    options = options or {}
    
    if not poem.character_count and not poem.length then
        return ""
    end
    
    local count = poem.character_count or poem.length
    local count_class = poem.is_fediverse_golden and "character-count golden" or "character-count"
    local achievement_text = poem.is_fediverse_golden and " (Perfect Fediverse Length!)" or ""
    
    return string.format([[
<div class="%s" aria-label="Character count: %d%s">
    <strong>Character Count:</strong> %d%s
</div>]], count_class, count, achievement_text, count, achievement_text)
end
-- }}}

-- {{{ function M.enhance_similarity_list_with_golden
function M.enhance_similarity_list_with_golden(recommendations, options)
    options = options or {}
    local enhanced_html = ""
    
    for i, rec in ipairs(recommendations) do
        local item_class = rec.is_golden and ' class="golden-poem"' or ""
        local golden_indicator = rec.is_golden and " ✨" or ""
        local title = M.escape_html(rec.title or ("Poem " .. rec.id))
        
        -- Add aria-label for golden poems
        local aria_label = rec.is_golden and 
            string.format(' aria-label="%s - Golden poem with perfect fediverse length"', title) or ""
        
        enhanced_html = enhanced_html .. string.format(
            '<li%s%s><a href="%s">%s</a>%s <span class="similarity-score">(%.3f similarity)</span></li>\n',
            item_class,
            aria_label,
            rec.url or "",
            title,
            golden_indicator,
            rec.score or 0
        )
    end
    
    return enhanced_html
end
-- }}}

-- {{{ function M.generate_golden_statistics_display
function M.generate_golden_statistics_display(total_poems, golden_count, options)
    options = options or {}
    
    if not golden_count or golden_count == 0 then
        return ""
    end
    
    local percentage = (golden_count / total_poems) * 100
    
    return string.format([[
<div class="golden-statistics" role="region" aria-label="Golden poem collection statistics">
    <h4>✨ Golden Poem Collection</h4>
    <p><strong>%d</strong> poems achieve the perfect fediverse length of 1024 characters</p>
    <p><em>%.1f%% of the complete poetry collection</em></p>
    <p><a href="poems/golden/index.html" aria-label="Browse all %d golden poems">Browse all golden poems →</a></p>
</div>]], golden_count, percentage, golden_count)
end
-- }}}

-- {{{ function M.generate_golden_help_tooltip
function M.generate_golden_help_tooltip(options)
    options = options or {}
    
    return [[
<div class="golden-help" role="tooltip" id="golden-help-tooltip">
    <button class="help-icon" aria-describedby="golden-help-content" aria-label="Information about golden poems">?</button>
    <div class="tooltip-content" id="golden-help-content" role="tooltip">
        <strong>Golden Poems</strong><br>
        Exactly 1024 characters<br>
        Perfect for fediverse sharing<br>
        Artistic constraint achievement
    </div>
</div>]]
end
-- }}}

-- {{{ function M.generate_golden_poem_teaser
function M.generate_golden_poem_teaser(options)
    options = options or {}
    
    return [[
<aside class="golden-teaser" role="complementary" aria-label="Golden poem collection information">
    <h3>✨ Discover Perfect Fediverse Poems</h3>
    <p>Explore our collection of exactly 1024-character poems, 
       perfectly crafted for sharing on the fediverse.</p>
    <a href="poems/golden/index.html" class="golden-cta" aria-label="Browse the golden poem collection">
        Browse Golden Collection →
    </a>
</aside>]]
end
-- }}}

-- {{{ function M.add_golden_indicators_to_template_data
function M.add_golden_indicators_to_template_data(poem, template_data)
    template_data = template_data or {}
    
    -- Add golden poem indicator (full badge)
    template_data.GOLDEN_POEM_INDICATOR = M.generate_golden_indicator(poem, "full")
    
    -- Add character count display with golden styling
    template_data.CHARACTER_COUNT_DISPLAY = M.generate_character_count_display(poem)
    
    -- Add compact golden indicator for use in titles or lists
    template_data.GOLDEN_COMPACT_INDICATOR = M.generate_golden_indicator(poem, "compact")
    
    -- Add golden icon only
    template_data.GOLDEN_ICON = M.generate_golden_indicator(poem, "icon")
    
    -- Add golden status flag for conditional rendering
    template_data.IS_GOLDEN_POEM = poem.is_fediverse_golden and "true" or "false"
    
    return template_data
end
-- }}}

-- {{{ function M.validate_golden_poem_indicators
function M.validate_golden_poem_indicators(html_content)
    if not html_content then
        return {valid = false, error = "No HTML content provided"}
    end
    
    local validation = {
        valid = true,
        checks = {},
        warnings = {}
    }
    
    -- Check for golden poem indicators
    local has_golden_badge = html_content:match('<div class="golden%-badge"')
    local has_golden_icon = html_content:match('✨') or html_content:match('class="golden%-icon"')
    local has_golden_list_items = html_content:match('class="golden%-poem"')
    local has_character_count = html_content:match('class="character%-count')
    
    -- Validate accessibility attributes
    local has_aria_labels = html_content:match('aria%-label=') or html_content:match('aria%-describedby=')
    local has_screen_reader_content = html_content:match('class="sr%-only"')
    local has_role_attributes = html_content:match('role="')
    
    -- Record checks
    table.insert(validation.checks, {name = "Golden badge present", passed = has_golden_badge})
    table.insert(validation.checks, {name = "Golden icons present", passed = has_golden_icon})
    table.insert(validation.checks, {name = "Character count display", passed = has_character_count})
    table.insert(validation.checks, {name = "Accessibility attributes", passed = has_aria_labels})
    table.insert(validation.checks, {name = "Screen reader support", passed = has_screen_reader_content})
    table.insert(validation.checks, {name = "ARIA roles", passed = has_role_attributes})
    
    -- Warnings for missing but optional elements
    if not has_golden_list_items then
        table.insert(validation.warnings, "No golden poem list items found (may be expected)")
    end
    
    if not has_screen_reader_content then
        table.insert(validation.warnings, "Screen reader content missing")
    end
    
    -- Overall validation
    local passed_checks = 0
    for _, check in ipairs(validation.checks) do
        if check.passed then passed_checks = passed_checks + 1 end
    end
    
    validation.valid = passed_checks >= 4  -- Require at least 4/6 checks to pass
    validation.score = passed_checks / #validation.checks
    
    return validation
end
-- }}}

-- {{{ function M.get_golden_indicator_css_classes
function M.get_golden_indicator_css_classes()
    return {
        "golden-badge",
        "golden-icon", 
        "golden-text",
        "golden-count",
        "golden-poem",
        "golden-compact",
        "golden-statistics",
        "golden-help",
        "golden-teaser",
        "character-count",
        "sr-only"
    }
end
-- }}}

return M