-- 029-the-workflow-for-one-kanji.lua
--
-- The actual pipeline: which boxes, wired how.
--
-- For a general: `028` knows how to describe a graph. This says what graph. It
-- is the recipe -- load a model, turn the sentence into something the model
-- understands, load the grey picture that hides the character, bias every step
-- of the drawing towards it, draw, and lay the stroke-order arrows on top.
--
-- `docs/005` has the diagram and the reasoning. This is that, built.

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local graph = project.load("028-the-shape-of-a-graph")

local M = {}

-- {{{ M.seed_for(record, style)
-- The starting noise for a character, taken from the character itself.
--
-- Not from a clock. A given character regenerates identically, and two runs
-- over the whole set differ only where the code changed -- without which,
-- comparing six thousand pictures against six thousand pictures is impossible
-- and every change looks like it changed everything.
--
-- Multiplied by a large odd number so that neighbouring characters, whose
-- numbers differ by one, do not get neighbouring noise.
function M.seed_for(record, style)
  local from = record.codepoint * 2654435761
  -- The style is part of the description, so it is part of the seed.
  --
  -- WHY THIS MATTERS MORE THAN IT LOOKS. Without it, two styles of one
  -- character begin from *identical* noise, meet an identical field at full
  -- control strength, and differ only by a trailing clause -- so they come out
  -- as very nearly the same picture, and asking for a different style appears
  -- to do nothing. It was doing something; there was no room left for it to do
  -- it in.
  --
  -- The rule the project actually wants is that the same *description* gives
  -- the same bytes, and the style is part of the description.
  --
  -- Folded back into range on every step, not once at the end. Numbers here are
  -- doubles: multiplying by thirty-one ten times carries a codepoint past the
  -- fifty-three bits a double keeps exactly, and the low bits -- which are the
  -- only ones the modulo reads -- become noise. It came out as zero.
  if style and style ~= "photographic" then
    from = from % 2147483647
    for index = 1, #style do
      from = (from * 31 + style:byte(index)) % 2147483647
    end
  end
  return from % 2147483647
end
-- }}}

-- {{{ size_of(made, wanted)
-- The picture is as wide as the field is. A word of two characters is twice
-- as wide as a single one, and asking for a square would squash it.
--
-- Rounded down to a multiple of eight, because that is what these models
-- work in and a size that is not one gets rounded somewhere out of sight.
local function size_of(made, wanted)
  local width = made.width or wanted.width
  local height = made.height or wanted.height
  return width - (width % 8), height - (height % 8)
end
-- }}}

-- {{{ sampler_for(g, record, made, wanted, model, positive, negative, latent, denoise)
-- The drawing itself, the same box for every route, so the routes differ only
-- in what they hand it. The seed is shared between routes: one character, one
-- starting noise, so inside and outside are two answers to one question.
local function sampler_for(g, record, made, wanted, model, positive, negative,
                           latent, denoise)
  local sampler = g:add("KSampler", {
    seed = M.seed_for(record, made.style),
    steps = wanted.steps,
    cfg = wanted.cfg,
    sampler_name = wanted.sampler,
    scheduler = wanted.scheduler,
    denoise = denoise or 1.0,
    -- The editor's seed selector is set to hold rather than to randomise. A
    -- workflow that arrives set to randomise stops being the picture that was
    -- tested the moment somebody presses the button.
    control_after_generate = "fixed",
  }, "draw it")
  g:link(model, "MODEL", sampler, "model")
  g:link(positive[1], positive[2], sampler, "positive")
  g:link(negative[1], negative[2], sampler, "negative")
  g:link(latent[1], latent[2], sampler, "latent_image")
  return sampler
end
-- }}}

-- {{{ stroke_mask(g, made)
-- The character's strokes as a mask the picture program can use: loaded as a
-- picture, and its red channel read as how much each pixel is inside.
local function stroke_mask(g, made)
  local picture = g:add("LoadImage", { image = made.mask_name },
                        "the strokes, as in and out")
  local mask = g:add("ImageToMask", { channel = "red" }, "read as a mask")
  g:link(picture, "IMAGE", mask, "image")
  return mask
end
-- }}}

-- {{{ save(g, record, made, last, last_socket)
local function save(g, record, made, last, last_socket)
  local route = made.route or "illusion"
  local prefix = "kanji/" .. record.character
  if route ~= "illusion" then prefix = prefix .. "-" .. route end
  local keep = g:add("SaveImage", { filename_prefix = prefix }, "keep it")
  g:link(last, last_socket, keep, "images")
end
-- }}}

-- {{{ M.build_inside(record, made, settings)
-- The inside route (`416`): the scene's things only where the strokes are,
-- and everything else background.
--
-- The stroke layer is never drawn. It is a mask, and two sentences are each
-- held to one side of it -- the subjects inside, the word *background* and the
-- empty world outside -- and combined into the one instruction the drawing
-- follows. The character is there only because the things are where the
-- strokes were.
function M.build_inside(record, made, settings)
  local wanted = settings.workflow
  local g = graph.new()
  local model = g:add("CheckpointLoaderSimple",
                      { ckpt_name = wanted.checkpoint }, "the model")

  local things = g:add("CLIPTextEncode", { text = made.parts.subjects },
                       "what stands along the strokes")
  local ground = g:add("CLIPTextEncode", { text = made.parts.background },
                       "what is everywhere else")
  local refusals = g:add("CLIPTextEncode", { text = made.negative },
                         "what it must not be")
  for _, box in ipairs({ things, ground, refusals }) do
    g:link(model, "CLIP", box, "clip")
  end

  local inside = stroke_mask(g, made)
  local outside = g:add("InvertMask", {}, "everything that is not a stroke")
  g:link(inside, "MASK", outside, "mask")

  local held_in = g:add("ConditioningSetMask",
                        { strength = 1.0, set_cond_area = "default" },
                        "the things, held to the strokes")
  g:link(things, "CONDITIONING", held_in, "conditioning")
  g:link(inside, "MASK", held_in, "mask")
  local held_out = g:add("ConditioningSetMask",
                         { strength = 1.0, set_cond_area = "default" },
                         "the background, held off them")
  g:link(ground, "CONDITIONING", held_out, "conditioning")
  g:link(outside, "MASK", held_out, "mask")
  local both = g:add("ConditioningCombine", {}, "one instruction")
  g:link(held_in, "CONDITIONING", both, "conditioning_1")
  g:link(held_out, "CONDITIONING", both, "conditioning_2")

  -- TWO PASSES, AND WHY. One pass with each sentence held to its side of the
  -- mask was tried first, on 休 at the far kitchen on 2026-10-04, and the
  -- character did not appear at all: a held sentence is a suggestion about
  -- where, and a model drawing a whole forest at once puts trees where trees
  -- look best. So the background is drawn first over the whole frame, and
  -- then only the pixels inside the strokes are drawn again with the things
  -- that stand there. Outside the mask nothing changes in the second pass, so
  -- the edge of what was redrawn is the edge of the character.
  local width, height = size_of(made, wanted)
  local blank = g:add("EmptyLatentImage", { width = width, height = height },
                      "an empty picture to start from")
  local world = sampler_for(g, record, made, wanted, model,
                            { held_out, "CONDITIONING" },
                            { refusals, "CONDITIONING" },
                            { blank, "LATENT" })
  -- AND A TONE TO START FROM. Redrawn from noise alone, the strokes were tried
  -- second and still did not appear: the model, asked to fill a tree-shaped
  -- hole in a forest, continues the forest. So before the second pass the
  -- strokes are painted into the background as one flat tone -- dark or light,
  -- as the world's polarity says (`docs/004`) -- and redrawn at less than full
  -- strength, which keeps that difference in light while turning it into
  -- things. The mask decides where; the tone is what makes "where" visible.
  local drawn = g:add("VAEDecode", {}, "the background, as pixels")
  g:link(world, "LATENT", drawn, "samples")
  g:link(model, "VAE", drawn, "vae")
  local tone = g:add("LoadImage", { image = made.tone_name },
                     "the strokes as one flat tone")
  local toned = g:add("ImageCompositeMasked",
                      { x = 0, y = 0, resize_source = false },
                      "the tone laid into the background")
  g:link(drawn, "IMAGE", toned, "destination")
  g:link(tone, "IMAGE", toned, "source")
  g:link(inside, "MASK", toned, "mask")
  local again = g:add("VAEEncode", {}, "back into the model's terms")
  g:link(toned, "IMAGE", again, "pixels")
  g:link(model, "VAE", again, "vae")
  local open = g:add("SetLatentNoiseMask", {}, "draw again only on the strokes")
  g:link(again, "LATENT", open, "samples")
  g:link(inside, "MASK", open, "mask")
  local sampler = sampler_for(g, record, made, wanted, model,
                              { both, "CONDITIONING" },
                              { refusals, "CONDITIONING" },
                              { open, "LATENT" },
                              settings.routes and settings.routes.inside_denoise)
  local picture = g:add("VAEDecode", {}, "turn it into pixels")
  g:link(sampler, "LATENT", picture, "samples")
  g:link(model, "VAE", picture, "vae")
  save(g, record, made, picture, "IMAGE")
  return g
end
-- }}}

-- {{{ M.build_outside(record, made, settings)
-- The outside route (`416`): the character painted, and the scene drawn around
-- it -- "you can't generate images in here".
--
-- The inked canvas is encoded and every pixel off the strokes is marked to be
-- drawn afresh; the strokes are held as they are. Then, after drawing, the ink
-- is pasted back over the finished picture through the same mask, because the
-- model's encoder and decoder smudge whatever passes through them and the
-- character is the one thing here that must arrive exactly as painted.
function M.build_outside(record, made, settings)
  local wanted = settings.workflow
  local g = graph.new()
  local model = g:add("CheckpointLoaderSimple",
                      { ckpt_name = wanted.checkpoint }, "the model")

  local scene = g:add("CLIPTextEncode", { text = made.parts.outside },
                      "what grows around the character")
  local refusals = g:add("CLIPTextEncode", { text = made.negative },
                         "what it must not be")
  g:link(model, "CLIP", scene, "clip")
  g:link(model, "CLIP", refusals, "clip")

  local ink = g:add("LoadImage", { image = made.ink_name },
                    "the character, painted")
  local inside = stroke_mask(g, made)
  local outside = g:add("InvertMask", {}, "where the scene may be drawn")
  g:link(inside, "MASK", outside, "mask")

  local encoded = g:add("VAEEncode", {}, "the painted canvas, as the model sees it")
  g:link(ink, "IMAGE", encoded, "pixels")
  g:link(model, "VAE", encoded, "vae")
  local open = g:add("SetLatentNoiseMask", {}, "draw only off the strokes")
  g:link(encoded, "LATENT", open, "samples")
  g:link(outside, "MASK", open, "mask")

  local sampler = sampler_for(g, record, made, wanted, model,
                              { scene, "CONDITIONING" },
                              { refusals, "CONDITIONING" },
                              { open, "LATENT" })
  local picture = g:add("VAEDecode", {}, "turn it into pixels")
  g:link(sampler, "LATENT", picture, "samples")
  g:link(model, "VAE", picture, "vae")

  -- The compositor pastes the source where the mask is one: the ink, where the
  -- strokes are.
  local exact = g:add("ImageCompositeMasked",
                      { x = 0, y = 0, resize_source = false },
                      "the ink, put back exactly")
  g:link(picture, "IMAGE", exact, "destination")
  g:link(ink, "IMAGE", exact, "source")
  g:link(inside, "MASK", exact, "mask")
  save(g, record, made, exact, "IMAGE")
  return g
end
-- }}}

-- {{{ M.build(record, made, settings)
-- The graph for one character, for the route `made.route` names.
--
-- `made` names the files this character's pictures were written as, relative to
-- the folder the picture program reads its inputs from.
--
-- A table of routes rather than a chain of tests: a route is a row, and the
-- three never share a branch.
local ROUTES = {}
M.ROUTES = ROUTES
function M.build(record, made, settings)
  local route = made.route or "illusion"
  local builder = ROUTES[route]
  if not builder then
    local names = {}
    for name in pairs(ROUTES) do names[#names + 1] = name end
    table.sort(names)
    error("there is no route called '" .. tostring(route) .. "'. There is: " ..
          table.concat(names, ", "))
  end
  return builder(record, made, settings)
end
-- }}}

-- {{{ M.build_illusion(record, made, settings)
-- The illusion route: the character hidden in the scene's light and dark,
-- through a control net. The original, and still the one for any kitchen that
-- has a control net.
function M.build_illusion(record, made, settings)
  local wanted = settings.workflow
  if not wanted.control_net then
    error("this kitchen has no control net, so the illusion route cannot " ..
          "run here; its routes setting should not name it (416)")
  end
  local g = graph.new()

  local model = g:add("CheckpointLoaderSimple",
                      { ckpt_name = wanted.checkpoint }, "the model")

  local scene = g:add("CLIPTextEncode", { text = made.positive },
                      "what the picture is")
  local refusals = g:add("CLIPTextEncode", { text = made.negative },
                         "what it must not be")
  g:link(model, "CLIP", scene, "clip")
  g:link(model, "CLIP", refusals, "clip")

  local field = g:add("LoadImage", { image = made.field_name },
                      "the character, as light and dark")
  local net = g:add("ControlNetLoader",
                    { control_net_name = wanted.control_net },
                    "what makes the picture obey it")

  -- Applied to both sentences at once, which is what makes the grey picture a
  -- constraint on the whole drawing rather than a note attached to the prompt.
  --
  -- Strength is how hard it pushes. Start and end are *when* it pushes, as
  -- fractions of the run, and they matter as much: composition is decided in
  -- the first steps and detail in the last, so the field is present from the
  -- beginning and released before the end -- placing the strokes, then getting
  -- out of the way while the model finishes the scene. Held to the last step it
  -- stamps the character through the picture.
  local applied = g:add("ControlNetApplyAdvanced", {
    strength = wanted.control_strength,
    start_percent = wanted.control_start,
    end_percent = wanted.control_end,
  }, "bias the drawing towards it")
  g:link(scene, "CONDITIONING", applied, "positive")
  g:link(refusals, "CONDITIONING", applied, "negative")
  g:link(net, "CONTROL_NET", applied, "control_net")
  g:link(field, "IMAGE", applied, "image")

  local width, height = size_of(made, wanted)
  local blank = g:add("EmptyLatentImage",
                      { width = width, height = height },
                      "an empty picture to start from")
  local sampler = sampler_for(g, record, made, wanted, model,
                              { applied, "positive" }, { applied, "negative" },
                              { blank, "LATENT" })

  local picture = g:add("VAEDecode", {}, "turn it into pixels")
  g:link(sampler, "LATENT", picture, "samples")
  g:link(model, "VAE", picture, "vae")

  local last = picture
  local last_socket = "IMAGE"

  if wanted.composite_arrows and made.arrows_name then
    local sheet = g:add("LoadImage", { image = made.arrows_name },
                        "the stroke-order arrows")

    -- THE ONE DETAIL THAT DECIDES WHETHER THIS WORKS. LoadImage's mask output
    -- is the *inverse* of the picture's transparency: one where the picture is
    -- see-through, zero where it is solid. The compositor pastes where the mask
    -- is one. Wire those together directly and the arrows are pasted exactly
    -- where the arrows are not.
    local flipped = g:add("InvertMask", {},
                          "because the mask arrives inside out")
    g:link(sheet, "MASK", flipped, "mask")

    local over = g:add("ImageCompositeMasked",
                       { x = 0, y = 0, resize_source = true },
                       "lay them over the picture")
    g:link(picture, "IMAGE", over, "destination")
    g:link(sheet, "IMAGE", over, "source")
    g:link(flipped, "MASK", over, "mask")
    last, last_socket = over, "IMAGE"
  end

  save(g, record, made, last, last_socket)
  return g
end
-- }}}

ROUTES.illusion = M.build_illusion
ROUTES.inside = M.build_inside
ROUTES.outside = M.build_outside

-- {{{ M.assumptions(settings)
-- What this workflow takes on faith, said out loud.
--
-- There is no picture program on this machine. The model and the control net
-- are names that have to match some other installation's model folder, and
-- nothing here can look. Stating the assumption is the whole of what can be
-- done about it, so it is done rather than skipped.
-- {{{ M.shape_warning(width, height)
-- Whether this picture is a shape the far end was never trained on.
--
-- Diffusion models learn on images of roughly one aspect and go strange well
-- away from it -- repeated subjects, drifting composition. A five-character
-- phrase is five times as wide as it is tall, and that is far outside what any
-- of them have seen. Said out loud rather than prevented, because a long phrase
-- is a legitimate thing to ask for and the result is worth looking at even if
-- it comes out badly.
function M.shape_warning(width, height)
  local ratio = width / height
  if ratio <= 2.6 then return nil end
  return string.format(
    "this picture is %.1f times as wide as it is tall, which is well outside " ..
    "what\n  a diffusion model has been trained on. Expect the composition to " ..
    "drift or\n  the subject to repeat across the frame.", ratio)
end
-- }}}

function M.assumptions(settings)
  local said = {
    "the checkpoint named '" .. settings.workflow.checkpoint ..
      "' is in that installation's models/checkpoints",
  }
  if settings.workflow.control_net then
    said[#said + 1] = "the control net named '" .. settings.workflow.control_net ..
      "' is in its models/controlnet, and is one of the family that reads a " ..
      "grey picture as a map of light and dark"
  end
  said[#said + 1] = "each character's input pictures have been uploaded to its " ..
    "input folder, under kanji/ -- which src/044 does, and checks all of this " ..
    "against the far end before posting (415)"
  return said
end
-- }}}

return M
