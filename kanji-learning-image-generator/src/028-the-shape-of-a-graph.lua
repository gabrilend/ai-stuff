-- 028-the-shape-of-a-graph.lua
--
-- Builds a ComfyUI workflow, and writes it in the two shapes ComfyUI accepts.
--
-- For a general: the program that actually makes the pictures reads a graph --
-- boxes with sockets, wired together. It reads that graph in two different
-- file formats which are not interchangeable. One is what a script posts to it
-- when nobody is watching; the other is what its editor opens when somebody
-- drags a file onto the canvas. A learner wants the second. A batch of six
-- thousand wants the first. This describes the graph once and writes both.
--
-- `docs/005` has the formats. What this file adds is the thing neither format
-- contains: a catalogue of what each kind of box actually looks like.

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local json = project.load("018-write-the-numbers")

local M = {}

-- {{{ CATALOGUE -- what each kind of node looks like
--
-- WHY THIS HAS TO EXIST. The editor's format identifies a wire by which
-- *numbered* socket it lands in, so anything writing that format has to know
-- every node's sockets in order. Get the order wrong and the file loads without
-- complaint and is wired somewhere else.
--
-- AND THE TRAP, which `docs/005` spends a paragraph on. The editor's format
-- stores a node's control values as a bare array with no names in it, and that
-- array contains controls the posting format has no field for at all. The
-- sampler draws a selector immediately after its seed -- fixed, increment,
-- randomise -- which occupies a slot in the array and corresponds to nothing
-- when posting. Leave it out and every value after the seed is off by one: the
-- step count lands in the guidance scale. The file opens. The pictures are
-- wrong in a way that looks like bad settings.
--
-- Marked `interface_only` below, and written into the editor's format only.
--
-- This covers the dozen node types this project uses and does not aspire to
-- cover ComfyUI. A type that is needed and missing is an error naming it, which
-- is a five-line fix at the moment somebody needs it and is far better than a
-- catalogue full of guesses.
local CATALOGUE = {

  CheckpointLoaderSimple = {
    inputs = {},
    outputs = { { "MODEL", "MODEL" }, { "CLIP", "CLIP" }, { "VAE", "VAE" } },
    widgets = { { "ckpt_name", "" } },
  },

  CLIPTextEncode = {
    inputs = { { "clip", "CLIP" } },
    outputs = { { "CONDITIONING", "CONDITIONING" } },
    widgets = { { "text", "" } },
  },

  LoadImage = {
    inputs = {},
    outputs = { { "IMAGE", "IMAGE" }, { "MASK", "MASK" } },
    -- the second control is the upload button, which exists in the editor and
    -- has no meaning when posting
    widgets = { { "image", "" }, { "upload", "image", interface_only = true } },
  },

  ControlNetLoader = {
    inputs = {},
    outputs = { { "CONTROL_NET", "CONTROL_NET" } },
    widgets = { { "control_net_name", "" } },
  },

  ControlNetApplyAdvanced = {
    inputs = { { "positive", "CONDITIONING" }, { "negative", "CONDITIONING" },
               { "control_net", "CONTROL_NET" }, { "image", "IMAGE" } },
    outputs = { { "positive", "CONDITIONING" }, { "negative", "CONDITIONING" } },
    widgets = { { "strength", 1.0 }, { "start_percent", 0.0 },
                { "end_percent", 1.0 } },
  },

  EmptyLatentImage = {
    inputs = {},
    outputs = { { "LATENT", "LATENT" } },
    widgets = { { "width", 512 }, { "height", 512 }, { "batch_size", 1 } },
  },

  KSampler = {
    inputs = { { "model", "MODEL" }, { "positive", "CONDITIONING" },
               { "negative", "CONDITIONING" }, { "latent_image", "LATENT" } },
    outputs = { { "LATENT", "LATENT" } },
    widgets = { { "seed", 0 },
                -- THE ONE THAT MOVES EVERYTHING ELSE ALONG BY ONE
                { "control_after_generate", "fixed", interface_only = true },
                { "steps", 20 }, { "cfg", 8.0 }, { "sampler_name", "euler" },
                { "scheduler", "normal" }, { "denoise", 1.0 } },
  },

  VAEDecode = {
    inputs = { { "samples", "LATENT" }, { "vae", "VAE" } },
    outputs = { { "IMAGE", "IMAGE" } },
    widgets = {},
  },

  InvertMask = {
    inputs = { { "mask", "MASK" } },
    outputs = { { "MASK", "MASK" } },
    widgets = {},
  },

  ImageCompositeMasked = {
    inputs = { { "destination", "IMAGE" }, { "source", "IMAGE" },
               { "mask", "MASK" } },
    outputs = { { "IMAGE", "IMAGE" } },
    widgets = { { "x", 0 }, { "y", 0 }, { "resize_source", false } },
  },

  SaveImage = {
    inputs = { { "images", "IMAGE" } },
    outputs = {},
    widgets = { { "filename_prefix", "ComfyUI" } },
  },
}
-- }}}

-- {{{ M.known(kind)
function M.known(kind) return CATALOGUE[kind] ~= nil end
-- }}}

-- {{{ M.catalogue()
function M.catalogue() return CATALOGUE end
-- }}}

-- {{{ find_socket(list, name)
-- Which numbered socket a named one is, and what type it carries.
local function find_socket(list, name)
  for index, socket in ipairs(list) do
    if socket[1] == name then return index, socket[2] end
  end
  return nil, nil
end
-- }}}

local Graph = {}
Graph.__index = Graph

-- {{{ M.new()
-- An empty graph.
function M.new()
  return setmetatable({ nodes = {}, links = {}, next_id = 1, next_link = 1 }, Graph)
end
-- }}}

-- {{{ Graph:add(kind, values, label)
-- One node, with its controls set by name.
--
-- Setting a control the catalogue does not list is an error rather than a
-- silently ignored key, because the symptom otherwise is a workflow that runs
-- with a default nobody chose.
function Graph:add(kind, values, label)
  local described = CATALOGUE[kind]
  if not described then
    error("this project's node catalogue does not describe '" .. tostring(kind) ..
          "'.\n  Add it to src/028-the-shape-of-a-graph.lua -- sockets in order," ..
          "\n  controls in order, with any editor-only ones marked.")
  end
  for name in pairs(values or {}) do
    if not find_socket(described.widgets, name) then
      error("'" .. kind .. "' has no control called '" .. name .. "'")
    end
  end
  local node = {
    id = self.next_id, kind = kind, label = label,
    values = values or {}, described = described,
    incoming = {}, outgoing = {},
  }
  self.next_id = self.next_id + 1
  self.nodes[#self.nodes + 1] = node
  return node
end
-- }}}

-- {{{ Graph:link(from, output_name, to, input_name)
-- One wire, named at both ends.
--
-- Both ends are checked against the catalogue and the two types must agree. A
-- mistyped socket name would otherwise leave an input unconnected, and an
-- unconnected input is exactly what this catalogue exists to prevent.
function Graph:link(from, output_name, to, input_name)
  local out_index, out_type = find_socket(from.described.outputs, output_name)
  if not out_index then
    error("'" .. from.kind .. "' has no output called '" .. output_name .. "'")
  end
  local in_index, in_type = find_socket(to.described.inputs, input_name)
  if not in_index then
    error("'" .. to.kind .. "' has no input called '" .. input_name .. "'")
  end
  if out_type ~= in_type then
    error("cannot wire " .. from.kind .. "'s " .. output_name .. " (" ..
          out_type .. ") into " .. to.kind .. "'s " .. input_name ..
          " (" .. in_type .. ")")
  end
  local link = {
    id = self.next_link, from = from, out_index = out_index,
    to = to, in_index = in_index, kind = out_type,
    output_name = output_name, input_name = input_name,
  }
  self.next_link = self.next_link + 1
  self.links[#self.links + 1] = link
  to.incoming[input_name] = link
  from.outgoing[#from.outgoing + 1] = link
  return link
end
-- }}}

-- {{{ Graph:connections()
-- Every wire, as text, for comparing one description of a graph against another.
--
-- What the test in `301` uses: both emitted formats are walked and their
-- connection sets compared. That is what catches socket numbers drifting away
-- from socket names, and it needs no ComfyUI to run.
function Graph:connections()
  local out = {}
  for _, link in ipairs(self.links) do
    out[#out + 1] = string.format("%d.%s -> %d.%s", link.from.id,
                     link.output_name, link.to.id, link.input_name)
  end
  table.sort(out)
  return out
end
-- }}}

-- {{{ Graph:lay_out()
-- Where each node sits on the canvas.
--
-- Computed by walking the graph, not authored. Every node goes one column right
-- of everything it depends on, and down the column in the order it was made. A
-- workflow that opens as a legible left-to-right pipeline is worth twenty
-- lines, and hand-placed coordinates would be wrong the first time a node was
-- added.
function Graph:lay_out()
  local depth = {}
  local function settle(node, guard)
    if depth[node.id] then return depth[node.id] end
    if guard > 64 then
      error("the graph has a loop in it, at " .. node.kind)
    end
    local deepest = 0
    for _, link in pairs(node.incoming) do
      local behind = settle(link.from, guard + 1) + 1
      if behind > deepest then deepest = behind end
    end
    depth[node.id] = deepest
    return deepest
  end
  for _, node in ipairs(self.nodes) do settle(node, 0) end

  local filled = {}
  for _, node in ipairs(self.nodes) do
    local column = depth[node.id]
    filled[column] = (filled[column] or 0) + 1
    node.pos = { 40 + column * 330, 40 + (filled[column] - 1) * 210 }
    node.depth = column
  end
end
-- }}}

-- {{{ Graph:api()
-- The graph in the shape the endpoint accepts.
--
-- A flat object keyed by node number. Every value is either a literal or a pair
-- naming the node and numbered output it comes from.
function Graph:api()
  local out = json.object()
  for _, node in ipairs(self.nodes) do
    local inputs = json.object()
    -- controls first, in catalogue order, so two runs write the same bytes and
    -- a person opening one finds the settings where they were last time
    for _, widget in ipairs(node.described.widgets) do
      if not widget.interface_only then
        local value = node.values[widget[1]]
        if value == nil then value = widget[2] end
        inputs[widget[1]] = value
      end
    end
    for _, socket in ipairs(node.described.inputs) do
      local link = node.incoming[socket[1]]
      if link then
        inputs[socket[1]] = { tostring(link.from.id), link.out_index - 1 }
      end
    end
    local body = json.object("class_type", node.kind, "inputs", inputs)
    if node.label then
      body._meta = json.object("title", node.label)
    end
    out[tostring(node.id)] = body
  end
  return out
end
-- }}}

-- {{{ Graph:ui()
-- The graph in the shape the editor opens.
function Graph:ui()
  self:lay_out()

  local nodes = {}
  for _, node in ipairs(self.nodes) do
    local inputs = {}
    for _, socket in ipairs(node.described.inputs) do
      local link = node.incoming[socket[1]]
      inputs[#inputs + 1] = json.object(
        "name", socket[1], "type", socket[2],
        "link", link and link.id or nil)
      -- an unconnected socket must still appear, holding nothing, or the
      -- numbering of the ones after it shifts
      if not link then inputs[#inputs].link = nil end
    end

    local outputs = {}
    for index, socket in ipairs(node.described.outputs) do
      local going = {}
      for _, link in ipairs(node.outgoing) do
        if link.out_index == index then going[#going + 1] = link.id end
      end
      outputs[#outputs + 1] = json.object(
        "name", socket[1], "type", socket[2],
        "links", going, "slot_index", index - 1)
    end

    -- The control array, in catalogue order, WITH the editor-only entries. This
    -- is the line that keeps the step count out of the guidance scale.
    local values = {}
    for _, widget in ipairs(node.described.widgets) do
      local value = node.values[widget[1]]
      if value == nil then value = widget[2] end
      values[#values + 1] = value
    end

    local body = json.object(
      "id", node.id,
      "type", node.kind,
      "pos", { node.pos[1], node.pos[2] },
      "size", { 300, 100 + #node.described.widgets * 26 },
      "flags", json.object(),
      "order", node.id - 1,
      "mode", 0)
    if #inputs > 0 then body.inputs = inputs end
    if #outputs > 0 then body.outputs = outputs end
    body.properties = json.object("Node name for S&R", node.kind)
    body.widgets_values = values
    if node.label then body.title = node.label end
    nodes[#nodes + 1] = body
  end

  local links = {}
  for _, link in ipairs(self.links) do
    links[#links + 1] = { link.id, link.from.id, link.out_index - 1,
                          link.to.id, link.in_index - 1, link.kind }
  end

  return json.object(
    "last_node_id", self.next_id - 1,
    "last_link_id", self.next_link - 1,
    "nodes", nodes,
    "links", links,
    "groups", {},
    "config", json.object(),
    "extra", json.object(),
    "version", 0.4)
end
-- }}}

-- {{{ M.connections_from_api(text_object)
-- The wires an emitted posting-format graph describes.
--
-- Read back out of what was written rather than off the graph it came from,
-- which is what makes comparing the two formats a real check.
function M.connections_from_api(api, graph)
  local out = {}
  for _, id in ipairs(json.keys(api)) do
    local node = api[id]
    local inputs = node.inputs
    for _, name in ipairs(json.keys(inputs)) do
      local value = inputs[name]
      if type(value) == "table" and #value == 2 and type(value[1]) == "string" then
        -- the numbered output has to be turned back into its name, which is the
        -- catalogue being consulted from the other direction
        local source = api[value[1]]
        local described = CATALOGUE[source.class_type]
        local socket = described.outputs[value[2] + 1]
        out[#out + 1] = string.format("%s.%s -> %s.%s", value[1], socket[1],
                                      id, name)
      end
    end
  end
  table.sort(out)
  return out
end
-- }}}

-- {{{ M.connections_from_ui(ui)
-- The same, read back out of the editor-format graph.
function M.connections_from_ui(ui)
  local kinds, sockets = {}, {}
  for _, node in ipairs(ui.nodes) do
    kinds[node.id] = node.type
    sockets[node.id] = CATALOGUE[node.type]
  end
  local out = {}
  for _, link in ipairs(ui.links) do
    local id, from, out_index, to, in_index = link[1], link[2], link[3],
                                              link[4], link[5]
    local output = sockets[from].outputs[out_index + 1]
    local input = sockets[to].inputs[in_index + 1]
    out[#out + 1] = string.format("%d.%s -> %d.%s", from, output[1], to, input[1])
  end
  table.sort(out)
  return out
end
-- }}}

return M
