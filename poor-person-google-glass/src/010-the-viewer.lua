-- 010-the-viewer.lua - the CAD viewer's window: a shape, lit, turned by hand.
--
-- In plain terms: the file is read into a shape record (001, through 006)
-- before this file sees it; here each part's triangles are copied once into
-- the graphics card's memory, and every frame the card is told where the
-- camera is (009) and draws them, shading each surface by how squarely it
-- faces the light. Nothing here knows any file format.
--
-- Order of a run: read input/ (007), open the window, read the CAD file,
-- frame after frame (update, draw), and on closing write output/goodbye
-- (008). Scripted run options feed the same handlers the mouse and keyboard
-- use, on a timeline, so a run can be checked without a person:
--   --key SECONDS NAME      press a key (the keys listed in KEYS below)
--   --drag SECONDS DX DY    drag with the left button (turn the shape)
--   --pan SECONDS DX DY     drag with the right button (slide the shape)
--   --wheel SECONDS NOTCHES turn the wheel (positive: closer)
--   --screenshot SECONDS    save the window to tmp/shared-memory/ and close
--
-- Lighting: a light at the camera (a "headlight": whatever faces you is
-- lit) plus a dim light from above, and a floor of ambient light so nothing
-- is pure black. Both sides of a surface are lit the same, because CAD
-- exports often have inside-out triangles, and a viewer that hides them
-- hides the model.

local ffi = require("ffi")
local settings_reader = require("007-read-the-input")
local goodbye = require("008-say-goodbye")
local camera_math = require("009-the-orbit-camera")
local any_file = require("006-read-any-cad-file")
local record = require("001-the-shape-record")

local viewer = {}

-- {{{ SHADER
local SHADER = [[
varying vec3 world_normal;
uniform mat4 view_projection;
uniform mat4 model_matrix;
uniform float depth_bias;

#ifdef VERTEX
attribute vec3 VertexNormal;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // the shape's own placement (standing it upright) turns its normals too;
    // it is a pure rotation, so its 3x3 part turns directions correctly
    world_normal = mat3(model_matrix) * VertexNormal;
    vec4 clip = view_projection * model_matrix * vec4(vertex_position.xyz, 1.0);
    // edges are drawn a hair nearer than the faces they sit on, so they
    // are not hidden by the face they outline
    clip.z -= depth_bias * clip.w;
    return clip;
}
#endif

#ifdef PIXEL
uniform vec3 part_colour;
uniform vec3 toward_camera;
uniform float flat_colour;
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    if (flat_colour > 0.5) return vec4(part_colour, 1.0);
    float length_of_normal = length(world_normal);
    // a sliver triangle has no direction: ambient light only
    if (length_of_normal < 1e-6) return vec4(part_colour * 0.3, 1.0);
    vec3 n = world_normal / length_of_normal;
    float headlight = abs(dot(n, toward_camera));
    float from_above = abs(n.y);
    float light = 0.22 + 0.63 * headlight + 0.15 * from_above;
    return vec4(part_colour * light, 1.0);
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
    for _, part in ipairs(shape.parts) do
        local corners = #part.positions / 3
        if corners > 0 then
            local data = love.data.newByteData(corners * 6 * 4)
            local floats = ffi.cast("float *", data:getFFIPointer())
            local p, n = part.positions, part.normals
            for k = 0, corners - 1 do
                floats[k * 6 + 0], floats[k * 6 + 1], floats[k * 6 + 2] = p[k * 3 + 1], p[k * 3 + 2], p[k * 3 + 3]
                floats[k * 6 + 3], floats[k * 6 + 4], floats[k * 6 + 5] = n[k * 3 + 1], n[k * 3 + 2], n[k * 3 + 3]
            end
            local mesh = love.graphics.newMesh(format, corners, "triangles", "static")
            mesh:setVertices(data)
            meshes[#meshes + 1] = { mesh = mesh, part = part, triangles = corners / 3 }
        end
    end
    return meshes
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

-- {{{ local function open_shape()
-- Reads a file and makes it the shape on screen.
local function open_shape(path)
    local shape, read_seconds = any_file.read(path)
    viewer.shape = shape
    viewer.read_seconds = read_seconds
    viewer.up_axis = shape.up_axis
    viewer.model_matrix = camera_math.upright(viewer.up_axis)
    viewer.meshes = build_meshes(shape)
    viewer.problem = nil
    fit_view()
end
-- }}}

-- {{{ KEYS
-- Each key to what it does (a dispatch table); --key uses the same table.
local KEYS = {
    escape = function() love.event.quit() end,
    f = function() fit_view() end,
    w = function() viewer.show_edges = not viewer.show_edges end,
    h = function() viewer.show_panel = not viewer.show_panel end,
    space = function() viewer.turning = not viewer.turning end,
    u = function()
        -- the other axis is up: some exporters ignore their format's rule
        viewer.up_axis = (viewer.up_axis == "y") and "z" or "y"
        viewer.model_matrix = camera_math.upright(viewer.up_axis)
        fit_view()
    end,
}
-- }}}

-- {{{ function viewer.drag()
-- The mouse handlers, shared by real mouse motion and scripted drags.
-- button 1 turns the camera around the shape; button 2 slides the shape.
function viewer.drag(button, dx, dy)
    if viewer.shape == nil then return end
    if button == 1 then
        camera_math.orbit(viewer.camera, -dx * 0.01, dy * 0.01)
    elseif button == 2 then
        camera_math.pan(viewer.camera, dx, dy, love.graphics.getHeight())
    end
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
    local index = 2
    -- {{{ run option parsing
    -- Each option and how many values it takes, then what it records.
    local OPTIONS = {
        ["--key"] = { 2, function(v) return { at = tonumber(v[1]), kind = "key", key = v[2] } end },
        ["--drag"] = { 3, function(v) return { at = tonumber(v[1]), kind = "drag", button = 1, dx = tonumber(v[2]), dy = tonumber(v[3]) } end },
        ["--pan"] = { 3, function(v) return { at = tonumber(v[1]), kind = "drag", button = 2, dx = tonumber(v[2]), dy = tonumber(v[3]) } end },
        ["--wheel"] = { 2, function(v) return { at = tonumber(v[1]), kind = "wheel", notches = tonumber(v[2]) } end },
        ["--screenshot"] = { 1, function(v) return { at = tonumber(v[1]), kind = "screenshot" } end },
    }
    while index <= #arguments do
        local word = arguments[index]
        local option = OPTIONS[word]
        if option then
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
    -- }}}

    -- no multisampling (msaa): on the owner's machine (dwm, which resizes
    -- every new window to fit its tile), a multisampled window draws fine
    -- but a screenshot of it reads back black below its first few rows,
    -- so scripted checks would see nothing. Found 2026-10-10 with a
    -- five-line LÖVE program: the same picture with msaa = 4 came back
    -- black, with msaa off came back whole. Edges are a little jagged.
    love.window.setMode(s.window_width, s.window_height, { depth = 24, resizable = true, vsync = 1 })
    love.window.setTitle("CAD viewer")
    love.graphics.setBackgroundColor(s.background_colour)
    viewer.font = love.graphics.newFont(14)
    viewer.shader = love.graphics.newShader(SHADER)
    viewer.camera = camera_math.new(s.field_of_view_degrees)
    viewer.show_edges, viewer.show_panel, viewer.turning = false, true, false
    viewer.frames_drawn, viewer.seconds_run = 0, 0
    viewer.read_seconds = 0

    -- no file named: the window opens empty and waits for a dropped file
    if viewer.file_path then open_shape(viewer.file_path) end
end
-- }}}

-- {{{ function viewer.update()
function viewer.update(seconds)
    viewer.seconds_run = viewer.seconds_run + seconds
    if viewer.quit_next_frame then love.event.quit() return end
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
        elseif event.kind == "screenshot" then
            viewer.take_screenshot()
        end
    end
end
-- }}}

-- {{{ function viewer.take_screenshot()
-- Saves the next finished frame, then closes the viewer.
function viewer.take_screenshot()
    local name = viewer.shape and viewer.shape.name or "empty"
    local path = viewer.project_dir .. "/tmp/shared-memory/screenshot-" .. name:gsub("[^%w%.%-]", "_") .. ".png"
    love.graphics.captureScreenshot(function(image)
        -- the share of pure black pixels goes on the receipt. The viewer
        -- never draws pure black (the background is not black, and even the
        -- darkest part keeps a floor of ambient light), so black pixels mean
        -- the capture itself failed -- as it did with multisampling on
        local width, height = image:getDimensions()
        local bytes = ffi.cast("const uint8_t *", image:getFFIPointer())
        local black = 0
        for k = 0, width * height - 1 do
            if bytes[k * 4] == 0 and bytes[k * 4 + 1] == 0 and bytes[k * 4 + 2] == 0 then black = black + 1 end
        end
        viewer.black_share = black / (width * height)
        local file, problem = io.open(path, "wb")
        if file == nil then error("cannot save screenshot " .. path .. ": " .. tostring(problem), 0) end
        file:write(image:encode("png"):getString())
        file:close()
        viewer.screenshot_path = path
        print("screenshot saved: " .. path)
        viewer.quit_next_frame = true
    end)
end
-- }}}

-- {{{ local function draw_shape()
local function draw_shape()
    local width, height = love.graphics.getDimensions()
    local view_projection = camera_math.multiply(camera_math.projection(viewer.camera, width / height),
                                                 camera_math.view(viewer.camera))
    local eye = camera_math.eye(viewer.camera)
    local t = viewer.camera.target
    local tx, ty, tz = eye[1] - t[1], eye[2] - t[2], eye[3] - t[3]
    local length = math.sqrt(tx * tx + ty * ty + tz * tz)

    love.graphics.setShader(viewer.shader)
    love.graphics.setDepthMode("lequal", true)
    viewer.shader:send("view_projection", "row", view_projection)
    viewer.shader:send("model_matrix", "row", viewer.model_matrix)
    viewer.shader:send("toward_camera", { tx / length, ty / length, tz / length })

    -- faces, lit
    viewer.shader:send("flat_colour", 0)
    viewer.shader:send("depth_bias", 0)
    for _, item in ipairs(viewer.meshes) do
        viewer.shader:send("part_colour", item.part.colour)
        love.graphics.draw(item.mesh)
    end
    -- edges, in one flat colour, over the faces
    if viewer.show_edges then
        love.graphics.setWireframe(true)
        viewer.shader:send("flat_colour", 1)
        viewer.shader:send("depth_bias", 0.0004)
        viewer.shader:send("part_colour", viewer.settings.edge_colour)
        for _, item in ipairs(viewer.meshes) do love.graphics.draw(item.mesh) end
        love.graphics.setWireframe(false)
    end
    love.graphics.setDepthMode()
    love.graphics.setShader()
end
-- }}}

-- {{{ local function draw_panel()
-- The figures in the corner: what the file is and what is in it.
local function draw_panel()
    local s = viewer.settings
    local shape = viewer.shape
    local lines = {}
    if shape then
        local size = record.size(shape)
        local units = shape.units and (" " .. shape.units) or ""
        lines[#lines + 1] = shape.name
        lines[#lines + 1] = string.format("format %s   up axis %s   %.1f KB", shape.source_format, viewer.up_axis, shape.bytes_on_disk / 1024)
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
        love.graphics.printf(viewer.problem, 12, love.graphics.getHeight() - 60, love.graphics.getWidth() - 24)
    end
    love.graphics.setColor(s.text_colour)
    love.graphics.print("left drag: turn   right drag: slide   wheel: zoom   f: fit   w: edges   u: up axis   space: spin   h: hide",
        12, love.graphics.getHeight() - 24)
    love.graphics.setColor(1, 1, 1)
end
-- }}}

-- {{{ function viewer.draw()
function viewer.draw()
    if viewer.shape then draw_shape() end
    if viewer.show_panel then draw_panel() end
    viewer.frames_drawn = viewer.frames_drawn + 1
end
-- }}}

-- {{{ input callbacks
-- {{{ function viewer.mousemoved()
function viewer.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(1) then viewer.drag(1, dx, dy)
    elseif love.mouse.isDown(2) then viewer.drag(2, dx, dy) end
end
-- }}}

-- {{{ function viewer.wheelmoved()
function viewer.wheelmoved(x, y)
    if viewer.shape then camera_math.zoom(viewer.camera, y) end
end
-- }}}

-- {{{ function viewer.keypressed()
function viewer.keypressed(key)
    local handler = KEYS[key]
    -- keys with no entry do nothing: the window has only the keys it lists
    if handler then handler() end
end
-- }}}

-- {{{ function viewer.resize()
function viewer.resize()
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
        screenshot = viewer.screenshot_path or false,
        black_share = viewer.black_share,
    })
end
-- }}}

return viewer
