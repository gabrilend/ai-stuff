-- {{{ Color palette for the game
local Colors = {}

-- {{{ Basic colors
Colors.BLACK = {0, 0, 0, 1}
Colors.WHITE = {1, 1, 1, 1}
Colors.RED = {1, 0, 0, 1}
Colors.GREEN = {0, 1, 0, 1}
Colors.BLUE = {0, 0, 1, 1}
Colors.YELLOW = {1, 1, 0, 1}
Colors.CYAN = {0, 1, 1, 1}
Colors.MAGENTA = {1, 0, 1, 1}
Colors.GRAY = {0.5, 0.5, 0.5, 1}
Colors.DARK_GRAY = {0.25, 0.25, 0.25, 1}
Colors.LIGHT_GRAY = {0.75, 0.75, 0.75, 1}
Colors.LIGHT_BLUE = {0.6, 0.8, 1, 1}
Colors.LIGHT_RED = {1, 0.6, 0.6, 1}
-- }}}

-- {{{ Player colors (colorblind-friendly and high contrast)
Colors.PLAYER_1 = {0.0, 0.3, 0.7, 1}      -- Dark blue (high contrast)
Colors.PLAYER_2 = {0.9, 0.5, 0.0, 1}      -- Bright orange (high contrast)
Colors.PLAYER_1_DARK = {0.0, 0.2, 0.5, 1}  -- Very dark blue
Colors.PLAYER_2_DARK = {0.7, 0.3, 0.0, 1}  -- Dark orange

-- Team aliases for map rendering
Colors.TEAM_A = {0.1, 0.4, 1, 1}          -- Blue team
Colors.TEAM_B = {1, 0.3, 0.1, 1}          -- Orange-red team

-- High contrast mode colors (WCAG AAA compliant)
Colors.PLAYER_1_HC = {0.0, 0.0, 0.8, 1}   -- Very dark blue for high contrast
Colors.PLAYER_2_HC = {0.8, 0.4, 0.0, 1}   -- Dark orange for high contrast
-- }}}

-- {{{ Game element colors
Colors.NEUTRAL = {0.7, 0.7, 0.7, 1}     -- Gray for neutral elements
Colors.HEALTH_HIGH = {0.2, 0.8, 0.2, 1} -- Bright green
Colors.HEALTH_MED = {1, 1, 0.2, 1}      -- Yellow
Colors.HEALTH_LOW = {1, 0.2, 0.2, 1}    -- Red
Colors.MANA = {0.4, 0.4, 1, 1}          -- Blue for mana
Colors.EXPERIENCE = {0.8, 0.6, 1, 1}    -- Purple for XP
-- }}}

-- {{{ UI colors
Colors.UI_BG = {0.1, 0.1, 0.1, 0.8}         -- Dark semi-transparent background
Colors.UI_BG_SOLID = {0.15, 0.15, 0.15, 1}  -- Solid dark background
Colors.UI_TEXT = {0.9, 0.9, 0.9, 1}         -- Light gray text
Colors.UI_TEXT_HIGHLIGHT = {1, 1, 1, 1}     -- White for highlighted text
Colors.UI_BORDER = {0.4, 0.4, 0.4, 1}       -- Medium gray borders
Colors.UI_BUTTON = {0.3, 0.3, 0.3, 1}       -- Button background
Colors.UI_BUTTON_HOVER = {0.4, 0.4, 0.4, 1} -- Button hover state
Colors.UI_BUTTON_ACTIVE = {0.5, 0.5, 0.5, 1} -- Button active state
-- }}}

-- {{{ Unit type colors
Colors.UNIT_MELEE = {0.8, 0.6, 0.2, 1}      -- Bronze/brown for melee
Colors.UNIT_RANGED = {0.2, 0.8, 0.4, 1}     -- Green for ranged
Colors.UNIT_TANK = {0.6, 0.6, 0.8, 1}       -- Purple-gray for tanks
Colors.UNIT_SUPPORT = {1, 0.8, 0.4, 1}      -- Gold for support
Colors.UNIT_SPECIAL = {0.8, 0.4, 0.8, 1}    -- Magenta for special units
-- }}}

-- {{{ Environmental colors
Colors.LANE_PATH = {0.3, 0.3, 0.3, 1}       -- Dark gray for paths
Colors.LANE_BORDER = {0.6, 0.6, 0.6, 1}     -- Lighter gray for borders
Colors.SPAWN_POINT = {0.2, 1, 0.8, 1}       -- Cyan for spawn points
Colors.BASE = {0.8, 0.8, 0.2, 1}            -- Yellow for bases
Colors.OBSTACLE = {0.5, 0.3, 0.2, 1}        -- Brown for obstacles
-- }}}

-- {{{ Effect colors
Colors.DAMAGE_INDICATOR = {1, 0.4, 0.4, 1}  -- Red for damage
Colors.HEAL_INDICATOR = {0.4, 1, 0.4, 1}    -- Green for healing
Colors.BUFF_INDICATOR = {0.4, 0.8, 1, 1}    -- Blue for buffs
Colors.DEBUFF_INDICATOR = {1, 0.6, 0.2, 1}  -- Orange for debuffs
Colors.CRITICAL_HIT = {1, 1, 0.4, 1}        -- Bright yellow for crits
-- }}}

-- {{{ Debug colors
Colors.DEBUG_COLLISION = {1, 0, 1, 0.5}     -- Magenta with transparency
Colors.DEBUG_PATH = {0, 1, 1, 0.7}          -- Cyan for pathfinding
Colors.DEBUG_RANGE = {1, 1, 0, 0.3}         -- Yellow for attack ranges
Colors.DEBUG_SELECTION = {1, 1, 1, 0.8}     -- White for selections
Colors.DEBUG_GRID = {0.3, 0.3, 0.3, 0.5}   -- Dark gray for grid
-- }}}

-- {{{ Utility functions

-- {{{ Colors.lerp
function Colors.lerp(color1, color2, t)
    local r = color1[1] + (color2[1] - color1[1]) * t
    local g = color1[2] + (color2[2] - color1[2]) * t
    local b = color1[3] + (color2[3] - color1[3]) * t
    local a = color1[4] + (color2[4] - color1[4]) * t
    return {r, g, b, a}
end
-- }}}

-- {{{ Colors.with_alpha
function Colors.with_alpha(color, alpha)
    return {color[1], color[2], color[3], alpha}
end
-- }}}

-- {{{ Colors.brighten
function Colors.brighten(color, factor)
    factor = factor or 1.2
    return {
        math.min(1, color[1] * factor),
        math.min(1, color[2] * factor),
        math.min(1, color[3] * factor),
        color[4]
    }
end
-- }}}

-- {{{ Colors.darken
function Colors.darken(color, factor)
    factor = factor or 0.8
    return {
        color[1] * factor,
        color[2] * factor,
        color[3] * factor,
        color[4]
    }
end
-- }}}

-- {{{ Colors.get_health_color
function Colors.get_health_color(health_percent)
    if health_percent > 0.7 then
        return Colors.HEALTH_HIGH
    elseif health_percent > 0.3 then
        return Colors.HEALTH_MED
    else
        return Colors.HEALTH_LOW
    end
end
-- }}}

-- {{{ Colors.get_player_color
function Colors.get_player_color(player_id, variant)
    variant = variant or "normal"
    
    if player_id == 1 then
        return variant == "dark" and Colors.PLAYER_1_DARK or Colors.PLAYER_1
    elseif player_id == 2 then
        return variant == "dark" and Colors.PLAYER_2_DARK or Colors.PLAYER_2
    else
        return Colors.NEUTRAL
    end
end
-- }}}

-- {{{ Accessibility functions

-- {{{ Colors.validate_contrast
function Colors.validate_contrast(color1, color2)
    -- Calculate relative luminance for each color
    local function luminance(color)
        local function linearize(component)
            if component <= 0.03928 then
                return component / 12.92
            else
                return math.pow((component + 0.055) / 1.055, 2.4)
            end
        end
        
        local r = linearize(color[1])
        local g = linearize(color[2])
        local b = linearize(color[3])
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    end
    
    local l1 = luminance(color1)
    local l2 = luminance(color2)
    local lighter = math.max(l1, l2)
    local darker = math.min(l1, l2)
    
    local contrast_ratio = (lighter + 0.05) / (darker + 0.05)
    
    return {
        ratio = contrast_ratio,
        aa_normal = contrast_ratio >= 4.5,     -- WCAG AA for normal text
        aa_large = contrast_ratio >= 3.0,      -- WCAG AA for large text
        aaa_normal = contrast_ratio >= 7.0,    -- WCAG AAA for normal text
        aaa_large = contrast_ratio >= 4.5      -- WCAG AAA for large text
    }
end
-- }}}

-- {{{ Colors.simulate_colorblindness
function Colors.simulate_colorblindness(color, type)
    local r, g, b = color[1], color[2], color[3]
    
    if type == "protanopia" then
        -- Red-blind (missing L cones)
        return {
            0.567 * r + 0.433 * g,
            0.558 * r + 0.442 * g,
            0.242 * g + 0.758 * b,
            color[4]
        }
    elseif type == "deuteranopia" then
        -- Green-blind (missing M cones)
        return {
            0.625 * r + 0.375 * g,
            0.7 * r + 0.3 * g,
            0.3 * g + 0.7 * b,
            color[4]
        }
    elseif type == "tritanopia" then
        -- Blue-blind (missing S cones)
        return {
            0.95 * r + 0.05 * g,
            0.433 * g + 0.567 * b,
            0.475 * g + 0.525 * b,
            color[4]
        }
    elseif type == "achromatopsia" then
        -- Complete color blindness (monochromacy)
        local gray = 0.299 * r + 0.587 * g + 0.114 * b
        return {gray, gray, gray, color[4]}
    else
        return color -- No change for unknown types
    end
end
-- }}}

-- {{{ Colors.get_safe_pair
function Colors.get_safe_pair(background_color)
    -- Returns a text color that's guaranteed to have good contrast
    local luminance = 0.299 * background_color[1] + 0.587 * background_color[2] + 0.114 * background_color[3]
    
    if luminance > 0.5 then
        return Colors.BLACK  -- Dark text on light background
    else
        return Colors.WHITE  -- Light text on dark background
    end
end
-- }}}

-- {{{ Colors.validate_palette_accessibility
function Colors.validate_palette_accessibility()
    local results = {}
    
    -- Test key color combinations
    local tests = {
        {"PLAYER_1", "BLACK", "Player 1 on black background"},
        {"PLAYER_2", "BLACK", "Player 2 on black background"},
        {"PLAYER_1", "WHITE", "Player 1 on white background"},
        {"PLAYER_2", "WHITE", "Player 2 on white background"},
        {"UI_TEXT", "UI_BG", "UI text on UI background"},
        {"HEALTH_HIGH", "BLACK", "High health on black"},
        {"HEALTH_LOW", "BLACK", "Low health on black"},
        {"MANA", "BLACK", "Mana on black"}
    }
    
    for _, test in ipairs(tests) do
        local color1 = Colors[test[1]]
        local color2 = Colors[test[2]]
        local description = test[3]
        
        if color1 and color2 then
            local contrast = Colors.validate_contrast(color1, color2)
            table.insert(results, {
                description = description,
                contrast = contrast,
                passed_aa = contrast.aa_normal
            })
        end
    end
    
    return results
end
-- }}}

-- }}} End accessibility functions

-- {{{ Pattern support for colorblind accessibility
Colors.PATTERNS = {
    SOLID = "solid",
    STRIPED = "striped",
    DOTTED = "dotted",
    DASHED = "dashed",
    CROSSED = "crossed",
    THICK_BORDER = "thick_border"
}

-- {{{ Colors.get_pattern_for_color
function Colors.get_pattern_for_color(color)
    -- Assign patterns based on color to help distinguish when colors are hard to see
    if color == Colors.PLAYER_1 then
        return Colors.PATTERNS.SOLID
    elseif color == Colors.PLAYER_2 then
        return Colors.PATTERNS.STRIPED
    elseif color == Colors.NEUTRAL then
        return Colors.PATTERNS.DOTTED
    elseif color == Colors.UNIT_MELEE then
        return Colors.PATTERNS.SOLID
    elseif color == Colors.UNIT_RANGED then
        return Colors.PATTERNS.DASHED
    elseif color == Colors.UNIT_TANK then
        return Colors.PATTERNS.THICK_BORDER
    elseif color == Colors.UNIT_SUPPORT then
        return Colors.PATTERNS.CROSSED
    else
        return Colors.PATTERNS.SOLID
    end
end
-- }}}

-- }}} End pattern support

-- }}} End utility functions

return Colors
-- }}}