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

-- {{{ M.seed_for(record)
-- The starting noise for a character, taken from the character itself.
--
-- Not from a clock. A given character regenerates identically, and two runs
-- over the whole set differ only where the code changed -- without which,
-- comparing six thousand pictures against six thousand pictures is impossible
-- and every change looks like it changed everything.
--
-- Multiplied by a large odd number so that neighbouring characters, whose
-- numbers differ by one, do not get neighbouring noise.
function M.seed_for(record)
  return (record.codepoint * 2654435761) % 2147483647
end
-- }}}

-- {{{ M.build(record, made, settings)
-- The graph for one character.
--
-- `made` names the files this character's pictures were written as, relative to
-- the folder the picture program reads its inputs from.
function M.build(record, made, settings)
  local wanted = settings.workflow
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

  local blank = g:add("EmptyLatentImage",
                      { width = wanted.width, height = wanted.height },
                      "an empty picture to start from")

  local sampler = g:add("KSampler", {
    seed = M.seed_for(record),
    steps = wanted.steps,
    cfg = wanted.cfg,
    sampler_name = wanted.sampler,
    scheduler = wanted.scheduler,
    denoise = 1.0,
    -- The editor's seed selector is set to hold rather than to randomise. A
    -- workflow that arrives set to randomise stops being the picture that was
    -- tested the moment somebody presses the button.
    control_after_generate = "fixed",
  }, "draw it")
  g:link(model, "MODEL", sampler, "model")
  g:link(applied, "positive", sampler, "positive")
  g:link(applied, "negative", sampler, "negative")
  g:link(blank, "LATENT", sampler, "latent_image")

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

  local save = g:add("SaveImage",
                     { filename_prefix = "kanji/" .. record.character },
                     "keep it")
  g:link(last, last_socket, save, "images")

  return g
end
-- }}}

-- {{{ M.assumptions(settings)
-- What this workflow takes on faith, said out loud.
--
-- There is no picture program on this machine. The model and the control net
-- are names that have to match some other installation's model folder, and
-- nothing here can look. Stating the assumption is the whole of what can be
-- done about it, so it is done rather than skipped.
function M.assumptions(settings)
  return {
    "the checkpoint named '" .. settings.workflow.checkpoint ..
      "' is in that installation's models/checkpoints",
    "the control net named '" .. settings.workflow.control_net ..
      "' is in its models/controlnet, and is one of the family that reads a " ..
      "grey picture as a map of light and dark",
    "the two pictures for each character have been copied into its input " ..
      "folder, under kanji/",
  }
end
-- }}}

return M
