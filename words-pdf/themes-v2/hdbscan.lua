-- themes-v2/hdbscan.lua
-- Issue 029, slice 2: HDBSCAN clustering of the poem embeddings.
--
-- Reads tmp/poem-embeddings.bin (packed float32 from slice 1), runs
-- HDBSCAN, writes:
--   - tmp/clusters.lua    : cluster IDs, member poem ids, stability scores
--   - tmp/cluster-centroids.bin : packed float32 centroids per cluster
--
-- Algorithm phases (McInnes 2017, "hdbscan: Hierarchical density based
-- clustering"):
--
--   1. Cosine distance matrix  D[i][j] = 1 - dot(v_i, v_j)
--      (nomic vectors are unit-normalized, so dot product == cosine sim)
--   2. Core distance            core[i] = D[i][k-th nearest neighbor]
--                                         where k = MIN_SAMPLES
--   3. Mutual reachability      MR[i][j] = max(D[i][j], core[i], core[j])
--   4. Single-linkage tree from MR via Prim's MST + agglomerative
--      union-find. Each MST edge becomes a "merge event" at scale = edge
--      weight; merges are processed in ascending order.
--   5. Condensation             Walk the dendrogram. A merge that creates
--      a cluster where both children have >= MIN_CLUSTER_SIZE points is
--      a "real split". Otherwise the smaller child's points become noise
--      that "fall out" of the larger child as we move up the tree.
--   6. Stability extraction     For each condensed cluster C with birth
--      lambda L_birth, stability(C) = sum over points p in C of
--      (lambda_p_falls_out - L_birth). Pick the subset of clusters that
--      maximizes total stability such that no two are ancestor-and-
--      descendant. Top-down greedy: pick C if its stability > sum of
--      child stabilities; otherwise recurse into children.
--
-- Two FFI buffers carry the heavy data: embeddings (n*768 floats) and
-- mutual-reachability matrix (n*n floats, upper triangular indexing).
-- For n=7800, that's ~24 MB embeddings + ~122 MB MR matrix. Both fit
-- comfortably in modern RAM and avoid Lua's table overhead.
--
-- Run with:
--   luajit themes-v2/hdbscan.lua [DIR]
-- Or for synthetic-data correctness test:
--   luajit themes-v2/hdbscan.lua --test

local DIR = "/home/ritz/programming/ai-stuff/words-pdf"
local TEST_MODE = false
for _, a in ipairs(arg) do
    if a == "--test" then TEST_MODE = true
    elseif a:sub(1, 1) ~= "-" then DIR = a end
end

local INPUT_BIN    = DIR .. "/tmp/shared-memory/poem-embeddings.bin"
local OUTPUT_LUA   = DIR .. "/tmp/shared-memory/clusters.lua"
local OUTPUT_BIN   = DIR .. "/tmp/shared-memory/cluster-centroids.bin"

-- HDBSCAN tunables. MIN_SAMPLES sets the k-NN neighborhood that drives
-- core-distance estimation; small values make the algorithm sensitive
-- to noise, large values smooth over real cluster structure.
-- MIN_CLUSTER_SIZE is the threshold below which a candidate cluster is
-- treated as noise. Lowered from the original 5/30 to 3/10 — the 5/30
-- defaults left ~90% of nomic-embedded poems as noise because cosine
-- distances in 768-dim are tightly packed; smaller thresholds expose
-- the actual density structure. Combined with the post-hoc noise
-- reassignment below (assign each noise point to its nearest cluster
-- centroid), we get ~40-80 HDBSCAN-discovered clusters AND 100% poem
-- coverage in the output.
local MIN_SAMPLES      = 3
local MIN_CLUSTER_SIZE = 10

local ffi = require("ffi")
local bit = require("bit")

-- {{{ local function read_uint32_le
local function read_uint32_le(f)
    local b = f:read(4)
    if not b or #b < 4 then return nil end
    return b:byte(1)
        + b:byte(2) * 256
        + b:byte(3) * 65536
        + b:byte(4) * 16777216
end
-- }}}

-- {{{ local function write_uint32_le
local function write_uint32_le(f, n)
    f:write(string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256))
end
-- }}}

-- {{{ local function load_embeddings_bin
-- Reads the packed binary written by load-poem-embeddings.lua. Returns
-- (n, dim, FFI float[n*dim] buffer). Row-major: poem i's d-th dim is at
-- buffer[i * dim + d].
local function load_embeddings_bin(path)
    local f = io.open(path, "rb")
    if not f then
        error("Cannot read " .. path .. " — did you run load-poem-embeddings.lua first?")
    end
    local n = read_uint32_le(f)
    local dim = read_uint32_le(f)
    if not n or not dim then
        error("Truncated header in " .. path)
    end
    local total_floats = n * dim
    local buf = ffi.new("float[?]", total_floats)
    local raw = f:read(total_floats * 4)
    f:close()
    if #raw ~= total_floats * 4 then
        error(string.format("Truncated payload in %s: expected %d bytes, got %d",
            path, total_floats * 4, #raw))
    end
    ffi.copy(buf, raw, total_floats * 4)
    return n, dim, buf
end
-- }}}

-- {{{ local function cosine_distance
-- Cosine distance between row i and row j of the embedding buffer.
-- Vectors are unit-normalized per nomic, so cosine sim == dot product,
-- and distance = 1 - sim. Clamped to [0, 2] for floating-point safety.
local function cosine_distance(emb_buf, i, j, dim)
    local base_i = i * dim
    local base_j = j * dim
    local dot = 0.0
    for d = 0, dim - 1 do
        dot = dot + emb_buf[base_i + d] * emb_buf[base_j + d]
    end
    local d = 1.0 - dot
    if d < 0 then d = 0 end
    if d > 2 then d = 2 end
    return d
end
-- }}}

-- {{{ local function compute_distance_matrix
-- Dense n×n matrix of cosine distances. Symmetric, zero on the diagonal.
-- Stored as a single FFI float[n*n] buffer (row-major) for cache locality
-- in the MST inner loop. Memory: n*n*4 bytes (~122 MB for n=7800).
--
-- Optimized inner loop: only compute the upper triangle, mirror to lower.
-- For each i, walk j > i once.
local function compute_distance_matrix(emb_buf, n, dim)
    local dist = ffi.new("float[?]", n * n)
    local start = os.time()
    local last_report = start
    for i = 0, n - 1 do
        dist[i * n + i] = 0
        local base_i = i * dim
        for j = i + 1, n - 1 do
            local base_j = j * dim
            local dot = 0.0
            for d = 0, dim - 1 do
                dot = dot + emb_buf[base_i + d] * emb_buf[base_j + d]
            end
            local cd = 1.0 - dot
            if cd < 0 then cd = 0 end
            if cd > 2 then cd = 2 end
            dist[i * n + j] = cd
            dist[j * n + i] = cd
        end
        if os.time() - last_report >= 5 then
            last_report = os.time()
            io.write(string.format(
                "\r    distance matrix: row %d/%d (%.0f%%) — %ds elapsed",
                i + 1, n, (i + 1) / n * 100, os.time() - start))
            io.flush()
        end
    end
    io.write(string.format("\r    distance matrix: %d×%d done in %ds                  \n",
        n, n, os.time() - start))
    return dist
end
-- }}}

-- {{{ local function compute_core_distances
-- For each point i, find the distance to its k-th nearest neighbor
-- (excluding itself), where k = MIN_SAMPLES. Implemented as a partial
-- sort: walk row i once, maintain a max-heap of size k of the smallest
-- distances seen so far. The top of the heap at the end is the k-th
-- smallest distance.
--
-- A min-heap implementation in Lua tables is slower than a manual array
-- with insertion sort for small k (k=5 here), so we use the simpler form.
local function compute_core_distances(dist, n, k)
    local core = ffi.new("float[?]", n)
    -- Reused k+1 buffer for the k smallest, kept sorted ascending.
    -- We track up to k+1 entries; the (k+1)th gets discarded on push if
    -- the new distance doesn't beat it.
    local top = ffi.new("float[?]", k + 1)
    for i = 0, n - 1 do
        local count = 0
        for j = 0, n - 1 do
            if j ~= i then
                local d = dist[i * n + j]
                if count < k then
                    -- Insertion sort into the sorted top array.
                    local pos = count
                    while pos > 0 and top[pos - 1] > d do
                        top[pos] = top[pos - 1]
                        pos = pos - 1
                    end
                    top[pos] = d
                    count = count + 1
                elseif d < top[k - 1] then
                    -- Push out the current worst, insertion-sort the new value.
                    local pos = k - 1
                    while pos > 0 and top[pos - 1] > d do
                        top[pos] = top[pos - 1]
                        pos = pos - 1
                    end
                    top[pos] = d
                end
            end
        end
        core[i] = top[k - 1]  -- the k-th nearest neighbor (1-indexed) is the k-1 slot
    end
    return core
end
-- }}}

-- {{{ local function mutate_to_mutual_reachability
-- Transforms dist[] in place: MR[i][j] = max(dist[i][j], core[i], core[j]).
-- Saves a 122 MB allocation by reusing the distance buffer.
local function mutate_to_mutual_reachability(dist, core, n)
    for i = 0, n - 1 do
        local ci = core[i]
        for j = i + 1, n - 1 do
            local d = dist[i * n + j]
            local cj = core[j]
            if ci > d then d = ci end
            if cj > d then d = cj end
            dist[i * n + j] = d
            dist[j * n + i] = d
        end
    end
end
-- }}}

-- {{{ local function prim_mst
-- Prim's MST on the dense mutual-reachability matrix. O(n^2) total,
-- which is essentially free compared to the n^2*dim distance pass.
-- Returns a table of edges: {{from, to, weight}, ...}, ordered by
-- insertion (which is sorted by min_edge magnitude in the discovered
-- order; we re-sort below by weight ascending for the agglomerative pass).
local function prim_mst(mr, n)
    local visited = ffi.new("bool[?]", n)
    local min_edge = ffi.new("float[?]", n)
    local parent = ffi.new("int32_t[?]", n)
    for i = 0, n - 1 do
        min_edge[i] = math.huge
        parent[i] = -1
    end
    min_edge[0] = 0
    visited[0] = true
    -- Seed: from node 0, set distances to all other nodes.
    for j = 1, n - 1 do
        min_edge[j] = mr[0 * n + j]
        parent[j] = 0
    end

    local edges = {}
    for iter = 1, n - 1 do
        -- Find unvisited node with smallest min_edge.
        local best_d = math.huge
        local best_j = -1
        for j = 0, n - 1 do
            if not visited[j] and min_edge[j] < best_d then
                best_d = min_edge[j]
                best_j = j
            end
        end
        if best_j == -1 then break end
        visited[best_j] = true
        table.insert(edges, {parent[best_j], best_j, best_d})
        -- Update min_edge for remaining unvisited nodes.
        local row = best_j * n
        for j = 0, n - 1 do
            if not visited[j] then
                local w = mr[row + j]
                if w < min_edge[j] then
                    min_edge[j] = w
                    parent[j] = best_j
                end
            end
        end
    end

    -- Sort edges by weight ascending — the agglomerative order.
    table.sort(edges, function(a, b) return a[3] < b[3] end)
    return edges
end
-- }}}

-- {{{ local function build_dendrogram
-- Agglomerative single-linkage from sorted MST edges using union-find.
-- Each MST edge merges two clusters; the merged cluster gets a fresh
-- cluster ID >= n (point IDs are 0..n-1). For each merged cluster we
-- record:
--   left_id, right_id  : the two clusters that merged
--   scale              : the edge weight (cluster's "birth distance")
--   size               : how many points it contains
--
-- Returns:
--   merges[i] = {id, left_id, right_id, scale, size}  for i in 1..n-1
--   parent_of[point/cluster id] = parent merged-cluster id
--   The root cluster id = n + n - 2 (last merge index 0-based: n-2, plus base n)
local function build_dendrogram(edges, n)
    local find_parent = {}      -- union-find parent map; per cluster ID
    local rank = {}             -- union-find rank for path compression
    local cluster_size = {}     -- size of cluster currently identified by id
    local cluster_for = {}      -- current top-level cluster id holding this point/sub
    for i = 0, n - 1 do
        find_parent[i] = i
        rank[i] = 0
        cluster_size[i] = 1
        cluster_for[i] = i
    end

    -- Standard union-find with path compression.
    local function find(x)
        local root = x
        while find_parent[root] ~= root do
            root = find_parent[root]
        end
        local node = x
        while find_parent[node] ~= root do
            local nxt = find_parent[node]
            find_parent[node] = root
            node = nxt
        end
        return root
    end

    local merges = {}
    local next_id = n
    for _, edge in ipairs(edges) do
        local from, to, w = edge[1], edge[2], edge[3]
        local left_root = find(from)
        local right_root = find(to)
        if left_root ~= right_root then
            local left_cluster = cluster_for[left_root]
            local right_cluster = cluster_for[right_root]
            local left_size = cluster_size[left_cluster]
            local right_size = cluster_size[right_cluster]
            local new_id = next_id
            next_id = next_id + 1
            cluster_size[new_id] = left_size + right_size
            -- Union: keep one root, point the other at it. Doesn't matter
            -- which for correctness; rank heuristic for shallow tree.
            if rank[left_root] < rank[right_root] then
                find_parent[left_root] = right_root
                cluster_for[right_root] = new_id
            elseif rank[left_root] > rank[right_root] then
                find_parent[right_root] = left_root
                cluster_for[left_root] = new_id
            else
                find_parent[right_root] = left_root
                rank[left_root] = rank[left_root] + 1
                cluster_for[left_root] = new_id
            end
            table.insert(merges, {
                id = new_id,
                left_id = left_cluster,
                right_id = right_cluster,
                scale = w,
                size = left_size + right_size,
            })
        end
    end
    return merges
end
-- }}}

-- {{{ local function collect_points_under
-- Iteratively walks the dendrogram subtree rooted at cluster id `root`
-- and collects every point id (0..n-1) it contains. Iterative because
-- the dendrogram for n=7800 can have depth ≥ 7800 in the chain-like
-- worst case, which blows the LuaJIT call stack (~200 levels) with the
-- previously recursive version.
local function collect_points_under(root, merges_by_id, n, out)
    out = out or {}
    local stack = {root}
    while #stack > 0 do
        local node = stack[#stack]
        stack[#stack] = nil
        if node < n then
            table.insert(out, node)
        else
            local m = merges_by_id[node]
            if m then
                stack[#stack + 1] = m.left_id
                stack[#stack + 1] = m.right_id
            end
        end
    end
    return out
end
-- }}}

-- {{{ local function condense_and_extract
-- Walks the dendrogram top-down, condensing false splits (where one
-- child is below MIN_CLUSTER_SIZE) into "points fall out as noise" of
-- the parent. Tracks stability per condensed cluster, then top-down
-- greedy selection picks the highest-stability flat partition.
--
-- Implementation:
--   * The root is "always a cluster" (the entire dataset).
--   * For each merge processed top-down (descending size, since merges
--     ascend in scale), at the split point: if both children are large
--     enough, both become condensed clusters with birth_lambda = 1/scale.
--     Otherwise the small child's points "fall out" of the parent at
--     lambda = 1/scale.
--   * Stability of cluster C = sum over points p in C of
--     (lambda_p_falls_out - birth_lambda_C).
--
-- Returns the selected clusters as:
--   {{point_ids = {...}, stability = X, birth_lambda = Y}, ...}
local function condense_and_extract(merges, n, min_cluster_size)
    -- Build a lookup from cluster id to its merge record.
    local merges_by_id = {}
    for _, m in ipairs(merges) do merges_by_id[m.id] = m end

    if #merges == 0 then
        return {}, {}  -- pathological case: nothing to cluster
    end

    -- The root is the last merge (largest id).
    local root_merge = merges[#merges]

    -- Subtree-size helper. Pre-compute once for all dendrogram nodes so
    -- we don't recurse on every check.
    local subtree_size = {}
    for i = 0, n - 1 do subtree_size[i] = 1 end
    for _, m in ipairs(merges) do
        subtree_size[m.id] = (subtree_size[m.left_id] or 1) + (subtree_size[m.right_id] or 1)
    end

    -- Walk top-down (descending size). For each node, decide whether
    -- this is a real split or a false split. False splits eject the
    -- smaller side as noise; real splits create two condensed clusters.
    --
    -- We accumulate condensed clusters keyed by an arbitrary index.
    -- Each entry tracks:
    --   * point ids (collected on demand)
    --   * birth_lambda (1 / scale when the cluster was born)
    --   * fall_out_lambda per point (lambda at which the point left
    --     this cluster — either it joined a child cluster at a real
    --     split, or it became noise at a false split, or it lived to
    --     the leaf, in which case fall_out = math.huge)
    --   * children indices (for the selection walk)
    --
    -- For computational simplicity, we represent the condensed tree
    -- as a recursive walk that emits cluster records.

    local condensed = {}  -- list of cluster records

    -- {{{ iterative condensation
    -- Two nested loops replace the recursive process() / walk() pair
    -- from the original design (which blew Lua's call stack on the
    -- ~7800-deep chain-like dendrograms that come out of single linkage
    -- on real embedding data):
    --
    --   * Outer "job queue" creates a new condensed cluster per job.
    --     A job is born when a real split is hit while walking some
    --     ancestor cluster; each child of the split is queued as its
    --     own new condensed cluster with the split's lambda as birth.
    --   * Inner "walk stack" descends the dendrogram nodes that belong
    --     to the current condensed cluster. Real splits enqueue jobs;
    --     false splits eject noise points and continue down the
    --     surviving side; both-small splits dump the rest of the
    --     subtree as noise.
    --
    -- Sizes (`subtree_size`) are precomputed, so we don't have to walk
    -- the subtree just to know its size — we only walk it when we
    -- actually need the point ids (noise ejection / both-small cases).
    local job_queue = {{node_id = root_merge.id, birth_lambda = 0, parent_idx = nil}}
    while #job_queue > 0 do
        local job = table.remove(job_queue, 1)  -- FIFO so the tree builds top-down
        local cluster_idx = #condensed + 1
        local record = {
            birth_lambda = job.birth_lambda,
            point_ids = {},
            child_indices = {},
            stability = 0,
        }
        condensed[cluster_idx] = record
        if job.parent_idx then
            table.insert(condensed[job.parent_idx].child_indices, cluster_idx)
        end

        local stack = {job.node_id}
        while #stack > 0 do
            local dnode = stack[#stack]
            stack[#stack] = nil
            if dnode < n then
                -- Leaf point: stays in this cluster (no further fall-out).
                table.insert(record.point_ids, dnode)
            else
                local m = merges_by_id[dnode]
                if m then
                    local left_size = subtree_size[m.left_id]
                    local right_size = subtree_size[m.right_id]
                    local split_lambda = (m.scale > 0) and (1.0 / m.scale) or math.huge
                    local left_big = left_size >= min_cluster_size
                    local right_big = right_size >= min_cluster_size

                    if left_big and right_big then
                        -- Real split: both sides become new condensed
                        -- clusters. All (left+right) points "fall out
                        -- of" the current cluster at split_lambda;
                        -- credit the stability contribution and queue
                        -- the children as separate jobs.
                        local contrib = split_lambda - record.birth_lambda
                        if contrib < 0 then contrib = 0 end
                        record.stability = record.stability + contrib * (left_size + right_size)
                        table.insert(job_queue, {
                            node_id = m.left_id,
                            birth_lambda = split_lambda,
                            parent_idx = cluster_idx,
                        })
                        table.insert(job_queue, {
                            node_id = m.right_id,
                            birth_lambda = split_lambda,
                            parent_idx = cluster_idx,
                        })
                    elseif left_big or right_big then
                        -- False split: smaller side ejects as noise of
                        -- the current cluster; surviving side keeps
                        -- being walked. Pre-known size lets us credit
                        -- the stability without walking the noise
                        -- subtree just to count it.
                        local stay_id   = left_big and m.left_id  or m.right_id
                        local noise_id  = left_big and m.right_id or m.left_id
                        local noise_size = left_big and right_size or left_size
                        local contrib = split_lambda - record.birth_lambda
                        if contrib < 0 then contrib = 0 end
                        record.stability = record.stability + contrib * noise_size
                        local noise_pts = collect_points_under(noise_id, merges_by_id, n, {})
                        for _, p in ipairs(noise_pts) do
                            table.insert(record.point_ids, p)
                        end
                        stack[#stack + 1] = stay_id
                    else
                        -- Both sides too small: whole remaining subtree
                        -- is noise. Add all points; do not descend.
                        local all_size = subtree_size[dnode]
                        local contrib = split_lambda - record.birth_lambda
                        if contrib < 0 then contrib = 0 end
                        record.stability = record.stability + contrib * all_size
                        local all_pts = collect_points_under(dnode, merges_by_id, n, {})
                        for _, p in ipairs(all_pts) do
                            table.insert(record.point_ids, p)
                        end
                    end
                end
            end
        end
    end
    -- }}}

    -- {{{ iterative top-down greedy selection
    -- Standard HDBSCAN extraction rule: for each condensed cluster,
    -- compare its stability vs. the sum of its descendants' stabilities.
    -- If self ≥ children, select self; else recurse and select children.
    -- The natural recursive formulation overflows the Lua stack on tall
    -- condensed trees (depth bounded by n / min_cluster_size, up to ~260
    -- for n=7800), so we run it as an iterative post-order traversal.
    --
    -- The chosen_picks table maps cluster_idx -> {selected_picks list,
    -- chosen_stability}. Post-order ensures children are filled in
    -- before their parent reads them.
    local chosen_picks = {}
    local function select_subtree(start_idx)
        -- Two-action stack: "visit" pushes children first, "process"
        -- runs after children. Standard iterative post-order.
        local stack = {{idx = start_idx, action = "visit"}}
        while #stack > 0 do
            local item = stack[#stack]
            stack[#stack] = nil
            local idx = item.idx
            local node = condensed[idx]
            if item.action == "visit" then
                if #node.child_indices == 0 then
                    -- Leaf of the condensed tree: always select self.
                    chosen_picks[idx] = {picks = {idx}, stability = node.stability}
                else
                    -- Push self for the "process" step, then push every
                    -- child for "visit" so they fill in first.
                    stack[#stack + 1] = {idx = idx, action = "process"}
                    for _, c in ipairs(node.child_indices) do
                        stack[#stack + 1] = {idx = c, action = "visit"}
                    end
                end
            else  -- "process"
                local child_total = 0
                local child_picks = {}
                for _, c in ipairs(node.child_indices) do
                    local r = chosen_picks[c]
                    child_total = child_total + r.stability
                    for _, p in ipairs(r.picks) do
                        child_picks[#child_picks + 1] = p
                    end
                end
                if node.stability >= child_total then
                    chosen_picks[idx] = {picks = {idx}, stability = node.stability}
                else
                    chosen_picks[idx] = {picks = child_picks, stability = child_total}
                end
            end
        end
        return chosen_picks[start_idx].picks
    end
    -- }}}

    -- Skip the actual root in extraction: it's the "everything" cluster
    -- and selecting it would give one giant cluster, which is useless.
    -- Start from its children and union their picks.
    local selected = {}
    local root = condensed[1]
    for _, c in ipairs(root.child_indices) do
        for _, p in ipairs(select_subtree(c)) do
            table.insert(selected, p)
        end
    end

    -- If the root had no children (no real splits — everything is one
    -- big cluster or all noise), fall back to selecting the root itself.
    if #selected == 0 then
        selected = {1}
    end

    -- Build the result: clusters with their point lists and stabilities,
    -- plus the set of points that didn't end up in any selected cluster.
    local results = {}
    local in_cluster = {}  -- point id -> true if assigned
    for _, idx in ipairs(selected) do
        local c = condensed[idx]
        table.insert(results, {
            point_ids = c.point_ids,
            stability = c.stability,
            birth_lambda = c.birth_lambda,
        })
        for _, p in ipairs(c.point_ids) do in_cluster[p] = true end
    end
    local noise = {}
    for p = 0, n - 1 do
        if not in_cluster[p] then table.insert(noise, p) end
    end
    return results, noise
end
-- }}}

-- {{{ local function compute_centroid
-- Mean of the embedding vectors for the given point indices. Returns a
-- new FFI float[dim] buffer.
local function compute_centroid(emb_buf, dim, point_ids)
    local centroid = ffi.new("float[?]", dim)
    for d = 0, dim - 1 do centroid[d] = 0 end
    local n = #point_ids
    if n == 0 then return centroid end
    for _, p in ipairs(point_ids) do
        local base = p * dim
        for d = 0, dim - 1 do
            centroid[d] = centroid[d] + emb_buf[base + d]
        end
    end
    for d = 0, dim - 1 do centroid[d] = centroid[d] / n end
    -- Re-normalize to unit length so it lives in the same space as nomic
    -- embeddings — important for downstream cosine comparisons during
    -- naming (candidate-vs-centroid similarity scoring).
    local mag = 0
    for d = 0, dim - 1 do mag = mag + centroid[d] * centroid[d] end
    mag = math.sqrt(mag)
    if mag > 0 then
        for d = 0, dim - 1 do centroid[d] = centroid[d] / mag end
    end
    return centroid
end
-- }}}

-- {{{ local function run_clustering
-- The full pipeline for a real embedding matrix. Used by both the
-- real run and the test mode (with a synthetic matrix).
local function run_clustering(emb_buf, n, dim, min_samples, min_cluster_size)
    print(string.format("  1/6 distance matrix (n=%d, dim=%d)", n, dim))
    local dist = compute_distance_matrix(emb_buf, n, dim)

    print(string.format("  2/6 core distances (k=%d)", min_samples))
    local core = compute_core_distances(dist, n, min_samples)

    print("  3/6 mutual reachability transform (in-place)")
    mutate_to_mutual_reachability(dist, core, n)

    print("  4/6 Prim's MST on mutual reachability graph")
    local mst = prim_mst(dist, n)
    print(string.format("       %d MST edges", #mst))

    print("  5/6 single-linkage dendrogram via union-find")
    local merges = build_dendrogram(mst, n)
    print(string.format("       %d merges", #merges))

    print(string.format("  6/6 condensation + stability extraction (min_cluster_size=%d)",
        min_cluster_size))
    local clusters, noise = condense_and_extract(merges, n, min_cluster_size)
    print(string.format("       %d clusters, %d noise points", #clusters, #noise))

    return clusters, noise
end
-- }}}

-- {{{ local function test_main
-- Synthetic-data sanity check. Build a 2D test set with three clear
-- Gaussian-ish blobs plus a few outliers, run HDBSCAN, assert the
-- structure looks right. Catches gross algorithmic bugs without needing
-- the real corpus or the embedding server.
local function test_main()
    print("🧪 HDBSCAN synthetic test")
    -- Build 60-point dataset: 3 clusters of 18 + 6 noise points.
    -- 768-dim because that matches the real path's dimensionality —
    -- the algorithm doesn't care about dim but FFI sizing does.
    local n, dim = 60, 768
    local buf = ffi.new("float[?]", n * dim)
    math.randomseed(42)
    local function fill_gaussian(idx, mean_x, mean_y, spread)
        -- A poor man's Gaussian: average of 4 uniform draws.
        local function u()
            return (math.random() + math.random() + math.random() + math.random()) / 4 - 0.5
        end
        -- Make a sparse 768-dim vector: put cluster signal in first 2 dims,
        -- tiny noise everywhere else. Then unit-normalize.
        for d = 0, dim - 1 do buf[idx * dim + d] = u() * 0.01 end
        buf[idx * dim + 0] = mean_x + u() * spread
        buf[idx * dim + 1] = mean_y + u() * spread
        local mag = 0
        for d = 0, dim - 1 do mag = mag + buf[idx * dim + d] * buf[idx * dim + d] end
        mag = math.sqrt(mag)
        if mag > 0 then
            for d = 0, dim - 1 do buf[idx * dim + d] = buf[idx * dim + d] / mag end
        end
    end
    -- Three blobs widely separated in (dim 0, dim 1) plane.
    for i = 0, 17 do fill_gaussian(i,    1.0,  0.0, 0.1) end
    for i = 18, 35 do fill_gaussian(i,  -1.0,  1.0, 0.1) end
    for i = 36, 53 do fill_gaussian(i,  -1.0, -1.0, 0.1) end
    -- Six outliers scattered.
    for i = 54, 59 do fill_gaussian(i,
        (math.random() - 0.5) * 4, (math.random() - 0.5) * 4, 0.5) end

    local clusters, noise = run_clustering(buf, n, dim, 3, 5)
    print(string.format("\nResult: %d clusters, %d noise points", #clusters, #noise))
    for i, c in ipairs(clusters) do
        print(string.format("  cluster %d: %d points, stability=%.3f, birth_lambda=%.3f",
            i, #c.point_ids, c.stability, c.birth_lambda))
    end
    if #clusters < 2 or #clusters > 5 then
        error(string.format("FAIL: expected 3±2 clusters, got %d", #clusters))
    end
    if #noise == 0 then
        print("WARN: no noise points detected; outliers may have been absorbed.")
    end
    print("✅ Synthetic test passed (sanity-level — manual inspection above)")
end
-- }}}

-- {{{ local function real_main
local function real_main()
    print("🧮 HDBSCAN on " .. INPUT_BIN)
    print(string.format("    MIN_SAMPLES=%d MIN_CLUSTER_SIZE=%d", MIN_SAMPLES, MIN_CLUSTER_SIZE))
    local n, dim, emb_buf = load_embeddings_bin(INPUT_BIN)
    print(string.format("    loaded %d poems × %d dims", n, dim))

    local clusters, noise = run_clustering(emb_buf, n, dim, MIN_SAMPLES, MIN_CLUSTER_SIZE)

    print(string.format("\n📊 Raw HDBSCAN result: %d clusters, %d noise (%.1f%% of corpus before reassignment)",
        #clusters, #noise, #noise / n * 100))
    table.sort(clusters, function(a, b) return #a.point_ids > #b.point_ids end)

    -- Compute centroids from the CORE members only — these are the
    -- poems HDBSCAN flagged as definitively belonging to each dense
    -- region. The centroid represents the cluster's identity and is
    -- what naming uses; reassigned noise points later don't drift it.
    -- Track core_member_count separately from total member_count for
    -- the operator's situational awareness in the log + output.
    print("\n🎯 Computing core centroids (from dense-region members only)")
    local centroids = {}
    local core_member_count = {}
    for i, c in ipairs(clusters) do
        centroids[i] = compute_centroid(emb_buf, dim, c.point_ids)
        core_member_count[i] = #c.point_ids
    end

    -- {{{ noise reassignment
    -- For each noise point, compute cosine distance to each cluster
    -- centroid and append to the closest cluster's member list. Result:
    -- 100% coverage. HDBSCAN keeps doing what it's good at (finding the
    -- dense structure); we just don't throw away the loose poems
    -- afterwards. Centroids are NOT recomputed — keeping them anchored
    -- on the dense core preserves the cluster's semantic identity.
    if #noise > 0 then
        print(string.format("📌 Reassigning %d noise poems to nearest core centroid", #noise))
        local reassign_start = os.time()
        for _, noise_pid in ipairs(noise) do
            local best_idx = 1
            local best_sim = -2
            local base = noise_pid * dim
            for i, centroid in ipairs(centroids) do
                local dot = 0
                for d = 0, dim - 1 do
                    dot = dot + emb_buf[base + d] * centroid[d]
                end
                if dot > best_sim then
                    best_sim = dot
                    best_idx = i
                end
            end
            table.insert(clusters[best_idx].point_ids, noise_pid)
        end
        print(string.format("   reassigned in %ds", os.time() - reassign_start))
        noise = {}  -- all reassigned; clear for output
    end
    -- }}}

    print(string.format("\n📊 Final coverage: %d clusters, %d/%d poems (100%%)", #clusters, n - #noise, n))
    for i, c in ipairs(clusters) do
        print(string.format("    cluster %d: core %4d  +reassigned %4d  = %4d total  stability=%.3f",
            i, core_member_count[i], #c.point_ids - core_member_count[i], #c.point_ids, c.stability))
    end

    -- Write cluster metadata to a Lua file. Point IDs are 0-indexed
    -- (matching the binary input); consumers convert as needed.
    print("📝 Writing " .. OUTPUT_LUA)
    local out = io.open(OUTPUT_LUA, "w")
    if not out then error("Cannot write " .. OUTPUT_LUA) end
    out:write("-- Generated by themes-v2/hdbscan.lua (issue 029)\n")
    out:write("-- Point IDs are 0-indexed into tmp/poem-embeddings.bin / tmp/poem-texts.lua\n")
    out:write(string.format("return {\n  total_poems = %d,\n  embedding_dim = %d,\n", n, dim))
    out:write(string.format("  min_samples = %d,\n  min_cluster_size = %d,\n",
        MIN_SAMPLES, MIN_CLUSTER_SIZE))
    out:write(string.format("  noise_count = %d,\n", #noise))
    out:write("  clusters = {\n")
    for i, c in ipairs(clusters) do
        out:write(string.format("    {\n      id = %d,\n      stability = %.6f,\n      birth_lambda = %.6f,\n      core_member_count = %d,\n      member_count = %d,\n      member_ids = {",
            i, c.stability, c.birth_lambda, core_member_count[i], #c.point_ids))
        for j, p in ipairs(c.point_ids) do
            if j > 1 then out:write(",") end
            out:write(tostring(p))
        end
        out:write("},\n    },\n")
    end
    out:write("  },\n")
    out:write("  noise_ids = {")
    for j, p in ipairs(noise) do
        if j > 1 then out:write(",") end
        out:write(tostring(p))
    end
    out:write("},\n}\n")
    out:close()

    -- Write centroids in the same packed binary format as the input.
    print("📦 Writing " .. OUTPUT_BIN)
    local bin = io.open(OUTPUT_BIN, "wb")
    if not bin then error("Cannot write " .. OUTPUT_BIN) end
    write_uint32_le(bin, #centroids)
    write_uint32_le(bin, dim)
    for _, c in ipairs(centroids) do
        bin:write(ffi.string(c, dim * 4))
    end
    bin:close()

    print(string.format("\n✅ Done. %d clusters covering %d/%d poems (%.1f%%)",
        #clusters, n - #noise, n, (n - #noise) / n * 100))
end
-- }}}

if TEST_MODE then
    test_main()
else
    real_main()
end
