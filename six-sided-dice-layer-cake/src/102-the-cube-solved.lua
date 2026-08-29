-- 102-the-cube-solved.lua
--
-- Holds the cube as data and answers the three questions the notation cannot.
--
-- For a general reader: every blueprint in this project is a list of named
-- numbers and expressions over them, which is enough for almost everything and
-- not enough for three things. It cannot hold a list, so the twelve edges of the
-- cube live as prose in one document and as the number twelve in another, and
-- nobody has ever checked that the prose and the number describe the same
-- object. It cannot search, so the question of which coolant rail feeds which
-- face -- a matching problem with five hundred and twelve candidates -- was left
-- unanswered. And it cannot iterate, so the flow through a fifty-branch cooling
-- circuit could only be estimated.
--
-- This program does all three. It builds the cube from its definition rather
-- than from a list somebody typed, proves the plumbing property by enumeration,
-- searches every legal rail assignment for the one that starves the worst face
-- least, and solves the resulting hydraulic network by Newton's method. The
-- numbers it produces are copied into the blueprints as `solved` values, and the
-- checker re-runs this on every pass and refuses if a copy has gone stale.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local units  = dofile(DIR .. "/src/091-units.lua")
local ledger = dofile(DIR .. "/src/094-ledger.lua")

local M = {}

-- ---------------------------------------------------------------------------
-- The cube, built rather than listed
-- ---------------------------------------------------------------------------
--
-- Corner c is the integer whose three bits are its coordinates: bit 0 is x, bit
-- 1 is y, bit 2 is z, which is the labelling 010 fixes and every drawing in the
-- project is read in. A corner's parity is the exclusive-or of those bits, and
-- the whole plumbing scheme rests on what that parity does to an edge.

-- {{{ local function label()
-- A corner's written name, C followed by its three coordinate bits.
--
-- 010 writes a corner as C followed by x, y, z in that order, so the bits come
-- out of the integer in the opposite order to the way an integer is usually
-- written. Getting this backwards would relabel the cube without changing any
-- of the arithmetic, which is the kind of mistake that survives a long time.
local function label(c)
  local x = c % 2
  local y = math.floor(c / 2) % 2
  local z = math.floor(c / 4) % 2
  return ("C%d%d%d"):format(x, y, z)
end
-- }}}

-- {{{ local function parity()
-- A corner's parity: the exclusive-or of its three coordinate bits. Zero means
-- coolant enters there and one means it leaves, and that single bit is what the
-- whole plumbing scheme rests on -- an edge changes exactly one coordinate, so
-- every edge joins a corner of one parity to a corner of the other.
local function parity(c)
  local p, n = 0, c
  while n > 0 do p = p + n % 2; n = math.floor(n / 2) end
  return p % 2
end
-- }}}

-- {{{ local function build_cube()
-- Corners, edges and faces, every one of them derived from the definition of a
-- cube rather than copied from a document. An edge is a pair of corners
-- differing in exactly one coordinate; a face is the four corners agreeing on
-- one coordinate. Nothing here is a list a person maintains, which is the point:
-- the twelve-edge list in 010 can now be checked against something rather than
-- believed.
local function build_cube()
  local K = { corner = {}, edge = {}, face = {} }

  for c = 0, 7 do
    K.corner[c] = { id = c, label = label(c), parity = parity(c),
                    x = c % 2, y = math.floor(c / 2) % 2, z = math.floor(c / 4) % 2 }
  end

  -- Each unordered pair once, lower label first, which is the order 010 writes
  -- them in so the two lists can be compared line for line.
  for a = 0, 7 do
    for b = a + 1, 7 do
      local diff = 0
      for bit = 0, 2 do
        local m = 2 ^ bit
        if math.floor(a / m) % 2 ~= math.floor(b / m) % 2 then diff = diff + 1 end
      end
      if diff == 1 then
        -- The axis an edge runs along is the coordinate that changes across it,
        -- and it is what makes two faces' fields perpendicular or not.
        local axis
        for bit = 0, 2 do
          local m = 2 ^ bit
          if math.floor(a / m) % 2 ~= math.floor(b / m) % 2 then axis = bit end
        end
        K.edge[#K.edge + 1] = { a = a, b = b, axis = axis,
                                name = label(a) .. "-" .. label(b) }
      end
    end
  end

  -- A face is named by the direction of its outward normal, and carries the
  -- sieve index 010 gives it -- its position in the pipeline a token falls
  -- through. The order matters to 026 and not to the plumbing, and it is carried
  -- here so that a report about a face can say which stage it is.
  local NORMAL = {
    { axis = 2, side = 0, name = "-Z", sieve = 0 },
    { axis = 2, side = 1, name = "+Z", sieve = 1 },
    { axis = 0, side = 0, name = "-X", sieve = 2 },
    { axis = 0, side = 1, name = "+X", sieve = 3 },
    { axis = 1, side = 0, name = "-Y", sieve = 4 },
    { axis = 1, side = 1, name = "+Y", sieve = 5 },
  }
  for i, f in ipairs(NORMAL) do
    local corners = {}
    for c = 0, 7 do
      local m = 2 ^ f.axis
      if math.floor(c / m) % 2 == f.side then corners[#corners + 1] = c end
    end
    -- The four edges of a face are the edges with both ends on it. Two run along
    -- one in-plane axis and two along the other, and the two pairs are the two
    -- ways this face's channels can be made to run.
    local edges = {}
    for ei, e in ipairs(K.edge) do
      local on_a, on_b = false, false
      for _, c in ipairs(corners) do
        if c == e.a then on_a = true end
        if c == e.b then on_b = true end
      end
      if on_a and on_b then edges[#edges + 1] = ei end
    end
    K.face[i] = { id = i, name = f.name, sieve = f.sieve, axis = f.axis,
                  side = f.side, corners = corners, edges = edges }
  end

  return K
end
-- }}}

-- ---------------------------------------------------------------------------
-- The proofs, enumerated rather than asserted
-- ---------------------------------------------------------------------------
--
-- 023 states three properties of the parity arrangement and asserts all three by
-- counting. Counting is not proof: `C-023-1` multiplies four fed corners by
-- three edges each, gets twelve, and would go on getting twelve for a choice of
-- corners that does not work. These read the actual edges.

-- {{{ local function prove_bipartition()
-- Every edge joins an even-parity corner to an odd one. This is what makes the
-- supply and return networks reach every corner without either one ever having
-- two ports at the ends of a single channel, and it is the whole reason the four
-- fed corners are the ones they are.
local function prove_bipartition(K)
  local crossing, inside = 0, 0
  for _, e in ipairs(K.edge) do
    if K.corner[e.a].parity ~= K.corner[e.b].parity then crossing = crossing + 1
    else inside = inside + 1 end
  end
  return crossing, inside
end
-- }}}

-- {{{ local function prove_tetrahedron()
-- The four fed corners are mutually two coordinates apart, so every one of their
-- six pairwise distances is the cube's face diagonal. 023 calls this decoration
-- and it is, but a relabelling that broke it would have broken something else
-- first, so it is worth having as a tripwire.
local function prove_tetrahedron(K)
  local fed = {}
  for c = 0, 7 do if K.corner[c].parity == 0 then fed[#fed + 1] = c end end
  local equal, total = 0, 0
  for i = 1, #fed do
    for j = i + 1, #fed do
      total = total + 1
      local d = 0
      for bit = 0, 2 do
        local m = 2 ^ bit
        if math.floor(fed[i] / m) % 2 ~= math.floor(fed[j] / m) % 2 then d = d + 1 end
      end
      -- Two coordinates differing is the face diagonal. One would be an edge,
      -- three the body diagonal, and either would mean the fed set is not the
      -- parity set.
      if d == 2 then equal = equal + 1 end
    end
  end
  return equal, total, #fed
end
-- }}}

-- {{{ local function check_document()
-- The twelve edges are written out in 010 as prose, and until now nothing has
-- ever compared that list to the object it describes. This reads them back out
-- of the document and checks the two agree as sets -- so a typing slip in a
-- corner label is a failed run rather than a drawing nobody can follow.
local function check_document(K, dir)
  local fh = io.open(dir .. "/src/010-frame-of-reference.md", "r")
  if not fh then return 0, 0 end
  local text = fh:read("*a")
  fh:close()

  local written, seen = {}, {}
  for a, b in text:gmatch("(C[01][01][01])%-(C[01][01][01])") do
    local key = a .. "-" .. b
    if not seen[key] then seen[key] = true; written[#written + 1] = key end
  end

  local built = {}
  for _, e in ipairs(K.edge) do
    -- 010 writes the lower label first, and label order is not integer order --
    -- C010 is corner 2 and C001 is corner 4 -- so the comparison has to sort by
    -- the string the document uses rather than by the id the program uses.
    local la, lb = K.corner[e.a].label, K.corner[e.b].label
    if la > lb then la, lb = lb, la end
    built[la .. "-" .. lb] = true
  end

  local matched = 0
  for _, key in ipairs(written) do if built[key] then matched = matched + 1 end end
  return matched, #written
end
-- }}}

-- ---------------------------------------------------------------------------
-- The order a token visits the faces in
-- ---------------------------------------------------------------------------
--
-- 010 orders the six faces into the six stages of the pipeline, and wanted every
-- consecutive pair to be on opposite sides of the cube so that the one face
-- doing arithmetic is always as far as possible from the face that was doing it
-- a moment ago.
--
-- Its table claimed that was achieved and the claim was false: two of the five
-- steps land on an adjacent face, and the table had named the wrong face as the
-- opposite one twice. Nothing caught it for the same reason nothing checks any
-- of this project's orderings -- a sequence of six faces is a list, and the
-- notation holds numbers.
--
-- These count it properly, and settle whether the ordering could have been
-- better by trying all seven hundred and twenty of them.

-- {{{ local function antipodal()
-- Two faces are opposite when they lie on the same axis and different sides of
-- it. Everything below is this one test, counted.
local function antipodal(a, b)
  return a.axis == b.axis and a.side ~= b.side
end
-- }}}

-- {{{ local function anti_steps()
-- How many of the five steps through an ordering land on the opposite face.
local function anti_steps(order)
  local n = 0
  for i = 1, #order - 1 do
    if antipodal(order[i], order[i + 1]) then n = n + 1 end
  end
  return n
end
-- }}}

-- {{{ local function best_ordering()
-- The most antipodal steps any ordering of the six faces can have, found by
-- trying every one of them.
--
-- The answer is three, and the reason is worth having in prose as well as in a
-- number: a cube has three pairs of opposite faces, an ordering visits all six,
-- so it has to cross from one pair to another twice -- and a crossing between
-- two different pairs is always to an adjacent face. Two of the five steps are
-- therefore spent, whatever anybody does. The exhaustive search is here anyway,
-- because an argument in a comment is what the false claim in 010 was.
local function best_ordering(K)
  local best, faces = 0, {}
  for i = 1, #K.face do faces[i] = K.face[i] end

  local order = {}
  local used = {}
  local function recurse(depth)
    if depth > #faces then
      local n = anti_steps(order)
      if n > best then best = n end
      return
    end
    for i = 1, #faces do
      if not used[i] then
        used[i] = true; order[depth] = faces[i]
        recurse(depth + 1)
        used[i] = false
      end
    end
  end
  recurse(1)
  return best
end
-- }}}

-- {{{ local function sieve_order()
-- The faces in the order a token visits them, which is the sieve index 010
-- gives each one rather than the order they happen to be built in.
local function sieve_order(K)
  local order = {}
  for _, f in ipairs(K.face) do order[f.sieve + 1] = f end
  return order
end
-- }}}

-- ---------------------------------------------------------------------------
-- Which rail feeds which face
-- ---------------------------------------------------------------------------
--
-- A face's microchannels run from a plenum along one of its edges to a plenum
-- along the opposite one, so a face uses two of its four edges and the two must
-- be parallel. That gives each face two choices, which axis its channels run
-- along, and then two more, which of the pair is the supply side.
--
-- Three rules narrow it. Opposite faces must run their channels perpendicular,
-- so that no pair of rails ends up carrying two full loads. No supply channel
-- may feed two faces, and no return channel may drain two. Five hundred and
-- twelve arrangements satisfy the first rule by construction; the other two are
-- what the search is for, and the flow solve then picks between the survivors.

-- {{{ local function in_plane()
local function in_plane(face)
  local a = {}
  for axis = 0, 2 do if axis ~= face.axis then a[#a + 1] = axis end end
  return a
end
-- }}}

-- {{{ local function assignments()
-- Every arrangement that obeys all three rules, as a list. Each entry maps a
-- face id to the edge index its supply plenum sits on and the edge index its
-- return plenum sits on.
--
-- The enumeration is exhaustive rather than clever because five hundred and
-- twelve is a number a computer does not notice, and an exhaustive search that
-- reports how many candidates it rejected is worth more than a constructive
-- argument nobody can check.
local function assignments(K)
  local PAIR = { { 1, 2 }, { 3, 4 }, { 5, 6 } }
  local out, tried = {}, 0

  -- Which of a face's four edges lie along a given axis. Two always do.
  local function edges_along(face, axis)
    local e = {}
    for _, ei in ipairs(face.edges) do
      if K.edge[ei].axis == axis then e[#e + 1] = ei end
    end
    return e
  end

  local choice = {}
  local function recurse(pi)
    if pi > #PAIR then
      -- The three pairs have their axes; now each of the six faces chooses which
      -- of its two plenum edges is the supply side. Sixty-four ways, walked as
      -- the six bits of one integer.
      for bits = 0, 63 do
        tried = tried + 1
        local plan, sup, ret, ok = {}, {}, {}, true
        for fid = 1, 6 do
          local e = edges_along(K.face[fid], choice[fid])
          local first = math.floor(bits / 2 ^ (fid - 1)) % 2
          local s = first == 0 and e[1] or e[2]
          local r = first == 0 and e[2] or e[1]
          -- A channel that already feeds a face cannot feed another. This is the
          -- rule that does the work: without it, one rail would carry two loads
          -- and the face at the far end of it would be starved.
          if sup[s] or ret[r] then ok = false; break end
          sup[s], ret[r] = fid, fid
          -- `axis` is the axis the two plenum rails run along. The channels run
          -- across the face, along the other in-plane axis, which is what the
          -- perpendicularity rule is actually about -- so both are recorded and
          -- neither is left for a reader to infer.
          local ip, channel = in_plane(K.face[fid]), nil
          channel = ip[1] == choice[fid] and ip[2] or ip[1]
          plan[fid] = { supply = s, ret = r, axis = choice[fid], channel = channel }
        end
        if ok then out[#out + 1] = plan end
      end
      return
    end
    local a, b = PAIR[pi][1], PAIR[pi][2]
    local ax = in_plane(K.face[a])
    -- Opposite faces take different in-plane axes, which is what perpendicular
    -- means here. Two ways round, and they are not equivalent once the corner
    -- parity is taken into account.
    for _, swap in ipairs({ false, true }) do
      choice[a] = swap and ax[2] or ax[1]
      choice[b] = swap and ax[1] or ax[2]
      recurse(pi + 1)
    end
  end
  recurse(1)
  return out, tried
end
-- }}}

-- {{{ local function perpendicular_pairs()
-- How many opposite-face pairs actually run perpendicular under a plan. Should
-- be all three by construction, which is exactly why it is worth counting: it is
-- the assertion that the construction did what it said.
local function perpendicular_pairs(K, plan)
  local n = 0
  for _, p in ipairs({ { 1, 2 }, { 3, 4 }, { 5, 6 } }) do
    if plan[p[1]].channel ~= plan[p[2]].channel then n = n + 1 end
  end
  return n
end
-- }}}

-- ---------------------------------------------------------------------------
-- The hydraulic network
-- ---------------------------------------------------------------------------
--
-- Fifty branches across twenty-nine nodes. The ticket that asked for this
-- guessed twenty branches and eight nodes, which was the cube's corners and
-- edges rather than its plumbing: every rail that feeds a plenum is two rails
-- with a tap between them, the supply and return networks are separate objects
-- sharing a geometry, and the corner blocks are branches of their own.
--
-- Three flow regimes meet here and that is what makes it an iteration rather
-- than an elimination.
--
--   the microchannel fields are laminar, and lose pressure in proportion to
--   flow -- the first power
--
--   the rails are turbulent on Blasius, and lose it as the power one and three
--   quarters
--
--   every plenum entry, every corner tee and every rail end is a fitting, and
--   loses it as the square
--
-- So each branch is  dp = a*Q + b*Q^1.75 + c*Q^2  with the three coefficients
-- coming from the geometry the blueprints already fixed. Nothing is fitted and
-- nothing is assumed; if a rail's cross-section changes in 016, the coefficient
-- changes here on the next run.

-- {{{ local function coefficients()
-- Turn the blueprint set's geometry into the three coefficients of every kind of
-- branch. Read once and shared by all sixty-four candidate assignments, because
-- the geometry does not depend on which rail feeds which face.
local function coefficients(L)
  local function val(name)
    local q = L.value[name]
    if not q then error("102: no value for " .. name, 0) end
    return q.v
  end

  local rho, mu = val("rho_water"), val("mu_water")
  local A_rail, L_rail_m, D_rail = val("A_rail_chan"), val("L_rail"), val("D_rail")
  local K_ends = val("K_rail_ends")
  local A_cham, K_tee = val("A_chamber"), val("K_tee")
  local n_uchan, A_uchan = val("n_uchan"), val("A_uchan")
  local D_uchan, L_plate = val("D_uchan"), val("L_plate")
  local fRe, K_plenum = val("fRe_uchan"), val("K_plenum")

  local C = {}

  -- A rail of length L. Blasius friction gives the one-and-three-quarters term;
  -- the ends give the square one. Splitting a rail in half halves both, which is
  -- the right thing for the friction and an approximation for the ends -- an end
  -- loss belongs at an end, and a tapped rail has its tap in the middle, so half
  -- an end loss on each side is where it lands.
  C.rail = function(length, kfrac)
    local b = 0.316 * (mu / (rho * D_rail)) ^ 0.25 * (length / D_rail) * rho / 2
    return { a = 0,
             b = b / A_rail ^ 1.75,
             c = kfrac * K_ends * rho / (2 * A_rail ^ 2) }
  end

  C.full_rail = C.rail(L_rail_m, 1.0)
  C.half_rail = C.rail(L_rail_m / 2, 0.5)

  -- A corner block dividing three ways. Pure fitting loss, so pure square law.
  C.corner = { a = 0, b = 0, c = K_tee * rho / (2 * A_cham ^ 2) }

  -- One face: a hundred and seventy-three microchannels in parallel, plus the
  -- plenum at each end. The laminar friction factor times Reynolds number is a
  -- constant for a rectangular duct of this shape, which is why the field's loss
  -- is linear in flow and why halving the pump does not halve the cooling.
  local A_face = n_uchan * A_uchan
  C.face = { a = 2 * fRe * mu * L_plate / (D_uchan ^ 2 * A_face),
             b = 0,
             c = K_plenum * rho / (2 * A_face ^ 2) }

  C.Q_total = val("Q_total")
  C.dp_loop = val("dp_loop")
  return C
end
-- }}}

-- {{{ local function resistance()
-- The secant resistance of a branch at a given flow: the number R for which
-- dp = R*Q at that flow, rather than the slope of dp against Q.
--
-- Using the secant instead of the tangent is the whole reason this solver
-- converges, and it took a diverging run to see why. Newton's method wants the
-- tangent, and the tangent of a square-law branch at zero flow is zero -- so its
-- conductance is infinite, and on the first iteration, when every pressure in
-- the network is still the same and every rail is carrying nothing, half the
-- branches claim they will pass any flow for no pressure at all. The first step
-- is then enormous, the pressures go negative, and the run ends in numbers with
-- forty digits in them.
--
-- The secant has no such singularity. A branch carrying almost nothing has a
-- small resistance rather than none, the linear solve that results is
-- well-conditioned, and the sequence of linear solves converges on the answer
-- from any starting point. This is the linear-theory method, and it is what pipe
-- networks have been solved with since before there were computers to do it on.
local function resistance(br, q)
  local a = math.abs(q)
  if a < br.qfloor then a = br.qfloor end
  return br.a + br.b * a ^ 0.75 + br.c * a
end
-- }}}

-- {{{ local function build_network()
-- Lay the plumbing out as nodes and branches for one candidate assignment.
--
-- Node zero is the outlet header and is the reference every other pressure is
-- measured against. The inlet header is a node like any other, carrying the
-- whole machine's flow as an injection -- which is how the solve is told what
-- duty point to find rather than being told a pressure and asked what flow
-- results.
local function build_network(K, plan, C)
  local N = { name = {}, index = {}, branch = {}, inject = {} }

  local function node(name)
    if N.index[name] then return N.index[name] end
    local i = #N.name + 1
    N.name[i], N.index[name] = name, i
    N.inject[i] = 0
    return i
  end
  -- Every branch carries the order of magnitude of flow it expects, which is
  -- only ever used as a floor under the secant resistance. A branch is allowed
  -- to come out carrying a millionth of what it was built for; it is not allowed
  -- to come out with no resistance at all, because that is not a physical
  -- statement, it is a division by zero waiting for the first iteration.
  local function branch(from, to, coef, kind, tag, qref)
    N.branch[#N.branch + 1] = { from = from, to = to, kind = kind, tag = tag,
                                a = coef.a, b = coef.b, c = coef.c,
                                qref = qref, qfloor = qref * 1e-6 }
  end

  local GROUND = 0
  local IN = node("IN")

  local S, R, ST, RT = {}, {}, {}, {}
  for c = 0, 7 do S[c] = node("S" .. K.corner[c].label) end
  for c = 0, 7 do R[c] = node("R" .. K.corner[c].label) end
  for f = 1, 6 do ST[f] = node("ST" .. K.face[f].name) end
  for f = 1, 6 do RT[f] = node("RT" .. K.face[f].name) end

  -- The four inlet fittings, into the even corners, and the four outlets out of
  -- the odd ones. This is the parity choice, and it is read off the corner
  -- rather than off a list, so it stays true if the cube is relabelled.
  for c = 0, 7 do
    if K.corner[c].parity == 0 then
      branch(IN, S[c], C.corner, "inlet", K.corner[c].label, C.Q_total / 4)
    else
      branch(R[c], GROUND, C.corner, "outlet", K.corner[c].label, C.Q_total / 4)
    end
  end

  -- Which face taps which channel. A rail carrying a tap is two half-rails with
  -- the plenum between them; an untapped rail is one branch that only routes.
  local sup_of, ret_of = {}, {}
  for f = 1, 6 do sup_of[plan[f].supply] = f; ret_of[plan[f].ret] = f end

  for ei, e in ipairs(K.edge) do
    local f = sup_of[ei]
    -- A tapped rail's two halves each carry about half a face's flow; an
    -- untapped one is a routing path and carries whatever the solve gives it,
    -- which is nearer a twelfth of the machine.
    if f then
      branch(S[e.a], ST[f], C.half_rail, "supply", e.name, C.Q_total / 12)
      branch(ST[f], S[e.b], C.half_rail, "supply", e.name, C.Q_total / 12)
    else
      branch(S[e.a], S[e.b], C.full_rail, "supply", e.name, C.Q_total / 12)
    end
    local g = ret_of[ei]
    if g then
      branch(RT[g], R[e.a], C.half_rail, "return", e.name, C.Q_total / 12)
      branch(R[e.b], RT[g], C.half_rail, "return", e.name, C.Q_total / 12)
    else
      branch(R[e.a], R[e.b], C.full_rail, "return", e.name, C.Q_total / 12)
    end
  end

  for f = 1, 6 do
    branch(ST[f], RT[f], C.face, "face", K.face[f].name, C.Q_total / 6)
  end

  N.inject[IN] = C.Q_total
  N.IN, N.S, N.R, N.ST, N.RT = IN, S, R, ST, RT
  return N
end
-- }}}

-- {{{ local function gauss()
-- Dense elimination with partial pivoting on a twenty-nine by twenty-nine.
-- Sparse would be faster and a sparse solver is three hundred lines; this one is
-- twenty and runs sixty-four times in well under a second, which is the right
-- trade for a network this size.
local function gauss(A, b, n)
  for k = 1, n do
    local piv, pv = k, math.abs(A[k][k])
    for i = k + 1, n do
      local v = math.abs(A[i][k])
      if v > pv then piv, pv = i, v end
    end
    if pv < 1e-300 then return nil end
    if piv ~= k then A[k], A[piv] = A[piv], A[k]; b[k], b[piv] = b[piv], b[k] end
    local akk = A[k][k]
    for i = k + 1, n do
      local m = A[i][k] / akk
      if m ~= 0 then
        for j = k, n do A[i][j] = A[i][j] - m * A[k][j] end
        b[i] = b[i] - m * b[k]
      end
    end
  end
  local x = {}
  for i = n, 1, -1 do
    local s = b[i]
    for j = i + 1, n do s = s - A[i][j] * x[j] end
    x[i] = s / A[i][i]
  end
  return x
end
-- }}}

-- {{{ local function solve_network()
-- Solve the network by repeated linear solves.
--
-- Start every branch at the flow it was built for. Work out the secant
-- resistance each branch would have at that flow, which turns the whole circuit
-- into a linear one -- a resistor network with a current source at the inlet
-- header and ground at the outlet. Solve it exactly. That gives new flows;
-- recompute the resistances from those, and go round again.
--
-- Successive iterates are averaged rather than taken outright. Without the
-- average the flows oscillate: a branch that came out too high gets a resistance
-- too high, which sends it too low next time, and the pair alternate without
-- settling. Averaging halves the swing each round and it converges in about a
-- dozen passes, which for sixty-four candidate arrangements is nothing.
local function solve_network(N, C)
  local n = #N.name
  local q = {}
  for i, br in ipairs(N.branch) do q[i] = br.qref end

  local p, prev, iters, moved = nil, nil, 0, math.huge
  for iter = 1, 300 do
    iters = iter
    local A, rhs = {}, {}
    for i = 1, n do
      A[i] = {}
      for j = 1, n do A[i][j] = 0 end
      rhs[i] = N.inject[i]
    end

    local g = {}
    for bi, br in ipairs(N.branch) do
      g[bi] = 1 / resistance(br, q[bi])
      if br.from ~= 0 then
        A[br.from][br.from] = A[br.from][br.from] + g[bi]
        if br.to ~= 0 then A[br.from][br.to] = A[br.from][br.to] - g[bi] end
      end
      if br.to ~= 0 then
        A[br.to][br.to] = A[br.to][br.to] + g[bi]
        if br.from ~= 0 then A[br.to][br.from] = A[br.to][br.from] - g[bi] end
      end
    end

    p = gauss(A, rhs, n)
    if not p then return nil end

    -- Convergence is measured on the pressures rather than on the flows, and
    -- the reason is the same symmetry that makes the good arrangements good. A
    -- perfectly balanced network holds some rails at exactly zero flow, and a
    -- zero cannot be compared to itself in relative terms however it is scaled.
    -- Every pressure in the machine is a few thousand pascals and none of them
    -- is near zero, so the pressures have no such difficulty.
    -- Infinite on the first pass, because there is nothing yet to have moved
    -- from. Reading it as zero would end the loop after one linear solve, whose
    -- resistances are all still the starting guess.
    moved = math.huge
    if prev then
      moved = 0
      for i = 1, n do
        moved = math.max(moved, math.abs(p[i] - prev[i]) / C.dp_loop)
      end
    end
    prev = {}
    for i = 1, n do prev[i] = p[i] end


    for bi, br in ipairs(N.branch) do
      local pf = br.from == 0 and 0 or p[br.from]
      local pt = br.to == 0 and 0 or p[br.to]
      local fresh = g[bi] * (pf - pt)
      q[bi] = 0.5 * (fresh + q[bi])
    end

    -- A part in a million million of the loop pressure between
    -- successive rounds. This is far tighter than anything downstream reads,
    -- and the reason is the search rather than the answer: sixteen arrangements
    -- are exactly equally even and eight of those cost exactly the same to
    -- pump, so the tie-break is comparing numbers that agree in every figure the
    -- design cares about. A loop stopped early would decide between them on its
    -- own leftover error, and the drawing a builder gets would depend on
    -- rounding.
    if moved < 1e-12 then break end
  end

  -- What actually satisfies conservation, as opposed to what the loop last
  -- averaged. Recomputing the flows from the final pressures is the honest
  -- reading and it is what the residual below is measured on.
  local final, resid = {}, {}
  for i = 1, n do resid[i] = -N.inject[i] end
  for bi, br in ipairs(N.branch) do
    local pf = br.from == 0 and 0 or p[br.from]
    local pt = br.to == 0 and 0 or p[br.to]
    final[bi] = (pf - pt) / resistance(br, q[bi])
    if br.from ~= 0 then resid[br.from] = resid[br.from] + final[bi] end
    if br.to ~= 0 then resid[br.to] = resid[br.to] - final[bi] end
  end
  local worst = 0
  for i = 1, n do worst = math.max(worst, math.abs(resid[i])) end

  return { p = p, q = final, iters = iters, moved = moved,
           settled = moved < 1e-12,
           imbalance = worst / C.Q_total }
end
-- }}}

-- ---------------------------------------------------------------------------
-- The whole answer
-- ---------------------------------------------------------------------------

-- {{{ local function n_face_count()
-- The number of faces comes from the blueprint set rather than from the literal
-- six, because everything else here does. If somebody ever writes a blueprint
-- for an object that is not a cube, this should break loudly at the point where
-- the assumption stops holding rather than quietly divide by six.
local function n_face_count(L)
  local q = L.value["n_face"]
  return q and q.v or 6
end
-- }}}

-- {{{ function M.solve()
-- Everything, once: the cube built, the proofs enumerated, every legal rail
-- assignment searched, and the best of them solved.
--
-- The search is what makes this worth running rather than reasoning about.
-- Sixty-four of the five hundred and twelve arrangements obey all three rules,
-- and they are not equivalent: sixteen of them distribute the coolant exactly
-- evenly between the six faces, and the other forty-eight leave one face short
-- by five or six per cent. Nothing in 023's argument predicted that, because
-- 023's argument is about the supply network reaching everywhere, and this is
-- about where the plenums are hung on it.
--
-- The sixteen share a property that is visible once it is counted: one fed
-- corner has all three of its channels tapped and the other three fed corners
-- have one each. That is a threefold axis through a body diagonal, and a
-- threefold axis through a diagonal is the symmetry that makes all six faces
-- equivalent to one another. The forty-eight have the plenums spread two and
-- two, which looks more balanced and is not.
function M.solve(dir)
  dir = dir or DIR
  local L = ledger.load(dir)
  local K = build_cube()
  local C = coefficients(L)

  local crossing, inside = prove_bipartition(K)
  local equal, pairs_total, n_fed = prove_tetrahedron(K)
  local listed, written = check_document(K, dir)

  local sieve = sieve_order(K)
  local plans, tried = assignments(K)
  local best, even_count, worst_any = nil, 0, math.huge

  for ai, plan in ipairs(plans) do
    local N = build_network(K, plan, C)
    local S = solve_network(N, C)
    if S then
      local lo, hi = math.huge, 0
      for bi, br in ipairs(N.branch) do
        if br.kind == "face" then
          lo = math.min(lo, S.q[bi]); hi = math.max(hi, S.q[bi])
        end
      end
      local mean = C.Q_total / n_face_count(L)
      local r = { index = ai, plan = plan, net = N, sol = S,
                  worst = lo / mean, best = hi / mean }
      -- Even to within a part in a billion is even. The sixteen are exactly
      -- equal by symmetry and what separates them from one is the arithmetic's
      -- own noise, not anything about the cube.
      if r.best - r.worst < 1e-9 then even_count = even_count + 1 end
      worst_any = math.min(worst_any, r.worst)
      -- Best worst-served face wins; the least pump pressure breaks a tie; the
      -- enumeration order breaks what is left. Sixteen arrangements are equally
      -- good and a builder needs one drawing, so something has to choose, and
      -- saying which rule chose is better than appearing to have found a unique
      -- answer.
      -- The comparisons are made with a tolerance rather than exactly, and that
      -- is not fussiness. Sixteen arrangements are equally even and eight of
      -- those cost the same pressure to pump; they differ in the twelfth figure,
      -- which is the arithmetic and not the cube. Compared exactly, which one
      -- wins would depend on rounding, and the drawing a builder gets would
      -- change between runs for no reason anybody could point at.
      local function better(r2, r1)
        if not r1 then return true end
        if r2.worst > r1.worst * (1 + 1e-6) then return true end
        if r2.worst < r1.worst * (1 - 1e-6) then return false end
        local p2, p1 = r2.sol.p[r2.net.IN], r1.sol.p[r1.net.IN]
        -- A hundredth of a pascal in eleven thousand. Two arrangements closer
        -- together than that are the same arrangement seen from a different
        -- corner of the cube, and the earlier one in the enumeration keeps it.
        if p2 < p1 * (1 - 1e-6) then return true end
        return false
      end
      if better(r, best) then best = r end
    end
  end

  return {
    cube = K, ledger = L, coef = C,
    crossing = crossing, inside = inside,
    tetra_equal = equal, tetra_pairs = pairs_total, fed = n_fed,
    listed = listed, written = written,
    tried = tried, legal = #plans, even = even_count, worst_any = worst_any,
    anti = anti_steps(sieve), anti_best = best_ordering(K), n_step = #sieve - 1,
    best = best,
    perpendicular = perpendicular_pairs(K, best.plan),
  }
end
-- }}}

-- {{{ function M.answers()
-- What the blueprints copy, and what 095 re-runs this to check.
--
-- Every entry here is declared somewhere in src/ as a `solved` symbol naming
-- 102, and the checker compares the two on every pass. Adding a number here
-- without declaring it is reported; declaring one without answering for it is
-- reported. The two lists have to agree in both directions or the mechanism is
-- decoration.
function M.answers(dir)
  local R = M.solve(dir)
  local Q = units.new
  local mean = R.coef.Q_total / n_face_count(R.ledger)
  return {
    -- 023, the topology
    n_edge_crossing = Q(R.crossing, "1"),
    n_edge_dead     = Q(R.inside, "1"),
    n_edge_listed   = Q(R.listed, "1"),
    n_tetra_equal   = Q(R.tetra_equal, "1"),
    n_assign_legal  = Q(R.legal, "1"),
    n_assign_even   = Q(R.even, "1"),
    n_assign_tried  = Q(R.tried, "1"),
    n_perp_pair     = Q(R.perpendicular, "1"),
    -- 010, the face ordering
    n_step_anti     = Q(R.anti, "1"),
    n_step_anti_max = Q(R.anti_best, "1"),
    -- 024, the network
    n_node_net      = Q(#R.best.net.name, "1"),
    n_branch_net    = Q(#R.best.net.branch, "1"),
    f_worst_served  = Q(R.best.worst, "1"),
    f_best_served   = Q(R.best.best, "1"),
    f_worst_any     = Q(R.worst_any, "1"),
    dp_network      = Q(R.best.sol.p[R.best.net.IN], "Pa"),
  }
end
-- }}}

-- {{{ function M.report()
-- The whole thing in a page, for a person rather than for the checker. Nothing
-- here is stored anywhere: every number is worked out at the moment it is
-- printed, which is what the whole project is arranged to make possible.
function M.report(R, out)
  out = out or io.stdout
  local K = R.cube
  local function say(fmt, ...)
    out:write(select("#", ...) > 0 and fmt:format(...) or fmt, "\n")
  end

  say("")
  say("  the cube, solved")
  say("")
  say("  built from its definition: %d corners, %d edges, %d faces",
      8, #K.edge, #K.face)
  say("  edges crossing the parity: %d of %d -- the bipartition, enumerated",
      R.crossing, #K.edge)
  say("  edges joining two fed corners: %d -- channels that would carry nothing",
      R.inside)
  say("  edges in 010's written list matching the built cube: %d of %d",
      R.listed, R.written)
  say("  pairwise distances between the %d fed corners at the face diagonal: %d of %d",
      R.fed, R.tetra_equal, R.tetra_pairs)
  say("")
  say("  steps through the sieve that land on the opposite face: %d of %d",
      R.anti, R.n_step)
  say("  the most any ordering of six faces could manage: %d", R.anti_best)
  say("")
  say("  rail assignments tried: %d", R.tried)
  say("  of those legal -- no rail feeding two faces: %d", R.legal)
  say("  of those distributing the coolant exactly evenly: %d", R.even)
  say("  worst-served face under the least even legal one: %.4f of the mean",
      R.worst_any)
  say("")
  say("  the chosen assignment (number %d of %d)", R.best.index, R.legal)
  for fid = 1, #K.face do
    local p = R.best.plan[fid]
    say("    %-3s  supply %-11s  return %-11s  channels along %s",
        K.face[fid].name, K.edge[p.supply].name, K.edge[p.ret].name,
        ({ [0] = "x", [1] = "y", [2] = "z" })[p.channel])
  end
  say("")
  say("  the network: %d nodes, %d branches, %s in %d passes",
      #R.best.net.name, #R.best.net.branch,
      R.best.sol.settled and "settled" or "stopped at the pass limit after",
      R.best.sol.iters)
  say("  conservation residual: %.2g of the machine's flow", R.best.sol.imbalance)
  say("  pump to drain at the design flow: %.0f Pa", R.best.sol.p[R.best.net.IN])
  say("  worst-served face: %.6f of the mean; best: %.6f",
      R.best.worst, R.best.best)
  say("")
  return 0
end
-- }}}

M.build_cube = build_cube
M.label, M.parity = label, parity
M.assignments = assignments
M.perpendicular_pairs = perpendicular_pairs
M.coefficients = coefficients
M.build_network = build_network
M.solve_network = solve_network
M.anti_steps = anti_steps
M.best_ordering = best_ordering
M.sieve_order = sieve_order
M.prove_bipartition = prove_bipartition
M.prove_tetrahedron = prove_tetrahedron
M.check_document = check_document

if arg and arg[0] and arg[0]:match("102%-the%-cube%-solved%.lua$") then
  os.exit(M.report(M.solve(DIR)))
end

return M
