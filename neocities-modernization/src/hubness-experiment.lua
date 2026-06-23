#!/usr/bin/env luajit
-- Image-embedding measurement tool (Issue 9-013). Turn the seam knob and watch
-- three different things move at once, for an image synthesized between two
-- chronological neighbours (a = BEFORE poem, b = AFTER poem):
--
--   1. CENTRALITY  -- cosine to the corpus centroid (the centre of mass). High =
--      a HUB that floods similar lists. Compares the dimensional cross-cut
--      against a weighted average across the whole 0..100% blend.
--   2. STRUCTURE/TEXTURE -- cosine of the cross-cut to the BEFORE poem (its
--      "structure", the front dims) and the AFTER poem (its "texture", the back
--      dims). Shows how the structure-vs-texture balance tracks the seam.
--   3. NEIGHBOURHOOD -- Jaccard overlap of the cross-cut image's top-K similar
--      set with the BEFORE poem's top-K vs the AFTER poem's top-K. The
--      user-facing question: whose *similar page* does the image land in? Top-K
--      is a cliff, so this can flip more sharply than the smooth cosine.
--
-- Prefer running this over trusting a number written in a doc. Knobs below.
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path
local dk = require("dkjson")
local utils = require("utils")  -- Issue 10-054: read embeddings from wherever they live (RAM or disk)

-- {{{ knobs
local PAIR_SAMPLES   = 2000   -- random neighbour pairs for the cheap sweeps (1,2)
local NBR_PAIRS      = 30     -- pairs for the expensive neighbourhood sweep (3)
local CORPUS         = 1500   -- corpus sample the top-K rankings are drawn from
local TOPK           = 20     -- "similar page" size
local SEED           = 12345
-- }}}

io.write("loading embeddings... "); io.flush()
local E = dk.decode(io.open(utils.embeddings_dir() .. "/embeddings.json"):read("*a")).embeddings
local N, D = #E, #E[1].embedding
print(string.format("%d vectors, %d dims", N, D))

-- {{{ vector helpers
local function l2(v)
    local s = 0; for i = 1, #v do s = s + v[i] * v[i] end
    if s == 0 then return v end
    local inv = 1 / math.sqrt(s); local o = {}
    for i = 1, #v do o[i] = v[i] * inv end; return o
end
local function dot(a, b) local s = 0; for i = 1, #a do s = s + a[i] * b[i] end; return s end
local function seam_blend(a, b, fr)     -- dimensional cross-cut
    local seam = math.floor(D * fr); local o = {}
    for i = 1, D do o[i] = (i <= seam) and a[i] or b[i] end; return l2(o)
end
local function weight_blend(a, b, fr)   -- weighted average
    local o = {}; for i = 1, D do o[i] = fr * a[i] + (1 - fr) * b[i] end; return l2(o)
end
-- }}}

-- corpus centroid + a fixed corpus sample for rankings
local cen = {}; for i = 1, D do cen[i] = 0 end
for _, e in ipairs(E) do local v = e.embedding; for i = 1, D do cen[i] = cen[i] + v[i] end end
for i = 1, D do cen[i] = cen[i] / N end
cen = l2(cen)
math.randomseed(SEED)
local corpus = {}
for i = 1, CORPUS do corpus[i] = E[math.random(N)].embedding end

-- {{{ topk_set(q) -> set of corpus indices most similar to q
local function topk_set(q)
    local scored = {}
    for i = 1, CORPUS do scored[i] = { i, dot(q, corpus[i]) } end
    table.sort(scored, function(x, y) return x[2] > y[2] end)
    local set = {}
    for r = 1, TOPK do set[scored[r][1]] = true end
    return set
end
local function jaccard(x, y)
    local inter, uni = 0, 0
    local seen = {}
    for k in pairs(x) do uni = uni + 1; seen[k] = true; if y[k] then inter = inter + 1 end end
    for k in pairs(y) do if not seen[k] then uni = uni + 1 end end
    return uni > 0 and inter / uni or 0
end
-- }}}

print("\n========================================================================")
print("  1. CENTRALITY  (cosine to corpus centroid; higher = more of a hub)")
print("========================================================================")
do
    math.randomseed(SEED)
    local base = 0
    for s = 1, PAIR_SAMPLES do base = base + dot(E[math.random(N)].embedding, cen) end
    base = base / PAIR_SAMPLES
    print(string.format("  baseline (real poem) = %.4f\n", base))
    print("  before%   crooked   vs base      weighted   vs base")
    for step = 0, 10 do
        local fr = step / 10
        local sc, sw = 0, 0
        for s = 1, PAIR_SAMPLES do
            local a, b = E[math.random(N)].embedding, E[math.random(N)].embedding
            sc = sc + dot(seam_blend(a, b, fr), cen)
            sw = sw + dot(weight_blend(a, b, fr), cen)
        end
        sc, sw = sc / PAIR_SAMPLES, sw / PAIR_SAMPLES
        print(string.format("  %4d%%     %.4f   %+5.1f%%      %.4f   %+5.1f%%",
            step * 10, sc, (sc - base) / base * 100, sw, (sw - base) / base * 100))
    end
end

print("\n========================================================================")
print("  2. STRUCTURE / TEXTURE  (cross-cut's cosine to BEFORE vs AFTER poem)")
print("========================================================================")
print("  before%   cos->BEFORE   cos->AFTER   (they cross where structure=texture)")
do
    math.randomseed(SEED)
    for step = 0, 10 do
        local fr = step / 10
        local cb, ca = 0, 0
        for s = 1, PAIR_SAMPLES do
            local a, b = E[math.random(N)].embedding, E[math.random(N)].embedding
            local img = seam_blend(a, b, fr)
            cb = cb + dot(img, a); ca = ca + dot(img, b)
        end
        print(string.format("  %4d%%     %.3f         %.3f", step * 10, cb / PAIR_SAMPLES, ca / PAIR_SAMPLES))
    end
end

print("\n========================================================================")
print(string.format("  3. NEIGHBOURHOOD  (top-%d similar-set Jaccard overlap; %d pairs)", TOPK, NBR_PAIRS))
print("========================================================================")
print("  before%   J(img, BEFORE-page)   J(img, AFTER-page)")
do
    math.randomseed(SEED + 1)
    -- Precompute each pair's BEFORE/AFTER neighbour sets once, reuse per seam.
    local pairs_data = {}
    for p = 1, NBR_PAIRS do
        local a, b = E[math.random(N)].embedding, E[math.random(N)].embedding
        pairs_data[p] = { a = a, b = b, aset = topk_set(a), bset = topk_set(b) }
    end
    for step = 0, 10 do
        local fr = step / 10
        local jb, ja = 0, 0
        for p = 1, NBR_PAIRS do
            local pd = pairs_data[p]
            local imgset = topk_set(seam_blend(pd.a, pd.b, fr))
            jb = jb + jaccard(imgset, pd.aset)
            ja = ja + jaccard(imgset, pd.bset)
        end
        print(string.format("  %4d%%     %.3f                 %.3f", step * 10, jb / NBR_PAIRS, ja / NBR_PAIRS))
    end
end

print("\n========================================================================")
print(string.format("  4. FREQUENCY  (k-occurrence: times each item lands in others' top-%d)", TOPK))
print("========================================================================")
print("  the real question: do images show up MORE than poems? (goal: no). This")
print("  builds a corpus of real poems + injected images and counts appearances.")
do
    math.randomseed(SEED + 2)
    local KP, KI = 600, 90   -- poems + images in the test corpus (kept small: O(n^2))
    local base_poems, pair_list = {}, {}
    for i = 1, KP do base_poems[i] = E[math.random(N)].embedding end
    for i = 1, KI do pair_list[i] = { E[math.random(N)].embedding, E[math.random(N)].embedding } end
    local function kocc(mkimg)
        local items = {}
        for i = 1, KP do items[i] = { v = base_poems[i], img = false } end
        for i = 1, KI do items[KP + i] = { v = mkimg(pair_list[i][1], pair_list[i][2]), img = true } end
        local M = #items
        local occ = {}; for i = 1, M do occ[i] = 0 end
        for q = 1, M do
            local sc = {}
            for j = 1, M do if j ~= q then sc[#sc + 1] = { j, dot(items[q].v, items[j].v) } end end
            table.sort(sc, function(x, y) return x[2] > y[2] end)
            for r = 1, TOPK do occ[sc[r][1]] = occ[sc[r][1]] + 1 end
        end
        local sp, np, si, ni = 0, 0, 0, 0
        for i = 1, M do if items[i].img then si = si + occ[i]; ni = ni + 1 else sp = sp + occ[i]; np = np + 1 end end
        return sp / np, si / ni
    end
    local avg_fn = function(a, b) local o = {}; for i = 1, D do o[i] = (a[i] + b[i]) * 0.5 end; return l2(o) end
    print("  method               poems   images   images vs poems")
    local pp, im = kocc(avg_fn)
    print(string.format("  midpoint average     %5.1f   %5.2f   %+5.0f%%  (the old flooding)", pp, im, (im / pp - 1) * 100))
    local pc, ic = kocc(function(a, b) return seam_blend(a, b, 0.5) end)
    print(string.format("  crooked 50%% (live)   %5.1f   %5.2f   %+5.0f%%  (current setting)", pc, ic, (ic / pc - 1) * 100))
end
print("")
