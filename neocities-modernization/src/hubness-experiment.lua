#!/usr/bin/env luajit
-- Experiment (Issue 9-013 hubness): measure how "central" an image's synthesized
-- pseudo-embedding is, as the blend between its two neighbours is swept 0->100%.
-- CENTRALITY = cosine to the corpus centroid (the mean of all embeddings, the
-- collection's centre of mass). Higher = more of a HUB (generically similar to
-- everything -> floods similar lists). We compare two ways to blend:
--   * SEAM (crooked): first f*D dims from the BEFORE poem, the rest from AFTER.
--   * WEIGHT (average): normalize( (1-f)*after + f*before ).
-- f = 0 -> pure AFTER poem (a real poem); f = 1 -> pure BEFORE poem. Both should
-- match the real-poem baseline at the ends; only the middle differs.
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path
local dk = require("dkjson")

io.write("loading embeddings... "); io.flush()
local f = io.open(DIR .. "/assets/embeddings/nomic-embed-text-v1.5/embeddings.json")
local E = dk.decode(f:read("*a")).embeddings; f:close()
local N, D = #E, #E[1].embedding
print(string.format("%d vectors, %d dims", N, D))

local function l2(v)
    local s = 0; for i = 1, #v do s = s + v[i] * v[i] end
    if s == 0 then return v end
    local inv = 1 / math.sqrt(s); local o = {}
    for i = 1, #v do o[i] = v[i] * inv end; return o
end
local function dot(a, b) local s = 0; for i = 1, #a do s = s + a[i] * b[i] end; return s end

-- corpus centroid (centre of mass)
local cen = {}; for i = 1, D do cen[i] = 0 end
for _, e in ipairs(E) do local v = e.embedding; for i = 1, D do cen[i] = cen[i] + v[i] end end
for i = 1, D do cen[i] = cen[i] / N end
cen = l2(cen)

-- a = BEFORE poem, b = AFTER poem
local function seam_blend(a, b, fr)
    local seam = math.floor(D * fr); local o = {}
    for i = 1, D do o[i] = (i <= seam) and a[i] or b[i] end
    return l2(o)
end
local function weight_blend(a, b, fr)
    local o = {}; for i = 1, D do o[i] = fr * a[i] + (1 - fr) * b[i] end
    return l2(o)
end

math.randomseed(12345)
local SAMPLES = 2000
-- baseline: mean centrality of a real poem
local base = 0
for s = 1, SAMPLES do base = base + dot(E[math.random(N)].embedding, cen) end
base = base / SAMPLES

local function sweep(blend)
    local rows = {}
    for step = 0, 10 do
        local fr = step / 10
        local sum = 0
        for s = 1, SAMPLES do
            local a = E[math.random(N)].embedding
            local b = E[math.random(N)].embedding
            sum = sum + dot(blend(a, b, fr), cen)
        end
        rows[step] = sum / SAMPLES
    end
    return rows
end
local crooked = sweep(seam_blend)
local weighted = sweep(weight_blend)

print(string.format("\nbaseline (real poem) centrality = %.4f\n", base))
print("  blend     CROOKED (dim seam)        WEIGHTED (average)")
print("  before%   centrality   vs base      centrality   vs base")
print("  -------   ----------   --------      ----------   --------")
for step = 0, 10 do
    print(string.format("  %4d%%     %.4f      %+5.1f%%        %.4f      %+5.1f%%",
        step * 10,
        crooked[step], (crooked[step] - base) / base * 100,
        weighted[step], (weighted[step] - base) / base * 100))
end
print("\n(before% = how much of the blend comes from the BEFORE poem)")
