#!/usr/bin/env luajit
-- Temporary experiment (Issue: image-hubness). Measures whether each way of
-- synthesizing an image's pseudo-embedding makes it a HUB (a vector that is
-- on-average more similar to the whole corpus, which floods "similar" lists).
-- Proxy: cosine to the corpus centroid -- the higher, the more central/hubby.
-- Lower (closer to the real-poem baseline) is better. Marked -done; remove after
-- one commit (per the temp-script convention).
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path
local dk = require("dkjson")

-- {{{ load
io.write("loading embeddings... "); io.flush()
local f = io.open(DIR .. "/assets/embeddings/nomic-embed-text-v1.5/embeddings.json")
local data = dk.decode(f:read("*a")); f:close()
local E = data.embeddings
local N, D = #E, #E[1].embedding
print(string.format("%d vectors, %d dims", N, D))
-- }}}

-- {{{ vector helpers
local function l2(v)
    local s = 0; for i = 1, #v do s = s + v[i] * v[i] end
    if s == 0 then return v end
    local inv = 1 / math.sqrt(s); local o = {}
    for i = 1, #v do o[i] = v[i] * inv end
    return o
end
local function dot(a, b) local s = 0; for i = 1, #a do s = s + a[i] * b[i] end; return s end
-- }}}

-- {{{ corpus centroid (the "ultimate hub" direction)
local cen = {}; for i = 1, D do cen[i] = 0 end
for _, e in ipairs(E) do local v = e.embedding; for i = 1, D do cen[i] = cen[i] + v[i] end end
for i = 1, D do cen[i] = cen[i] / N end
cen = l2(cen)
-- }}}

-- {{{ variant builders (a = "before" poem, b = "after" poem), all normalized
local HALF = math.floor(D / 2)              -- 384
local SEAM40 = math.floor(D * 0.4)          -- 307: 40% from a, 60% from b
local function midpoint(a, b) local o = {}; for i = 1, D do o[i] = a[i] + b[i] end; return l2(o) end
local function weighted(a, b, wa) local o = {}; for i = 1, D do o[i] = wa * a[i] + (1 - wa) * b[i] end; return l2(o) end
local function crooked(a, b, seam) local o = {}; for i = 1, D do o[i] = (i <= seam) and a[i] or b[i] end; return l2(o) end
-- }}}

-- {{{ run: sample pairs, measure cosine-to-centroid per method
math.randomseed(12345)
local methods = {
    { name = "real poem (baseline)", fn = function(a, b) return a end },
    { name = "single neighbour    ", fn = function(a, b) return a end },
    { name = "MIDPOINT (current)   ", fn = function(a, b) return midpoint(a, b) end },
    { name = "weighted 0.4/0.6     ", fn = function(a, b) return weighted(a, b, 0.4) end },
    { name = "crooked 50/50        ", fn = function(a, b) return crooked(a, b, HALF) end },
    { name = "crooked 40/60        ", fn = function(a, b) return crooked(a, b, SEAM40) end },
}
local SAMPLES = 1500
local sums, sumsq = {}, {}
for m = 1, #methods do sums[m] = 0; sumsq[m] = 0 end
for s = 1, SAMPLES do
    local a = E[math.random(N)].embedding
    local b = E[math.random(N)].embedding
    for m = 1, #methods do
        local v = methods[m].fn(a, b)
        local c = dot(v, cen)
        sums[m] = sums[m] + c; sumsq[m] = sumsq[m] + c * c
    end
end

print(string.format("\ncosine-to-centroid over %d random neighbour-pairs (higher = more hubby):\n", SAMPLES))
local base = sums[1] / SAMPLES
for m = 1, #methods do
    local mean = sums[m] / SAMPLES
    local sd = math.sqrt(math.max(0, sumsq[m] / SAMPLES - mean * mean))
    print(string.format("  %s  mean=%.4f  sd=%.4f  vs baseline %+.1f%%",
        methods[m].name, mean, sd, (mean - base) / base * 100))
end
-- }}}
