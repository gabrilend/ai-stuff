-- 100-the-phase-demonstrations.lua
--
-- One demonstration per phase. Each loads the whole blueprint set, picks out
-- that phase's files, and shows what the phase actually produced: its headline
-- numbers with live values, every constraint it asserts and whether it holds,
-- and what it left open.
--
-- For a general reader: this project's deliverable is a set of blueprints in
-- which no number is written twice, so a demonstration of it cannot be a
-- program doing something -- it is the design answering questions about itself.
-- Every figure printed below is resolved from the blueprints at the moment you
-- run it. Change a dimension and run it again and the numbers move.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
local PHASE = nil
for i = 1, 8 do
  if arg and arg[i] then
    if tonumber(arg[i]) then PHASE = tonumber(arg[i]) else DIR = arg[i] end
  end
end

local units      = dofile(DIR .. "/src/091-units.lua")
local expression = dofile(DIR .. "/src/092-expression.lua")
local check      = dofile(DIR .. "/src/095-constraint-check.lua")

-- What each phase is, and the handful of numbers that say what it produced. The
-- symbol names are the demonstration: a phase that could not name six of its own
-- figures has not settled anything.
local PHASES = {
  [1]  = { "Datum", "the frame, the materials, the master dimensions",
           { "n_face", "n_edge", "L_cube", "L_cavity", "L_core", "Pr_water", "cte_ratio", "A_die" } },
  [2]  = { "The Body", "the cube as a mechanical object",
           { "m_cube", "rho_mean", "t_stack", "n_seal_total", "seal_compression_range",
             "tol_loop", "bow_face", "margin_tier", "F_mount_shock" } },
  [3]  = { "The Corners", "where the heat goes and the plumbing that takes it",
           { "P_heat", "h_conv", "eta_surface", "UA_total", "dT_conv", "Q_total",
             "dp_loop", "T_j_peak", "margin_thermal", "s_hotspot", "gain_field", "dT_walk" } },
  [4]  = { "The Rails", "where the current comes from",
           { "I_supply", "I_would_be", "I_die_logic", "C_raw", "C_ramped", "ramp_gain",
             "dV_total", "m_worst", "t_holdup" } },
  [5]  = { "The Yolk", "the block of shared memory at the centre",
           { "d_areal", "C_tier", "C_core_raw", "C_core_usable", "B_core", "n_tier",
             "t_tsv_delay", "f_ecc_line", "t_upset", "t_double" } },
  [6]  = { "The Faces", "one compute face, six times",
           { "A_slice_die", "C_face_slice", "m_slice", "ops_die", "ops_machine",
             "P_engine_die", "dT_hotspot", "dT_lateral", "w_weight_eff", "acc_headroom" } },
  [7]  = { "The Sieve", "six radial links and the pipeline on them",
           { "n_radial_pad", "bind_ratio", "w_transfer", "t_link_rt", "f_single",
             "f_other", "t_token", "t_stage", "f_poll_cost" } },
  [8]  = { "The Feed", "how a model gets into the cube",
           { "n_port_conductor", "B_feed", "t_load_relay", "t_load_min", "f_sequential",
             "ratio_core_media", "f_lead_layer", "m_core_feed" } },
  [9]  = { "The Spout", "the face that became a tube of wire",
           { "n_fine_pad", "n_pane_bit", "C_pane_mb", "E_pane", "t_core_out", "ratio_net",
             "ratio_fill", "y_array_raw", "ratio_align", "f_cube_busy", "t_mem_read" } },
  [10] = { "The Metronome", "clock, reset, and agreeing about when",
           { "f_face", "f_core", "jit_budget", "skew_face_all", "mtbf_all",
             "t_path_face", "t_margin_face", "t_boot_cold", "ratio_warm", "f_boost_max" } },
  [11] = { "The Recipe", "cutting a model up and pouring it through",
           { "n_param", "C_weights", "C_layer_weights", "C_resident", "f_resident",
             "batch_cross", "tok_s_single", "tok_s_agg", "tok_s_prefill",
             "gain_bw", "gain_cap", "ratio_full" } },
  [12] = { "The Kiln", "making it, testing it, waking it",
           { "y_die_logic", "y_die_tier", "y_stack_naive", "y_stack_red", "y_cube",
             "cost_si_cube", "f_yield_cost", "t_bringup_h", "t_life_seconds", "mtbf_silent" } },
  [13] = { "The Whole Cake", "integration, materials, the specification sheet",
           { "n_seam", "n_seam_open", "n_alarm", "n_count_only", "A_si_total",
             "f_cost_si", "f_cost_yield", "f_derived", "n_omission" } },
  [14] = { "The Instruments", "the programs that check all of it",
           {} },
}

-- {{{ local function bar()
local function bar(ch)
  return string.rep(ch or "-", 74)
end
-- }}}

-- {{{ local function fmt()
local function fmt(L, name)
  local q, d = L.value[name], L.decl[name]
  if not d then return "(no such symbol)" end
  if not q then return "unresolved" end
  local ok, s = pcall(units.format, q, d.unit, 5)
  return ok and s or units.format(q)
end
-- }}}

-- {{{ local function show_phase()
local function show_phase(R, n)
  local L = R.ledger
  local spec = PHASES[n]
  if not spec then
    print("no such phase: " .. tostring(n))
    return 1
  end

  print("")
  print(bar("="))
  print(("  PHASE %d -- %s"):format(n, spec[1]))
  print(("  %s"):format(spec[2]))
  print(bar("="))

  -- which blueprints belong to it
  local mine, nsym, ncon = {}, 0, 0
  for _, bp in ipairs(L.blueprints) do
    if bp.phase == n then
      mine[#mine + 1] = bp
      nsym = nsym + #bp.symbols
      ncon = ncon + #bp.constraints
    end
  end
  print("")
  print(("  %d blueprints, %d symbols, %d constraints"):format(#mine, nsym, ncon))
  print("")
  for _, bp in ipairs(mine) do
    print(("    %-5s %-42s %3d sym  %2d con")
      :format(bp.number, bp.title:sub(1, 42), #bp.symbols, #bp.constraints))
  end

  -- the headline numbers, live
  if #spec[3] > 0 then
    print("")
    print("  WHAT IT PRODUCED")
    print("")
    for _, name in ipairs(spec[3]) do
      local d = L.decl[name]
      local meaning = d and d.meaning or ""
      if #meaning > 40 then meaning = meaning:sub(1, 39) .. "\226\128\166" end
      print(("    %-18s %-18s %s"):format(name, fmt(L, name), meaning))
    end
  end

  -- every constraint this phase asserts, and whether it holds
  print("")
  print("  WHAT IT ASSERTS")
  print("")
  local held, failed = 0, 0
  local function belongs(c) return c.blueprint.phase == n end
  for _, rec in ipairs(R.passed) do
    if belongs(rec.c) then held = held + 1 end
  end
  for _, rec in ipairs(R.failed) do
    if belongs(rec.c) then
      failed = failed + 1
      print(("    FAILS  %-10s %s"):format(rec.c.tag, rec.c.relation))
    end
  end
  for _, m in ipairs(R.unresolved) do
    if belongs(m.c) then
      failed = failed + 1
      print(("    WAITS  %-10s %s"):format(m.c.tag, m.c.why))
    end
  end
  print(("    %d of %d hold."):format(held, held + failed))

  -- anything this phase left unfinished
  local targets = {}
  for _, name in ipairs(L.targets) do
    if L.decl[name].blueprint.phase == n then targets[#targets + 1] = name end
  end
  if #targets > 0 then
    print("")
    print("  WHAT IT LEFT AS A TARGET")
    print("")
    for _, name in ipairs(targets) do
      print(("    %-18s %s"):format(name, L.decl[name].meaning:sub(1, 50)))
    end
  end

  print("")
  return failed > 0 and 1 or 0
end
-- }}}

-- {{{ local function show_instruments()
-- Phase 14 has no design numbers of its own. What it produced is the ability to
-- ask the other thirteen anything, so the demonstration is to exercise it.
local function show_instruments(R)
  local L = R.ledger
  print("")
  print(bar("="))
  print("  PHASE 14 -- The Instruments")
  print("  the programs that read blueprints and check them")
  print(bar("="))
  print("")
  print("  Phase 14 declares no dimensions of its own. What it produced is the")
  print("  ability to ask the other thirteen phases anything, so this")
  print("  demonstration exercises that rather than listing numbers.")
  print("")
  print("  THE SET, AS THE LEDGER SEES IT")
  print("")
  local kinds = { given = 0, measured = 0, derived = 0, solved = 0, target = 0 }
  for _, n in ipairs(L.order) do kinds[L.decl[n].kind] = kinds[L.decl[n].kind] + 1 end
  print(("    blueprints          %d"):format(#L.blueprints))
  print(("    symbols             %d"):format(#L.order))
  print(("      chosen            %d"):format(kinds.given))
  print(("      measured          %d"):format(kinds.measured))
  print(("      derived           %d"):format(kinds.derived))
  print(("      solved by program %d"):format(kinds.solved))
  print(("      still targets     %d"):format(kinds.target))
  print(("    constraints         %d"):format(#L.constraints))
  print(("    holding             %d"):format(#R.passed))
  print(("    orphan symbols      %d"):format(#L.orphans))
  print("")
  print("  THE UNITS ENGINE REFUSING THINGS")
  print("")
  local trials = {
    { "a length plus a temperature", function() return units.new(1, "m") + units.new(1, "K") end },
    { "a bandwidth plus a clock",    function() return units.new(1, "bit/s") + units.new(1, "Hz") end },
    { "tokens per second as a clock", function() return units.new(1, "tok/s") + units.new(1, "Hz") end },
    { "a length in watts",           function() return units.value_in(units.new(1, "m"), "W") end },
  }
  for _, t in ipairs(trials) do
    local ok, err = pcall(t[2])
    print(("    %-30s %s"):format(t[1], ok and "ACCEPTED (wrong!)" or "refused"))
    if not ok then print(("      %s"):format(tostring(err):sub(1, 66))) end
  end
  print("")
  print("  A DERIVATION, TRACED")
  print("")
  local d = L.decl["L_core"]
  print(("    %s = %s"):format("L_core", d.expr))
  for _, ref in ipairs(expression.refs(d.tree)) do
    local rd = L.decl[ref]
    print(("      %-12s %-12s %s"):format(ref, fmt(L, ref), rd.kind))
  end
  print(("    %-14s %s"):format("comes to", fmt(L, "L_core")))
  print("")
  print("  and the same number, derived the other way round, from the memory stack:")
  print(("    %-14s %s"):format("n_tier x pitch",
    units.format(L.value["n_tier"] * L.value["t_tier_pitch"], "mm", 5)))
  print("")
  print("  Nothing forces those two to agree. C-012-9 is what notices when they")
  print("  stop, and it is the single most valuable line in the blueprint set.")
  print("")
  print("  A NUMBER THAT IS RE-RUN RATHER THAN REMEMBERED")
  print("")
  print("  Twenty values in this project came out of a program, because no")
  print("  expression in this notation could produce them -- a network that")
  print("  converges, a search over five hundred and twelve candidates, a list")
  print("  of twelve edges. The number in the blueprint is a copy, and a copy")
  print("  goes stale. So the checker re-runs the program on every pass:")
  print("")
  for _, n in ipairs(L.solved or {}) do
    local d = L.decl[n]
    print(("    %-16s %-10s %s"):format(n, fmt(L, n), d.meaning:match("%-%- from (%d%d%d)")))
  end
  print("")
  print("  Change a rail's cross-section in 016 and every one of the network")
  print("  figures above stops matching what produced it, and the run fails")
  print("  rather than quietly describing a machine that no longer exists.")
  print("")
  return 0
end
-- }}}

-- Some phases have more to show than a list of numbers, because an instrument
-- was written for them that answers questions the notation cannot. One entry per
-- such phase, as a table rather than a chain of comparisons: adding a phase's
-- extra is a line here, and a phase with no entry simply has none.
local EXTRA = {
  -- Phase 3's plumbing is a graph and a network, neither of which fits in a
  -- blueprint. 102 holds both and this is where a reader sees it work.
  [3] = function()
    local cube = dofile(DIR .. "/src/102-the-cube-solved.lua")
    cube.report(cube.solve(DIR))
  end,
  -- Phase 14 has no dimensions of its own at all; its whole demonstration is the
  -- instruments being exercised, so it replaces the standard one rather than
  -- following it.
}

local R = check.run(DIR)
if PHASE == 14 then os.exit(show_instruments(R)) end
if PHASE then
  local code = show_phase(R, PHASE)
  if EXTRA[PHASE] then EXTRA[PHASE]() end
  os.exit(code)
end

-- no phase given: a summary of all of them
print("")
print(bar("="))
print("  six sided dice layer cake -- all fourteen phases")
print(bar("="))
print("")
for n = 1, 14 do
  local spec = PHASES[n]
  local nbp, ncon = 0, 0
  for _, bp in ipairs(R.ledger.blueprints) do
    if bp.phase == n then nbp = nbp + 1; ncon = ncon + #bp.constraints end
  end
  print(("  %2d  %-16s %2d blueprints  %3d constraints   %s")
    :format(n, spec[1], nbp, ncon, spec[2]))
end
print("")
print(("  %d of %d constraints hold across the whole set."):format(
  #R.passed, #R.passed + #R.failed))
print("")
os.exit(0)
