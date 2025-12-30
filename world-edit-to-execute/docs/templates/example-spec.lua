-- Example Quest Specification File
-- Run with: luajit src/cli/quest-generator.lua from-spec docs/templates/example-spec.lua

return {
    -- Project metadata
    project = "WORLD EDIT TO EXECUTE",
    motto = "Start small. Slay slimes. Then dragons.",
    intro = [[
Welcome, brave adventurer. Before you stand against the Boss Monsters
documented in the Bounty Hall, you must hone your skills on lesser creatures.

Each quest teaches you something about the codebase. Complete them in order.
By the time you reach the bosses, you'll have the weapons you need.]],
    maintainer = "The Guild of Careful Coders",

    -- Quest definitions
    quests = {
        -- Seedling tier
        {
            id = "S1",
            name = "The Trimmed Tale",
            tier = "seedling",
            file = "src/parsers/wts.lua",
            line = "48-52",
            xp = 50,
            skill = "Parser Edge Cases",
            flavor = "The trigger strings speak, but their first words are stolen. A newline, intentionally placed, vanishes into the void.",
            code = [[text = text:gsub("^\n", ""):gsub("\n$", "")]],
            problem_comment = "Strips legitimate leading/trailing newlines",
            tasks = {
                "Add a flag to preserve intentional whitespace",
                "Or document this as intended behavior",
                "Test with a WTS file containing TRIGSTR_001 = \"\\nHello\""
            },
            reward = "Understanding of the WTS format, parser modification basics."
        },
        {
            id = "S2",
            name = "The Ghostly Zero",
            tier = "seedling",
            file = "src/jass/transpiler.lua",
            line = "879",
            xp = 75,
            skill = "Silent Error Detection",
            flavor = "The FourCC speaks its name, but when malformed, it whispers only zero. Is it truly zero, or is it lying?",
            code = [[if not str or #str ~= 4 then
    return 0  -- Silent failure
end]],
            problem_comment = "Indistinguishable from valid 0x00000000",
            tasks = {
                "Return an error indicator for invalid FourCC",
                "Or add a warning/log message",
                "Test with 'foo' (3 chars) and '12345' (5 chars)"
            },
            reward = "The add_error() function becomes your ally."
        },

        -- Apprentice tier
        {
            id = "A1",
            name = "The Floating Falsehood",
            tier = "apprentice",
            file = "src/runtime/pathfinding/smooth.lua",
            line = "80",
            xp = 100,
            skill = "Floating Point Awareness",
            flavor = "Three points lie on a line. The math says so. But the computer disagrees by 0.0000000001.",
            code = [[local cross = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
return cross == 0  -- FLOATING POINT EQUALITY IS A LIE]],
            problem_comment = "Direct float comparison fails",
            tasks = {
                "Replace == 0 with math.abs(cross) < EPSILON",
                "Choose appropriate EPSILON (1e-9 suggested)",
                "Test with points that should be collinear but have float coords"
            },
            reward = "You learn the ancient wisdom: \"Never compare floats directly.\""
        },

        -- Journeyman tier
        {
            id = "J1",
            name = "The Boundary Crasher",
            tier = "journeyman",
            file = "src/compat.lua",
            line = "98-107",
            xp = 200,
            skill = "Binary Safety",
            flavor = "The blacksmith gave me this piece of data storage. But when the scroll is torn short, the function reaches into the void and crashes.",
            code = [[compat.unpack_uint32 = function(data, pos)
    pos = pos or 1
    local b1, b2, b3, b4 = data:byte(pos, pos + 3)  -- No bounds check!
    return bytes_to_uint32(b1, b2, b3, b4), pos + 4
end]],
            problem_comment = "If data is too short, b1-b4 are nil, arithmetic fails",
            tasks = {
                "Check #data >= pos + 3 before unpacking",
                "Return nil, pos, \"Truncated data\" on failure",
                "Update all callers to handle the error",
                "Test with truncated MPQ files"
            },
            reward = "The compat module becomes robust. Malformed files no longer crash."
        },
    },

    -- Boss bounties
    bounties = {
        { id = "B01", name = "The Phantom Priority", file = "B01-the-phantom-priority.md", threat = 8 },
        { id = "B02", name = "The Eternal Timer", file = "B02-the-eternal-timer.md", threat = 7 },
        { id = "B03", name = "The Hivemind Component", file = "B03-the-hivemind-component.md", threat = 7 },
    }
}
