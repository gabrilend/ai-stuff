-- framing-test.lua - checks that a scene keeps its promises about the picture.
--
-- What this is, generally: a moving camera can wander away from what it is
-- filming. A scene may promise, in its `framing = { tag, at_least, margin }`,
-- that in every frame at least that many shapes carrying the tag have their
-- centre inside the picture (kept `margin` in from the edges) and in front of
-- the lens. This walks every frame of every scene that makes the promise,
-- using the painter's own projection, and reports the worst frame.
--
-- Two more promises a scene may make, checked the same way:
--   clearance = { { tag, radius }, ... } -- the lens never comes within
--     `radius` of a visible shape carrying the tag (the camera never flies
--     through a jellyfish); checked at every frame and three moments between.
--     With `column = true` the shape is an upright post (a tree trunk from
--     the ground up): the distance is measured level, to its upright line,
--     at any height
--   spacing = { tags = {...}, at_least = d } -- no two visible shapes with
--     those tags are ever closer than d, centre to centre (balls on a hill
--     never overlap)
--
-- Usage: luajit framing-test.lua DIR [scene-name ...]
-- Prints one line per scene; exits 1 if any scene breaks its promise.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/delta-version/scripts/readme-gallery"
local meshes = dofile(DIR .. "/meshes.lua")
local choreography = dofile(DIR .. "/choreography.lua")
local fluid = dofile(DIR .. "/fluid.lua")
local raster = dofile(DIR .. "/raster.lua")

local HUES = {
    rose = { 1, 0.2, 0.45 }, ember = { 1, 0.42, 0.1 }, gold = { 1, 0.8, 0.15 },
    jade = { 0.15, 1, 0.35 }, teal = { 0.1, 0.9, 0.8 }, ice = { 0.4, 0.7, 1 },
    violet = { 0.55, 0.25, 1 }, cloud = { 1, 1, 1 },
}

-- {{{ local function scene_paths()
local function scene_paths()
    local list = {}
    if #arg > 1 then
        for i = 2, #arg do list[#list + 1] = DIR .. "/scenes/" .. arg[i] .. ".lua" end
        return list
    end
    local pipe = io.popen(string.format("ls %q", DIR .. "/scenes"))
    for line in pipe:lines() do
        if line:match("%.lua$") then list[#list + 1] = DIR .. "/scenes/" .. line end
    end
    pipe:close()
    return list
end
-- }}}

-- {{{ local function in_view_count()
-- How many shapes with the tag stand inside the picture at moment t.
local function in_view_count(scene, canvas, t)
    raster.set_view(canvas, choreography.camera(scene, t))
    local margin = scene.framing.margin or 0.04
    local count = 0
    for _, item in ipairs(choreography.pose(scene, t)) do
        if item.tag == scene.framing.tag and item.scale > 0.05 then
            local fx, fy, depth = raster.project_point(canvas, item.position[1], item.position[2], item.position[3])
            if depth > 0.3 and fx >= margin and fx <= 1 - margin and fy >= margin and fy <= 1 - margin then
                count = count + 1
            end
        end
    end
    return count
end
-- }}}

-- {{{ local function distance()
local function distance(a, b)
    return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end
-- }}}

local failed, checked = 0, 0
for _, path in ipairs(scene_paths()) do
    local scene = choreography.load(dofile(path), HUES, meshes, fluid)
    if scene.clearance then
        checked = checked + 1
        local worst, worst_tag, worst_margin = math.huge, "", 0
        local steps = scene.frames * 4
        for k = 0, steps - 1 do
            local t = k / steps
            local eye = choreography.camera(scene, t).eye
            for _, item in ipairs(choreography.pose(scene, t)) do
                for _, rule in ipairs(scene.clearance) do
                    if item.tag == rule.tag and item.scale > 0.05 then
                        -- two measures: straight to a point, or level to an upright post
                        local d = rule.column
                            and math.sqrt((eye[1] - item.position[1]) ^ 2 + (eye[3] - item.position[3]) ^ 2)
                            or distance(eye, item.position)
                        local margin = d - rule.radius
                        if margin < worst then worst, worst_tag = margin, rule.tag end
                    end
                end
            end
        end
        local ok = worst >= 0
        if not ok then failed = failed + 1 end
        print(string.format("  %s - %s: the lens never comes within reach of what it passes (closest: %.2f to spare, a %s)",
            ok and "ok  " or "FAIL", scene.name, worst, worst_tag))
    end
    if scene.spacing then
        checked = checked + 1
        local wanted = {}
        for _, tag in ipairs(scene.spacing.tags) do wanted[tag] = true end
        local closest, at_frame = math.huge, 0
        for frame = 1, scene.frames do
            local shown = {}
            for _, item in ipairs(choreography.pose(scene, (frame - 1) / scene.frames)) do
                if wanted[item.tag] and item.scale > 0.05 then shown[#shown + 1] = item end
            end
            for i = 1, #shown do for j = i + 1, #shown do
                -- a shape and what it becomes are one family, not a crowd
                local same = shown[i].family and shown[i].family == shown[j].family
                local d = same and math.huge or distance(shown[i].position, shown[j].position)
                if d < closest then closest, at_frame = d, frame end
            end end
        end
        local ok = closest >= scene.spacing.at_least
        if not ok then failed = failed + 1 end
        print(string.format("  %s - %s: no two of %s ever closer than %.2f (closest %.2f, frame %d)",
            ok and "ok  " or "FAIL", scene.name, table.concat(scene.spacing.tags, "/"), scene.spacing.at_least,
            closest, at_frame))
    end
    if scene.framing then
        checked = checked + 1
        local canvas = raster.new(scene.size, scene.camera or {}, meshes)
        local worst, worst_frame, total = math.huge, 0, 0
        for frame = 1, scene.frames do
            local n = in_view_count(scene, canvas, (frame - 1) / scene.frames)
            total = total + n
            if n < worst then worst, worst_frame = n, frame end
        end
        local ok = worst >= scene.framing.at_least
        if not ok then failed = failed + 1 end
        print(string.format("  %s - %s: at least %d '%s' in view every frame (worst frame %d has %d; average %.1f)",
            ok and "ok  " or "FAIL", scene.name, scene.framing.at_least, scene.framing.tag,
            worst_frame, worst, total / scene.frames))
    end
end
print(string.format("%d scenes checked, %d failed", checked, failed))
os.exit(failed == 0 and 0 or 1)
