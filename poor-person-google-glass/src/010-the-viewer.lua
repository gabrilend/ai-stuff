-- 010-the-viewer.lua - the CAD viewer's window: a shape, lit, turned by hand.
--
-- In plain terms: the file is read into a shape record (001, through 006)
-- before this file sees it; here each part's triangles are copied once into
-- the graphics card's memory, and every frame the card is told where the
-- camera is (009) and draws them. Nothing here knows any file format.
--
-- Every frame is drawn into an off-screen picture (a canvas) first, and the
-- canvas is then shown in the window. Screenshots save the canvas, never
-- the screen: a program reading the screen gets whatever is on the screen,
-- and the first screenshots of this viewer came back black because the
-- owner was playing a game over it (2026-10-10). From the canvas a picture
-- is right whether the window is visible, covered, or on another desktop.
--
-- Views are filters on the same shape, kept in a dispatch table (VIEWS):
--   lit        the normal look
--   edges      lit, with every triangle's edges
--   parts      each part one flat distinct colour, no light
--   depth      near light, far dark
--   normals    the direction each surface faces, as colour
--   annotated  lit, part names on leader lines, the overall box measured
--
-- Order of a run: read input/ (007), open the window, read the CAD file,
-- frame after frame (update, draw), and on closing write output/goodbye
-- (008). Scripted run options feed the same handlers the mouse and keyboard
-- use, on a timeline, so a run can be checked without a person:
--   --key SECONDS NAME      press a key (the keys listed in KEYS below)
--   --drag SECONDS DX DY    drag with the left button (turn the shape)
--   --pan SECONDS DX DY     drag with the right button (slide the shape)
--   --wheel SECONDS NOTCHES turn the wheel (positive: closer)
--   --screenshot SECONDS    save one picture per view to tmp/shared-memory/,
--                           then close
--   --views NAME,NAME       which views a screenshot saves (default: all)
--
-- Lighting: a light at the camera (a "headlight": whatever faces you is
-- lit) plus a dim light from above, and a floor of ambient light so nothing
-- is pure black. Both sides of a surface are lit the same, because CAD
-- exports often have inside-out triangles, and a viewer that hides them
-- hides the model.

local ffi = require("ffi")
local bit = require("bit")
local settings_reader = require("007-read-the-input")
local goodbye = require("008-say-goodbye")
local camera_math = require("009-the-orbit-camera")
local any_file = require("006-read-any-cad-file")
local record = require("001-the-shape-record")

local viewer = {}

local VIEW_ORDER = { "lit", "edges", "parts", "depth", "normals", "annotated", "joints" }
local records = require("027-joint-records")
local lua_data = require("024-writing-lua-data")

-- The colour of a joint's mark, by its state (issue 010, docs/joints.md).
local JOINT_COLOURS = {
    empty = { 0.55, 0.56, 0.58 },     -- no equation yet
    waiting = { 0.95, 0.78, 0.30 },   -- an equation, not worked out (or changed since)
    pass = { 0.35, 0.85, 0.40 },
    fail = { 0.95, 0.30, 0.25 },
    gone = { 0.40, 0.40, 0.45 },      -- a record whose parts no longer meet
}

-- {{{ SHADER
-- shade_mode: 0 lit, 1 one flat colour, 2 depth, 3 normals as colour.
local SHADER = [[
varying vec3 world_normal;
varying float eye_distance;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;
uniform mat4 model_matrix;
uniform float depth_bias;

#ifdef VERTEX
attribute vec3 VertexNormal;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // the shape's own placement (standing it upright) turns its normals too;
    // it is a pure rotation, so its 3x3 part turns directions correctly
    world_normal = mat3(model_matrix) * VertexNormal;
    vec4 eye = view_matrix * model_matrix * vec4(vertex_position.xyz, 1.0);
    eye_distance = -eye.z;
    vec4 clip = projection_matrix * eye;
    // edges are drawn a hair nearer than the faces they sit on, so they
    // are not hidden by the face they outline
    clip.z -= depth_bias * clip.w;
    return clip;
}
#endif

#ifdef PIXEL
uniform vec3 part_colour;
uniform vec3 toward_camera;
uniform float shade_mode;
uniform vec2 depth_range;
// a model full of liquid or haze (issue 008): its colour, and how quickly
// it thickens with distance (0: no filling). Only the lit look is hazed;
// the flat, depth and normals views stay exact, being measurements.
uniform vec4 filling;
// 1 for a part that gives off light (a beam, the vortex): drawn at its own
// colour, brightened, and seen through only a little of the haze
uniform float glow;
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    if (shade_mode > 0.5 && shade_mode < 1.5) return vec4(part_colour, 1.0);
    if (shade_mode > 1.5 && shade_mode < 2.5) {
        float near_share = 1.0 - clamp((eye_distance - depth_range.x) / (depth_range.y - depth_range.x), 0.0, 1.0);
        // never pure black: the black-pixel check must stay meaningful
        return vec4(vec3(0.08 + 0.92 * near_share), 1.0);
    }
    if (glow > 0.5) {
        float glow_haze = 0.35 * (1.0 - exp(-filling.a * eye_distance));
        return vec4(mix(min(part_colour * 1.25, vec3(1.0)), filling.rgb, glow_haze), 1.0);
    }
    float length_of_normal = length(world_normal);
    // a sliver triangle has no direction: ambient light only
    if (length_of_normal < 1e-6) return vec4(part_colour * 0.3, 1.0);
    vec3 n = world_normal / length_of_normal;
    if (shade_mode > 2.5) return vec4(0.04 + 0.92 * (n * 0.5 + 0.5), 1.0);
    float headlight = abs(dot(n, toward_camera));
    float from_above = abs(n.y);
    float light = 0.22 + 0.63 * headlight + 0.15 * from_above;
    float haze = 1.0 - exp(-filling.a * eye_distance);
    return vec4(mix(part_colour * light, filling.rgb, haze), 1.0);
}
#endif
]]
-- }}}

-- {{{ local function build_meshes()
-- One mesh per part. Corners are written straight into a block of bytes
-- (six floats each: position, then normal) and handed to the card in one
-- piece; a Lua table per corner would cost seconds on a large model.
local function build_meshes(shape)
    local format = { { "VertexPosition", "float", 3 }, { "VertexNormal", "float", 3 } }
    local meshes = {}
    for index, part in ipairs(shape.parts) do
        local corners = #part.positions / 3
        if corners > 0 then
            local data = love.data.newByteData(corners * 6 * 4)
            local floats = ffi.cast("float *", data:getFFIPointer())
            local p, n = part.positions, part.normals
            local cx, cy, cz = 0, 0, 0
            for k = 0, corners - 1 do
                floats[k * 6 + 0], floats[k * 6 + 1], floats[k * 6 + 2] = p[k * 3 + 1], p[k * 3 + 2], p[k * 3 + 3]
                floats[k * 6 + 3], floats[k * 6 + 4], floats[k * 6 + 5] = n[k * 3 + 1], n[k * 3 + 2], n[k * 3 + 3]
                cx, cy, cz = cx + p[k * 3 + 1], cy + p[k * 3 + 2], cz + p[k * 3 + 3]
            end
            local mesh = love.graphics.newMesh(format, corners, "triangles", "static")
            mesh:setVertices(data)
            -- the part's flat colour for the parts view: hues a golden
            -- angle apart, so neighbours in the list never look alike
            local hue = (index * 0.618034) % 1
            meshes[#meshes + 1] = { mesh = mesh, part = part, triangles = corners / 3,
                middle = { cx / corners, cy / corners, cz / corners }, flat = viewer.hue_to_colour(hue) }
        end
    end
    return meshes
end
-- }}}

-- {{{ function viewer.hue_to_colour()
-- A hue 0..1 at full strength and moderate brightness, as {r,g,b}.
function viewer.hue_to_colour(hue)
    local function channel(offset)
        local k = (offset + hue * 6) % 6
        return 0.85 - 0.6 * math.max(0, math.min(k, 4 - k, 1))
    end
    return { channel(5), channel(3), channel(1) }
end
-- }}}

-- {{{ local function make_canvases()
-- The off-screen picture and its depth buffer, the size of the window.
-- Multisampled (4 samples a pixel) for smooth edges.
local function make_canvases()
    local width, height = love.graphics.getDimensions()
    viewer.canvas = love.graphics.newCanvas(width, height, { msaa = 4 })
    viewer.depth_canvas = love.graphics.newCanvas(width, height, { format = "depth24", msaa = 4, readable = false })
end
-- }}}

-- {{{ local function fit_view()
-- Aims the camera at the shape's middle, far enough back to see all of it.
local function fit_view()
    local b = viewer.shape.bounds
    local centre = { (b.min[1] + b.max[1]) / 2, (b.min[2] + b.max[2]) / 2, (b.min[3] + b.max[3]) / 2 }
    local size = record.size(viewer.shape)
    local radius = math.sqrt(size[1] ^ 2 + size[2] ^ 2 + size[3] ^ 2) / 2
    local x, y, z = camera_math.transform(viewer.model_matrix, centre)
    local width, height = love.graphics.getDimensions()
    camera_math.fit(viewer.camera, { x, y, z }, radius, width / height)
end
-- }}}

-- {{{ function viewer.load_joints()
-- The model's joint records (input/joints/MODEL.lua) and their worked-out
-- answers (output/joints/MODEL.results.lua), if there are any, and each
-- joint's state: empty, waiting, pass, fail or gone. Only read here; finding
-- and working out are ./joints's job (028), never the viewer's.
function viewer.load_joints(path)
    viewer.joints = nil
    local model = records.model_name(path)
    local record = records.read(viewer.project_dir, model)
    if record == nil then return end
    local results = lua_data.read_file(viewer.project_dir .. "/output/joints/" .. model .. ".results.lua")
    local answers = {}
    for _, answer in ipairs(results and results.joints or {}) do answers[answer.a .. "\0" .. answer.b] = answer end
    local marks, counts = {}, { empty = 0, waiting = 0, pass = 0, fail = 0, gone = 0 }
    for _, joint in ipairs(record.joints) do
        local state
        local answer = answers[joint.a .. "\0" .. joint.b]
        if not joint.found.still_found then state = "gone"
        elseif joint.equation == "" then state = "empty"
        -- an answer made from a record that has changed since is not shown
        elseif answer == nil or answer.signature ~= records.signature(record, joint) then state = "waiting"
        else state = answer.verdict end
        counts[state] = counts[state] + 1
        marks[#marks + 1] = { a = joint.a, b = joint.b, state = state, point = joint.found.contact_point }
    end
    viewer.joints = { marks = marks, counts = counts, model = model }
end
-- }}}

-- {{{ local function open_shape()
-- Reads a file and makes it the shape on screen.
local function open_shape(path)
    local shape, read_seconds = any_file.read(path)
    viewer.shape = shape
    viewer.read_seconds = read_seconds
    viewer.up_axis = shape.up_axis
    viewer.model_matrix = camera_math.upright(viewer.up_axis)
    viewer.meshes = build_meshes(shape)
    viewer.load_joints(path)
    viewer.problem = nil
    viewer.camera.fov = math.rad(viewer.settings.field_of_view_degrees)
    fit_view()
    -- a model with places to stand inside it opens standing at the first:
    -- from outside, a room is only the back of its walls (the light pipe
    -- opened as one flat colour, 2026-10-10)
    viewer.station = nil
    if shape.stations and #shape.stations > 0 then viewer.go_to_station(1) end
end
-- }}}

-- {{{ KEYS
-- Each key to what it does (a dispatch table); --key uses the same table.
local KEYS = {
    escape = function() love.event.quit() end,
    f = function() fit_view() end,
    w = function() viewer.view = (viewer.view == "edges") and "lit" or "edges" end,
    h = function() viewer.show_panel = not viewer.show_panel end,
    j = function() viewer.show_joints = not viewer.show_joints end,
    space = function() viewer.turning = not viewer.turning end,
    v = function()
        -- the next view in VIEW_ORDER, round to the first
        for index, name in ipairs(VIEW_ORDER) do
            if name == viewer.view then viewer.view = VIEW_ORDER[index % #VIEW_ORDER + 1] return end
        end
    end,
    n = function()
        -- the next station of a model that has them, round to the first
        local stations = viewer.shape and viewer.shape.stations
        if stations and #stations > 0 then viewer.go_to_station((viewer.station or 0) % #stations + 1) end
    end,
    o = function()
        -- back outside, circling the whole shape, with the settings' lens
        viewer.station = nil
        viewer.camera.fov = math.rad(viewer.settings.field_of_view_degrees)
        if viewer.shape then fit_view() end
    end,
    u = function()
        -- the other axis is up: some exporters ignore their format's rule
        viewer.up_axis = (viewer.up_axis == "y") and "z" or "y"
        viewer.model_matrix = camera_math.upright(viewer.up_axis)
        fit_view()
    end,
}
-- }}}

-- {{{ function viewer.go_to_station()
-- Stands the camera at station `index` of the shape (issue 008). The
-- station's points are in the file's own frame, so they are stood upright
-- with the shape.
function viewer.go_to_station(index)
    local station = viewer.shape.stations[index]
    local ex, ey, ez = camera_math.transform(viewer.model_matrix, station.eye)
    local lx, ly, lz = camera_math.transform(viewer.model_matrix, station.look)
    camera_math.stand_at(viewer.camera, { ex, ey, ez }, { lx, ly, lz })
    -- the station's own lens if it has one (a wide one for a room)
    viewer.camera.fov = math.rad(station.fov or viewer.settings.field_of_view_degrees)
    viewer.station = index
end
-- }}}

-- {{{ function viewer.drag()
-- The mouse handlers, shared by real mouse motion and scripted drags. The
-- model stands on an upright pillar, like an artifact on a plinth:
-- button 1 (left) turns it around the pillar, side to side only; button 2
-- (right) tilts the view up or down. Each drag does one thing, so turning
-- never tilts by accident and tilting never turns.
function viewer.drag(button, dx, dy)
    if viewer.shape == nil then return end
    if button == 1 then
        camera_math.orbit(viewer.camera, -dx * 0.01, 0)
    elseif button == 2 then
        camera_math.orbit(viewer.camera, 0, dy * 0.01)
    end
end
-- }}}

-- {{{ local function edge_push()
-- How hard the mouse pushes on one edge: 0 outside the margin, rising to 1
-- at the edge itself.
local function edge_push(position, size, margin)
    if position < margin then return -(margin - position) / margin end
    if position > size - margin then return (position - (size - margin)) / margin end
    return 0
end
-- }}}

-- {{{ function viewer.slide_at_edges()
-- The mouse resting near an edge slides the pillar across the floor:
-- left and right edges sideways, the top edge away, the bottom edge nearer,
-- faster the nearer the edge. Not while a button is held (that is a drag),
-- and not with the mouse outside the window (leaving the window must not
-- send the model drifting off).
function viewer.slide_at_edges(seconds)
    if viewer.shape == nil or viewer.mouse == nil then return end
    local width, height = love.graphics.getDimensions()
    local x, y = viewer.mouse.x, viewer.mouse.y
    if x < 0 or y < 0 or x > width or y > height then return end
    local margin = viewer.settings.edge_margin_pixels
    local across, nearer = edge_push(x, width, margin), edge_push(y, height, margin)
    if across == 0 and nearer == 0 then return end
    local step = viewer.camera.distance * viewer.settings.edge_speed * seconds
    -- the top edge (nearer < 0) moves the pillar away
    camera_math.slide_pillar(viewer.camera, across * step, -nearer * step)
    viewer.pillar_moved = 1.0
end
-- }}}

-- {{{ function viewer.load()
-- arguments: { project folder, [CAD file], run options... }
function viewer.load(arguments)
    viewer.project_dir = arguments[1]
    if viewer.project_dir == nil then
        error("the viewer needs the project folder as its first argument (use the view-cad script)", 0)
    end
    viewer.settings = settings_reader.read(viewer.project_dir)
    local s = viewer.settings

    viewer.scripted = {}
    viewer.screenshot_views = VIEW_ORDER
    local index = 2
    -- {{{ run option parsing
    -- Each option and how many values it takes, then what it records.
    local OPTIONS = {
        ["--key"] = { 2, function(v) return { at = tonumber(v[1]), kind = "key", key = v[2] } end },
        ["--drag"] = { 3, function(v) return { at = tonumber(v[1]), kind = "drag", button = 1, dx = tonumber(v[2]), dy = tonumber(v[3]) } end },
        ["--tilt"] = { 2, function(v) return { at = tonumber(v[1]), kind = "drag", button = 2, dx = 0, dy = tonumber(v[2]) } end },
        ["--mouse"] = { 3, function(v) return { at = tonumber(v[1]), kind = "mouse", x = tonumber(v[2]), y = tonumber(v[3]) } end },
        ["--wheel"] = { 2, function(v) return { at = tonumber(v[1]), kind = "wheel", notches = tonumber(v[2]) } end },
        ["--screenshot"] = { 1, function(v) return { at = tonumber(v[1]), kind = "screenshot" } end },
        -- --record SECONDS turn|walk LENGTH-SECONDS FRAMES-PER-SECOND (issue 011)
        ["--record"] = { 4, function(v) return { at = tonumber(v[1]), kind = "record", mode = v[2],
            length = tonumber(v[3]), fps = tonumber(v[4]) } end },
    }
    while index <= #arguments do
        local word = arguments[index]
        local option = OPTIONS[word]
        if word == "--stations" then
            -- not timed: a screenshot then takes its pictures at every station
            viewer.screenshot_at_stations = true
            index = index + 1
        elseif word == "--views" then
            -- not timed: it says which pictures a screenshot takes
            local names = {}
            for name in (arguments[index + 1] or ""):gmatch("[^,]+") do
                if viewer.VIEWS[name] == nil then
                    error("--views: no view called '" .. name .. "' (views: " .. table.concat(VIEW_ORDER, ", ") .. ")", 0)
                end
                names[#names + 1] = name
            end
            if #names == 0 then error("--views needs view names joined by commas", 0) end
            viewer.screenshot_views = names
            index = index + 2
        elseif option then
            local values = {}
            for k = 1, option[1] do values[k] = arguments[index + k] end
            local event = option[2](values)
            if event.at == nil then error(word .. " needs a number of seconds first", 0) end
            viewer.scripted[#viewer.scripted + 1] = event
            index = index + 1 + option[1]
        elseif word:sub(1, 2) == "--" then
            error("unknown run option " .. word, 0)
        else
            -- the one argument that is not an option is the file to show
            if viewer.file_path then error("only one CAD file at a time (got " .. viewer.file_path .. " and " .. word .. ")", 0) end
            viewer.file_path = word
            index = index + 1
        end
    end
    table.sort(viewer.scripted, function(a, b) return a.at < b.at end)
    -- a run with a script listens to the script only. The window takes
    -- keyboard focus when it opens, so whatever the person at the machine
    -- is typing elsewhere would otherwise land here (found 2026-10-10: two
    -- identical scripted runs gave pictures 10 degrees apart, the owner's
    -- game keys having pressed "space"). Ignored events are counted on the
    -- receipt.
    viewer.scripted_run = #viewer.scripted > 0
    viewer.ignored_input = 0
    -- }}}

    -- a window that cannot be resized is left at its size by a tiling window
    -- manager (dwm floats it), so it and every picture it takes stay one size
    love.window.setMode(s.window_width, s.window_height, { depth = 24, resizable = s.window_resizable, vsync = 1 })
    love.window.setTitle("CAD viewer")
    viewer.font = love.graphics.newFont(14)
    viewer.small_font = love.graphics.newFont(12)
    viewer.shader = love.graphics.newShader(SHADER)
    viewer.camera = camera_math.new(s.field_of_view_degrees)
    viewer.view, viewer.show_panel, viewer.turning = "lit", true, false
    viewer.frames_drawn, viewer.seconds_run = 0, 0
    viewer.read_seconds = 0
    viewer.pictures = {}
    make_canvases()

    -- no file named: the window opens empty and waits for a dropped file
    if viewer.file_path then open_shape(viewer.file_path) end
end
-- }}}

-- {{{ function viewer.update()
function viewer.update(seconds)
    viewer.seconds_run = viewer.seconds_run + seconds
    if viewer.quit_next_frame then love.event.quit() return end
    -- where the mouse rests: the real mouse, or in a scripted run the
    -- script's (--mouse), never both
    if not viewer.scripted_run then
        if love.window.hasMouseFocus() and not love.mouse.isDown(1) and not love.mouse.isDown(2) then
            local x, y = love.mouse.getPosition()
            viewer.mouse = { x = x, y = y }
        else
            viewer.mouse = nil
        end
    end
    viewer.slide_at_edges(seconds)
    viewer.pillar_moved = math.max(0, (viewer.pillar_moved or 0) - seconds)
    if viewer.turning and viewer.shape then
        camera_math.orbit(viewer.camera, math.rad(viewer.settings.turn_degrees_per_second) * seconds, 0)
    end
    -- scripted events whose time has come, through the same handlers
    while viewer.scripted[1] and viewer.scripted[1].at <= viewer.seconds_run do
        local event = table.remove(viewer.scripted, 1)
        if event.kind == "key" then
            local handler = KEYS[event.key]
            if handler == nil then error("--key " .. event.key .. ": no such key in the viewer", 0) end
            handler()
        elseif event.kind == "drag" then
            viewer.drag(event.button, event.dx, event.dy)
        elseif event.kind == "wheel" then
            viewer.wheelmoved(0, event.notches)
        elseif event.kind == "mouse" then
            viewer.mouse = { x = event.x, y = event.y }
        elseif event.kind == "screenshot" then
            -- taken in draw(), where drawing is allowed
            viewer.screenshot_due = true
        elseif event.kind == "record" then
            viewer.start_recording(event)
        end
    end
end
-- }}}

-- {{{ local function send_camera()
-- The camera's matrices and light direction to the shader. The projection
-- is turned upside down because a canvas stores its rows the other way up
-- from the screen (checked with a one-triangle LÖVE program, 2026-10-10:
-- unflipped, a triangle meant for the top landed at the bottom).
local function send_camera(width, height)
    local projection = camera_math.projection(viewer.camera, width / height)
    for column = 1, 4 do projection[2][column] = -projection[2][column] end
    local eye = camera_math.eye(viewer.camera)
    local t = viewer.camera.target
    local tx, ty, tz = eye[1] - t[1], eye[2] - t[2], eye[3] - t[3]
    local length = math.sqrt(tx * tx + ty * ty + tz * tz)
    viewer.shader:send("view_matrix", "row", camera_math.view(viewer.camera))
    viewer.shader:send("projection_matrix", "row", projection)
    viewer.shader:send("model_matrix", "row", viewer.model_matrix)
    viewer.shader:send("toward_camera", { tx / length, ty / length, tz / length })
    viewer.shader:send("depth_range", { viewer.camera.distance - viewer.camera.radius, viewer.camera.distance + viewer.camera.radius })
    local f = viewer.shape.filling
    viewer.shader:send("filling", f and { f.colour[1], f.colour[2], f.colour[3], f.density } or { 0, 0, 0, 0 })
end
-- }}}

-- {{{ local function draw_meshes()
-- Every part, in one shade mode; colour_of(item) picks each part's colour.
local function draw_meshes(shade_mode, colour_of, depth_bias)
    viewer.shader:send("shade_mode", shade_mode)
    viewer.shader:send("depth_bias", depth_bias or 0)
    for _, item in ipairs(viewer.meshes) do
        viewer.shader:send("part_colour", colour_of(item))
        -- glowing parts (the light itself) only in the lit looks; every
        -- other view draws them like any part
        viewer.shader:send("glow", (shade_mode == 0 and item.part.glow) and 1 or 0)
        love.graphics.draw(item.mesh)
    end
end
-- }}}

-- {{{ local function own_colour()
local function own_colour(item) return item.part.colour end
-- }}}

-- {{{ local function draw_annotations()
-- Over a lit picture: the overall box drawn in thin lines with its three
-- lengths, and each part's name at the end of a line from its middle,
-- pushed outward from the picture's centre so labels gather at the edges.
local function draw_annotations(width, height)
    local s = viewer.settings
    local b = viewer.shape.bounds
    -- the box's corners in the world (after standing upright)
    local corners = {}
    for i = 0, 1 do for j = 0, 1 do for k = 0, 1 do
        local x, y, z = camera_math.transform(viewer.model_matrix,
            { i == 0 and b.min[1] or b.max[1], j == 0 and b.min[2] or b.max[2], k == 0 and b.min[3] or b.max[3] })
        corners[i * 4 + j * 2 + k + 1] = { x, y, z }
    end end end
    local screen = {}
    for index, corner in ipairs(corners) do
        local sx, sy, ahead = camera_math.to_screen(viewer.camera, corner, width, height)
        screen[index] = { sx, sy, ahead }
    end
    love.graphics.setColor(s.edge_colour[1], s.edge_colour[2], s.edge_colour[3], 0.55)
    love.graphics.setLineWidth(1)
    -- corners differing in exactly one of the three bits share an edge
    for a = 0, 7 do
        for _, one_bit in ipairs({ 1, 2, 4 }) do
            local other = bit.bxor(a, one_bit)
            -- each edge once (from its lower-numbered corner), and only when
            -- both ends are in front of the camera
            if other > a and screen[a + 1][3] and screen[other + 1][3] then
                love.graphics.line(screen[a + 1][1], screen[a + 1][2], screen[other + 1][1], screen[other + 1][2])
            end
        end
    end
    -- three edges from the lowest corner, each labelled with its length
    local size = record.size(viewer.shape)
    local world_size = { camera_math.transform(viewer.model_matrix, size) }
    local units = viewer.shape.units and (" " .. viewer.shape.units) or ""
    local names = { "width", "height", "depth" }
    love.graphics.setFont(viewer.small_font)
    for axis, step in ipairs({ 4, 2, 1 }) do
        local a, c = screen[1], screen[1 + step]
        if a[3] and c[3] then
            love.graphics.setColor(s.edge_colour)
            love.graphics.print(string.format("%s %.4g%s", names[axis], math.abs(world_size[axis]), units),
                (a[1] + c[1]) / 2 + 4, (a[2] + c[2]) / 2 + 2)
        end
    end
    -- each part's label; a label landing on one already placed moves down a
    -- line until it is clear (parts sharing a middle, like a ring and the
    -- dials around it, would otherwise print over each other)
    local placed = {}
    local function clear_spot(x, y, w)
        for _ = 1, 40 do
            local overlaps = false
            for _, r in ipairs(placed) do
                if x < r[1] + r[3] and r[1] < x + w and math.abs(y - r[2]) < 15 then overlaps = true break end
            end
            if not overlaps then return y end
            y = y + 15
        end
        return y
    end
    for _, item in ipairs(viewer.meshes) do
        local x, y, z = camera_math.transform(viewer.model_matrix, item.middle)
        local sx, sy, ahead = camera_math.to_screen(viewer.camera, { x, y, z }, width, height)
        if ahead then
            local dx, dy = sx - width / 2, sy - height / 2
            local length = math.max(math.sqrt(dx * dx + dy * dy), 1)
            local lx, ly = sx + dx / length * 70, sy + dy / length * 70
            local label = item.part.name
            local label_width = viewer.small_font:getWidth(label)
            local label_x = dx < 0 and (lx - label_width - 3) or (lx + 3)
            local label_y = clear_spot(label_x, ly - 7, label_width)
            placed[#placed + 1] = { label_x, label_y, label_width }
            love.graphics.setColor(s.text_colour)
            love.graphics.circle("fill", sx, sy, 2.5)
            love.graphics.line(sx, sy, lx, label_y + 7)
            love.graphics.print(label, label_x, label_y)
        end
    end
    love.graphics.setColor(1, 1, 1)
end
-- }}}

-- {{{ function viewer.draw_joints()
-- A mark at each joint, coloured by its state, labelled with its two parts;
-- labels that would land on one another move down a line.
function viewer.draw_joints(width, height)
    if not viewer.joints then return end
    love.graphics.setFont(viewer.small_font)
    local placed = {}
    for _, mark in ipairs(viewer.joints.marks) do
        local x, y, z = camera_math.transform(viewer.model_matrix, mark.point)
        local sx, sy, ahead = camera_math.to_screen(viewer.camera, { x, y, z }, width, height)
        if ahead then
            local colour = JOINT_COLOURS[mark.state]
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.circle("fill", sx, sy, 7)
            love.graphics.setColor(colour)
            love.graphics.circle("fill", sx, sy, 5)
            local label = mark.a .. " / " .. mark.b .. "  (" .. mark.state .. ")"
            local lx, ly = sx + 10, sy - 7
            for _ = 1, 30 do
                local clear = true
                for _, p in ipairs(placed) do
                    if math.abs(p[2] - ly) < 14 and lx < p[1] + p[3] and p[1] < lx + viewer.small_font:getWidth(label) then clear = false end
                end
                if clear then break end
                ly = ly + 14
            end
            placed[#placed + 1] = { lx, ly, viewer.small_font:getWidth(label) }
            -- a dark backing, so the label reads over the model as well as
            -- over the background
            love.graphics.setColor(0.05, 0.05, 0.06, 0.75)
            love.graphics.rectangle("fill", lx - 3, ly - 1, viewer.small_font:getWidth(label) + 6, 15, 3)
            love.graphics.setColor(colour)
            love.graphics.print(label, lx, ly)
        end
    end
    love.graphics.setColor(1, 1, 1)
end
-- }}}

-- {{{ VIEWS
-- Each view draws the shape into the current canvas (a dispatch table).
viewer.VIEWS = {
    lit = function() draw_meshes(0, own_colour) end,
    edges = function()
        draw_meshes(0, own_colour)
        love.graphics.setWireframe(true)
        draw_meshes(1, function() return viewer.settings.edge_colour end, 0.0004)
        love.graphics.setWireframe(false)
    end,
    parts = function() draw_meshes(1, function(item) return item.flat end) end,
    depth = function() draw_meshes(2, own_colour) end,
    normals = function() draw_meshes(3, own_colour) end,
    annotated = function() draw_meshes(0, own_colour) end,
    joints = function() draw_meshes(0, own_colour) end,
}
-- }}}

-- {{{ local function render_view()
-- Draws one view of the shape into the canvas, with a title line naming
-- the file and the view (so a saved picture says what it is by itself).
local function render_view(view_name)
    local width, height = viewer.canvas:getDimensions()
    love.graphics.setCanvas({ viewer.canvas, depthstencil = viewer.depth_canvas })
    local bg = viewer.settings.background_colour
    love.graphics.clear(bg[1], bg[2], bg[3], 1, false, 1)
    if viewer.shape then
        love.graphics.setShader(viewer.shader)
        love.graphics.setDepthMode("lequal", true)
        send_camera(width, height)
        viewer.VIEWS[view_name]()
        love.graphics.setDepthMode()
        love.graphics.setShader()
        if view_name == "annotated" then draw_annotations(width, height) end
        if view_name == "joints" or (viewer.show_joints and view_name ~= "parts") then viewer.draw_joints(width, height) end
        love.graphics.setFont(viewer.small_font)
        love.graphics.setColor(viewer.settings.text_colour)
        love.graphics.print(viewer.shape.name .. "  —  " .. view_name .. " view", 12, height - 22)
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.setCanvas()
end
-- }}}

-- {{{ local function save_pictures()
-- One picture per requested view, read from the canvas, saved to
-- tmp/shared-memory/screenshot-<file>-<view>.png. The share of pure black
-- pixels goes on the receipt: the viewer never draws pure black (even the
-- depth view's farthest grey is above it), so black pixels mean the
-- picture was not drawn.
-- {{{ local function count_parts()
-- How many pixels of a parts-view picture belong to each part: every part is
-- drawn in one flat colour, so a pixel of exactly that colour is that part
-- (pixels at edges, blended by multisampling, belong to none and are not
-- counted). Returns { part name = pixel count }.
local function count_parts(image)
    local width, height = image:getDimensions()
    -- each part's colour, and every colour within 2 steps of it on each
    -- channel: the graphics card rounds its own way (the hinges' 0.627 was
    -- stored as 159 where 0.627 x 255 rounds to 160, found 2026-10-10 when
    -- coverage called plainly visible hinges unseen). The flat colours are
    -- at least ~30 steps apart, so the neighbourhoods never overlap.
    local by_colour = {}
    for _, item in ipairs(viewer.meshes) do
        local c = item.flat
        local r, g, b = math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)
        for dr = -2, 2 do for dg = -2, 2 do for db = -2, 2 do
            by_colour[(r + dr) * 65536 + (g + dg) * 256 + (b + db)] = item.part.name
        end end end
    end
    local counts = {}
    local bytes = ffi.cast("const uint8_t *", image:getFFIPointer())
    for k = 0, width * height - 1 do
        local part = by_colour[bytes[k * 4] * 65536 + bytes[k * 4 + 1] * 256 + bytes[k * 4 + 2]]
        if part then counts[part] = (counts[part] or 0) + 1 end
    end
    return counts, width * height
end
-- }}}

-- {{{ local function measure_coverage()
-- At the current camera: each part's share of the picture, from the parts
-- view. Folded into viewer.coverage (part name -> { stations = whole,
-- best_share = number, best_station = string }).
local function measure_coverage(station_name)
    render_view("parts")
    local counts, total = count_parts(viewer.canvas:newImageData())
    viewer.coverage_rows[#viewer.coverage_rows + 1] = { station = station_name, counts = counts, total = total }
    for _, item in ipairs(viewer.meshes) do
        local entry = viewer.coverage[item.part.name]
        local share = (counts[item.part.name] or 0) / total
        -- seen: at least a few hundred pixels' worth, so a part is not
        -- "featured" by a speck
        if share >= 0.0005 then entry.stations = entry.stations + 1 end
        if share > entry.best_share then entry.best_share, entry.best_station = share, station_name end
    end
end
-- }}}

local function save_pictures()
    local name = (viewer.shape and viewer.shape.name or "empty"):gsub("[^%w%.%-]", "_")
    -- the places to take pictures from: every station, or just here
    local places = { { label = nil } }
    if viewer.screenshot_at_stations then
        local stations = viewer.shape and viewer.shape.stations
        if not stations or #stations == 0 then error("--stations: this model has no stations", 0) end
        places = {}
        for index, station in ipairs(stations) do places[index] = { label = station.name, index = index } end
        viewer.coverage, viewer.coverage_rows = {}, {}
        for _, item in ipairs(viewer.meshes) do
            viewer.coverage[item.part.name] = { stations = 0, best_share = 0, best_station = "none" }
        end
    end
    for _, place in ipairs(places) do
        if place.index then
            viewer.go_to_station(place.index)
            measure_coverage(place.label)
        end
        for _, view_name in ipairs(viewer.screenshot_views) do
            render_view(view_name)
            local image = viewer.canvas:newImageData()
            local width, height = image:getDimensions()
            local bytes = ffi.cast("const uint8_t *", image:getFFIPointer())
            local black = 0
            for k = 0, width * height - 1 do
                if bytes[k * 4] == 0 and bytes[k * 4 + 1] == 0 and bytes[k * 4 + 2] == 0 then black = black + 1 end
            end
            local label = place.label and (place.label:gsub("[^%w%-]", "-") .. "-") or ""
            local path = viewer.project_dir .. "/tmp/shared-memory/screenshot-" .. name .. "-" .. label .. view_name .. ".png"
            local file, problem = io.open(path, "wb")
            if file == nil then error("cannot save screenshot " .. path .. ": " .. tostring(problem), 0) end
            file:write(image:encode("png"):getString())
            file:close()
            print("screenshot saved: " .. path)
            local c = viewer.camera
            viewer.pictures[#viewer.pictures + 1] = { path = path, view = view_name, black_share = black / (width * height),
                station = place.label,
                camera = string.format("%dx%d yaw %.4f pitch %.4f distance %.6g target %.6g %.6g %.6g",
                    width, height, c.yaw, c.pitch, c.distance, c.target[1], c.target[2], c.target[3]) }
        end
    end
    if viewer.coverage then viewer.write_coverage(name) end
    viewer.quit_next_frame = true
end
-- }}}

-- {{{ function viewer.write_coverage()
-- The coverage table: one row per station, one column per part, each the
-- part's share of that station's picture in thousandths; then each part's
-- count of stations that show it. Written to tmp/shared-memory/.
function viewer.write_coverage(name)
    local out = { "coverage of " .. viewer.shape.name .. ", written by src/010-the-viewer.lua (--stations): "
        .. "each part's share of each station's picture, in thousandths; '.' = not seen", "" }
    local header = { string.format("%-28s", "station") }
    -- each column 11 wide: a space, then the part's name cut to 10 letters
    for _, item in ipairs(viewer.meshes) do header[#header + 1] = string.format(" %10s", item.part.name:sub(1, 10)) end
    out[#out + 1] = table.concat(header)
    for _, row in ipairs(viewer.coverage_rows) do
        local line = { string.format("%-28s", row.station) }
        for _, item in ipairs(viewer.meshes) do
            local share = (row.counts[item.part.name] or 0) / row.total
            line[#line + 1] = share >= 0.0005 and string.format(" %10.0f", share * 1000) or string.format(" %10s", ".")
        end
        out[#out + 1] = table.concat(line)
    end
    local path = viewer.project_dir .. "/tmp/shared-memory/coverage-" .. name .. ".txt"
    local file, problem = io.open(path, "w")
    if file == nil then error("cannot write " .. path .. ": " .. tostring(problem), 0) end
    file:write(table.concat(out, "\n") .. "\n")
    file:close()
    print("coverage written: " .. path)
end
-- }}}

-- {{{ recording (issue 011)
-- A recording is a fixed number of frames, each with the camera set by the
-- frame's number, not by the clock: the same recording always has the same
-- frames, however fast the machine draws. Frames are drawn in the lit look,
-- shrunk to half size, and written as raw pixels (4 bytes each, red, green,
-- blue, alpha, row by row from the top) to tmp/shared-memory/frames/NAME/,
-- with info.lua describing them; scripts/make-gif turns them into a GIF.
--   turn  a full turn of the model on its pillar, from where the camera is
--   walk  through the model's stations in order: at each, a moment's hold,
--         then an eased glide (eye, look point and lens) to the next

-- {{{ function viewer.start_recording()
function viewer.start_recording(event)
    if event.mode ~= "turn" and event.mode ~= "walk" then error("--record: the mode is turn or walk, not " .. tostring(event.mode), 0) end
    if not (event.length and event.length > 0 and event.fps and event.fps > 0) then error("--record needs a length and frames per second", 0) end
    if event.mode == "walk" and not (viewer.shape.stations and #viewer.shape.stations >= 2) then
        error("--record walk: this model has fewer than two stations", 0)
    end
    local name = (viewer.shape.name:gsub("%.[^.]*$", "") .. "-" .. event.mode):gsub("[^%w%-]", "-")
    local folder = viewer.project_dir .. "/tmp/shared-memory/frames/" .. name
    -- a recording's folder is remade each time: frames of an older, longer
    -- recording must not trail behind a newer one
    os.execute("rm -rf '" .. folder .. "' && mkdir -p '" .. folder .. "'")
    local width, height = viewer.canvas:getDimensions()
    viewer.recording = { mode = event.mode, frame = 0, total = math.floor(event.length * event.fps + 0.5), fps = event.fps,
        folder = folder, name = name, yaw = viewer.camera.yaw,
        small = love.graphics.newCanvas(math.floor(width / 2), math.floor(height / 2)) }
end
-- }}}

-- {{{ local function ease()
local function ease(t) return t * t * (3 - 2 * t) end
-- }}}

-- {{{ local function place_walk_camera()
-- The camera for frame i of a walk through n stations.
local function place_walk_camera(r, i)
    local stations = viewer.shape.stations
    local legs = #stations - 1
    local progress = i / r.total * legs
    local leg = math.min(legs - 1, math.floor(progress))
    local t = progress - leg
    -- the first 30% of each leg holds at its station, the rest glides
    t = (t < 0.3) and 0 or ease((t - 0.3) / 0.7)
    local a, b = stations[leg + 1], stations[leg + 2]
    local function mix(u, v) return { u[1] + (v[1] - u[1]) * t, u[2] + (v[2] - u[2]) * t, u[3] + (v[3] - u[3]) * t } end
    local eye, look = mix(a.eye, b.eye), mix(a.look, b.look)
    local ex, ey, ez = camera_math.transform(viewer.model_matrix, eye)
    local lx, ly, lz = camera_math.transform(viewer.model_matrix, look)
    camera_math.stand_at(viewer.camera, { ex, ey, ez }, { lx, ly, lz })
    local fa = a.fov or viewer.settings.field_of_view_degrees
    local fb = b.fov or viewer.settings.field_of_view_degrees
    viewer.camera.fov = math.rad(fa + (fb - fa) * t)
end
-- }}}

-- {{{ function viewer.record_frame()
-- Draws, shrinks and writes one frame; after the last, writes info.lua and
-- closes the viewer.
function viewer.record_frame()
    local r = viewer.recording
    if r.mode == "turn" then
        viewer.camera.yaw = r.yaw + 2 * math.pi * r.frame / r.total
    else
        place_walk_camera(r, r.frame)
    end
    render_view("lit")
    love.graphics.setCanvas(r.small)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.draw(viewer.canvas, 0, 0, 0, 0.5, 0.5)
    love.graphics.setCanvas()
    local image = r.small:newImageData()
    local path = string.format("%s/%04d.rgba", r.folder, r.frame)
    local file, problem = io.open(path, "wb")
    if file == nil then error("cannot write frame " .. path .. ": " .. tostring(problem), 0) end
    file:write(image:getString())
    file:close()
    r.frame = r.frame + 1
    if r.frame >= r.total then
        local width, height = r.small:getDimensions()
        local info = io.open(r.folder .. "/info.lua", "w")
        info:write(string.format("-- written by src/010-the-viewer.lua (--record): the frames of %s, for scripts/make-gif\n"
            .. "return { name = %q, mode = %q, frames = %d, fps = %g, width = %d, height = %d, model = %q }\n",
            r.name, r.name, r.mode, r.total, r.fps, width, height, viewer.file_path or "none"))
        info:close()
        print(string.format("recorded %d frames: %s", r.total, r.folder))
        viewer.recorded = { name = r.name, frames = r.total }
        viewer.recording = nil
        viewer.quit_next_frame = true
    end
end
-- }}}
-- }}}

-- {{{ local function draw_panel()
-- The figures in the corner, on the window only (not in saved pictures,
-- which carry their own title line).
local function draw_panel()
    local s = viewer.settings
    local shape = viewer.shape
    local lines = {}
    if shape then
        local size = record.size(shape)
        local units = shape.units and (" " .. shape.units) or ""
        lines[#lines + 1] = shape.name
        lines[#lines + 1] = string.format("format %s   up axis %s   %.1f KB   view %s", shape.source_format, viewer.up_axis, shape.bytes_on_disk / 1024, viewer.view)
        lines[#lines + 1] = string.format("triangles %d   degenerate %d", shape.triangle_count, shape.degenerate_count)
        lines[#lines + 1] = string.format("size %.4g x %.4g x %.4g%s", size[1], size[2], size[3], units)
        lines[#lines + 1] = string.format("read %.3f s   %d fps", viewer.read_seconds, love.timer.getFPS())
        -- what the reader passed over (OBJ texture coordinates, smoothing
        -- groups...): a model coloured by a picture shows "vt" here, which
        -- says why it is drawn plain
        if shape.skipped and next(shape.skipped) then
            local words = {}
            for word, count in pairs(shape.skipped) do words[#words + 1] = word .. " " .. count end
            table.sort(words)
            lines[#lines + 1] = "not read: " .. table.concat(words, ", ")
        end
        if shape.stations and #shape.stations > 0 then
            lines[#lines + 1] = viewer.station
                and string.format("station %d of %d: %s   (n: next, o: outside)", viewer.station, #shape.stations, shape.stations[viewer.station].name)
                or string.format("%d stations inside   (n: stand at the first)", #shape.stations)
        end
        if viewer.joints then
            local c = viewer.joints.counts
            lines[#lines + 1] = string.format("joints %d: %d empty, %d waiting, %d pass, %d fail   (j: %s)",
                #viewer.joints.marks, c.empty, c.waiting, c.pass, c.fail, viewer.show_joints and "hide" or "show")
        end
        lines[#lines + 1] = string.format("parts %d:", #shape.parts)
    else
        lines[#lines + 1] = "drop a CAD file onto this window (." .. table.concat(any_file.endings(), ", .") .. ")"
    end
    love.graphics.setFont(viewer.font)
    love.graphics.setColor(s.text_colour)
    local y = 12
    for _, text in ipairs(lines) do
        love.graphics.print(text, 12, y)
        y = y + 18
    end
    -- one line per part, with its colour; long lists stop at 24
    if shape then
        for index, part in ipairs(shape.parts) do
            if index > 24 then
                love.graphics.setColor(s.text_colour)
                love.graphics.print(string.format("... and %d more", #shape.parts - 24), 12, y)
                break
            end
            love.graphics.setColor(part.colour)
            love.graphics.rectangle("fill", 14, y + 3, 12, 12)
            love.graphics.setColor(s.text_colour)
            love.graphics.print(string.format("%s  (%d)", part.name, #part.positions / 9), 32, y)
            y = y + 18
        end
    end
    if viewer.problem then
        love.graphics.setColor(1, 0.4, 0.35)
        love.graphics.printf(viewer.problem, 12, love.graphics.getHeight() - 80, love.graphics.getWidth() - 24)
    end
    love.graphics.setColor(s.text_colour)
    love.graphics.print("left drag: turn   right drag: tilt   wheel: zoom   mouse at an edge: move the pillar   f: fit   v: view   w: edges   j: joints   space: spin   h: hide",
        12, love.graphics.getHeight() - 44)
    love.graphics.setColor(1, 1, 1)
end
-- }}}

-- {{{ function viewer.draw()
function viewer.draw()
    if viewer.screenshot_due then
        viewer.screenshot_due = false
        save_pictures()
    end
    if viewer.recording then viewer.record_frame() end
    render_view(viewer.view)
    love.graphics.draw(viewer.canvas)
    -- {{{ the pillar, shown faintly for a moment after it moves
    -- (on the window only: pictures show the model, not the controls)
    if viewer.shape and (viewer.pillar_moved or 0) > 0 then
        local width, height = love.graphics.getDimensions()
        local t, r = viewer.camera.target, viewer.camera.radius
        local x1, y1, ahead1 = camera_math.to_screen(viewer.camera, { t[1], t[2] - r, t[3] }, width, height)
        local x2, y2, ahead2 = camera_math.to_screen(viewer.camera, { t[1], t[2] + r, t[3] }, width, height)
        if ahead1 and ahead2 then
            love.graphics.setColor(viewer.settings.edge_colour[1], viewer.settings.edge_colour[2], viewer.settings.edge_colour[3], 0.6 * viewer.pillar_moved)
            love.graphics.setLineWidth(2)
            love.graphics.line(x1, y1, x2, y2)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1)
        end
    end
    -- }}}
    if viewer.show_panel then draw_panel() end
    viewer.frames_drawn = viewer.frames_drawn + 1
end
-- }}}

-- {{{ input callbacks
-- {{{ function viewer.mousemoved()
function viewer.mousemoved(x, y, dx, dy)
    if viewer.scripted_run then
        if love.mouse.isDown(1) or love.mouse.isDown(2) then viewer.ignored_input = viewer.ignored_input + 1 end
        return
    end
    if love.mouse.isDown(1) then viewer.drag(1, dx, dy)
    elseif love.mouse.isDown(2) then viewer.drag(2, dx, dy) end
end
-- }}}

-- {{{ function viewer.wheelmoved()
function viewer.wheelmoved(x, y)
    if viewer.shape then camera_math.zoom(viewer.camera, y) end
end

-- {{{ function viewer.real_wheelmoved()
-- The wheel as LÖVE reports it: ignored in a scripted run.
function viewer.real_wheelmoved(x, y)
    if viewer.scripted_run then viewer.ignored_input = viewer.ignored_input + 1 return end
    viewer.wheelmoved(x, y)
end
-- }}}
-- }}}

-- {{{ function viewer.keypressed()
function viewer.keypressed(key)
    if viewer.scripted_run then viewer.ignored_input = viewer.ignored_input + 1 return end
    local handler = KEYS[key]
    -- keys with no entry do nothing: the window has only the keys it lists
    if handler then handler() end
end
-- }}}

-- {{{ function viewer.resize()
-- A new window size needs canvases of the new size.
function viewer.resize()
    make_canvases()
    if viewer.shape then fit_view() end
end
-- }}}

-- {{{ function viewer.filedropped()
-- A dropped file replaces the shape. If it cannot be read, the reason is
-- printed on screen and to the terminal, and the old shape stays: the
-- person dropped it by hand and can see the message, so the window is not
-- closed on them.
function viewer.filedropped(file)
    local path = file:getFilename()
    local ok, problem = pcall(open_shape, path)
    if not ok then
        viewer.problem = "could not open " .. path .. ": " .. tostring(problem)
        io.stderr:write(viewer.problem .. "\n")
    else
        viewer.file_path = path
    end
end
-- }}}
-- }}}

-- {{{ function viewer.quit()
-- The last act: the goodbye receipt.
function viewer.quit()
    local shape = viewer.shape
    goodbye.write(viewer.project_dir, {
        file = viewer.file_path or "none",
        format = shape and shape.source_format or "none",
        triangles = shape and shape.triangle_count or 0,
        parts = shape and #shape.parts or 0,
        read_seconds = viewer.read_seconds,
        frames_drawn = viewer.frames_drawn,
        seconds_run = viewer.seconds_run,
        pictures = viewer.pictures,
        joints = viewer.joints and viewer.joints.counts or nil,
        ignored_input = viewer.ignored_input,
        coverage = viewer.coverage,
        part_order = viewer.meshes,
    })
end
-- }}}

return viewer
