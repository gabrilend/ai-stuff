-- example-recipe.lua
--
-- What a seed IS. It never names a machine -- read the top of src/088 for
-- why that matters and how it is enforced.
--
-- This lives in input/ because the first thing a program should do is read
-- the input files, and from there it knows exactly how to start up. A
-- different seed is a different file beside this one.

return {
  recipe_id = "esia-example",

  -- which architectures this seed carries an engine for, and how wide a
  -- vector arrangement each engine assumes. Carrying more than one level for
  -- an architecture is faster and is three times the testing (402).
  engines = {
    { arch = "x86_64",  level = "baseline" },
    { arch = "x86_64",  level = "wider" },
    { arch = "aarch64", level = "baseline" },
    { arch = "riscv64", level = "baseline" },
  },

  -- The operator's choice at build time, not this project's. Named and
  -- hashed, so the manifest says which one this image actually carries
  -- rather than which one somebody meant to give it.
  model = {
    name = "the fixture model",
    hash = "taken from the packed bytes at build time",
  },

  instruction = "assets/081-the-instruction.md",
  patterns = "src/083-the-patterns.lua",
  descriptions = "src/082-the-descriptions.lua",

  -- Same recipe and same seed gives the same machine, exactly -- which turns
  -- a strange failure into something reproducible by handing somebody an
  -- image rather than by explaining what happened.
  randomness = {
    bytes = 102400,
    seed = 20260802,
  },
}
