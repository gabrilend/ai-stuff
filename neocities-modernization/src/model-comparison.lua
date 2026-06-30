#!/usr/bin/env luajit
-- {{{ model-comparison.lua
-- Data + report layer for the embedding-model evaluation framework (Issue
-- 10-031). Three subcommands, each a separate resumable step so the expensive
-- middle one (which needs a model loaded on the GPU) is isolated from the cheap
-- ends:
--
--   select : choose a reproducible sample of poems + a spread of anchor poems,
--            write output/model-evaluation/sample.json
--   embed  : embed that sample with the CURRENTLY-RUNNING model server, write
--            output/model-evaluation/<model>/sample-embeddings.json
--   report : read the sample + every model's embeddings, rank each anchor per
--            model, compute agreement/divergence + "personality" signals, and
--            emit output/model-evaluation/comparison-report.html (+ metrics.json)
--
-- General description (for a CEO): step one picks the line-up of poems to judge;
-- step two runs once per model (with that model loaded) to record its opinions;
-- step three lays the opinions side by side as a web page a human can read.
--
-- Orchestration (which server to start for each model) lives in the bash driver
-- scripts/evaluate-embedding-models; this file does the data, not the process
-- management -- separation of concerns.
-- }}}

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/?.lua;" .. DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local utils = require("utils")
local evaluator = require("model-evaluator")

utils.init_assets_root({ DIR })
local EVAL_DIR = DIR .. "/output/model-evaluation"

-- {{{ local function parse_flags(argv, from)
-- Tiny --key value / --flag parser over argv starting at index `from`. Bare
-- --flag becomes true. Keeps the CLI self-describing without a dependency.
local function parse_flags(argv, from)
    local f = {}
    local i = from
    while i <= #argv do
        local a = argv[i]
        if a:sub(1, 2) == "--" then
            local key = a:sub(3)
            local val = argv[i + 1]
            if val == nil or val:sub(1, 2) == "--" then
                f[key] = true; i = i + 1
            else
                f[key] = val; i = i + 2
            end
        else
            i = i + 1
        end
    end
    return f
end
-- }}}

-- {{{ local function read_json(path) / write_json(path, t)
local function read_json(path)
    local fh = io.open(path, "r")
    if not fh then return nil end
    local s = fh:read("*a"); fh:close()
    return dkjson.decode(s)
end

local function write_json(path, t)
    -- Parent dir is created by the caller; a missing one should fail loudly here
    -- rather than leave a silent half-run, so io.open's nil is asserted.
    local fh = assert(io.open(path, "w"), "cannot write " .. path)
    fh:write(dkjson.encode(t, { indent = true }))
    fh:close()
end
-- }}}

-- {{{ local function model_dir(model)
-- Per-model output subdir, name sanitized the same way embeddings_dir sanitizes
-- (colon -> underscore etc.), so "embeddinggemma-300m" and a future "qwen:4b"
-- both map to a safe folder.
local function model_dir(model)
    return EVAL_DIR .. "/" .. model:gsub("[^%w%-_.]", "_")
end
-- }}}

-- {{{ local function lcg(seed)
-- Self-contained linear congruential generator (Park-Miller constants). Used
-- instead of math.random so the sample is byte-identical on any machine and any
-- LuaJIT build -- the comparison is only meaningful if everyone judges the SAME
-- poems. Returns a function yielding floats in [0,1).
local function lcg(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
end
-- }}}

-- {{{ local function load_poems()
-- Load poems.json, keeping only real embeddable text (skip image-only entries
-- and empties): a candidate with no words tells us nothing about a model's taste.
-- Returns an array of { poem_index, id, content, length }.
local function load_poems()
    local data = read_json(utils.asset_path("poems.json"))
    if not data then error("cannot read assets/poems.json") end
    local poems = data.poems or data
    local out = {}
    for _, p in ipairs(poems) do
        local content = p.content or p.text or ""
        if not p.is_image_only and #content:gsub("%s", "") > 0 then
            out[#out + 1] = {
                poem_index = p.poem_index or p.id,
                id = p.id,
                content = content,
                length = p.length or #content,
            }
        end
    end
    return out
end
-- }}}

-- {{{ local function cmd_select(flags)
-- Pick a reproducible sample (--sample N) and a length-spread set of anchors
-- (--anchors K). Anchors come from sorting the sample by length and taking K
-- evenly spaced positions, so they span short imagery-poems through long
-- narratives (the diversity Issue 10-031 asks for) with no hand-curation.
local function cmd_select(flags)
    local n_sample = tonumber(flags.sample) or 500
    local n_anchor = tonumber(flags.anchors) or 8
    local seed = tonumber(flags.seed) or 12345

    local poems = load_poems()
    if #poems == 0 then error("no embeddable poems found") end

    -- Seeded Fisher-Yates over an index list, then take the first N. Shuffling
    -- (vs striding) removes any bias from how poems.json happens to be ordered.
    local rand = lcg(seed)
    local order = {}
    for i = 1, #poems do order[i] = i end
    for i = #order, 2, -1 do
        local j = math.floor(rand() * i) + 1
        order[i], order[j] = order[j], order[i]
    end
    n_sample = math.min(n_sample, #poems)
    local sample = {}
    for i = 1, n_sample do sample[i] = poems[order[i]] end

    local by_len = {}
    for i = 1, #sample do by_len[i] = sample[i] end
    table.sort(by_len, function(a, b) return a.length < b.length end)
    local anchors = {}
    n_anchor = math.min(n_anchor, #by_len)
    for k = 1, n_anchor do
        local pos = math.floor((k - 0.5) / n_anchor * #by_len) + 1
        if pos > #by_len then pos = #by_len end
        anchors[k] = by_len[pos].poem_index
    end

    utils.ensure_directory(EVAL_DIR)
    write_json(EVAL_DIR .. "/sample.json", {
        seed = seed, sample_size = #sample, anchor_count = #anchors,
        anchors = anchors, sample = sample,
    })
    print(string.format("[select] sample=%d anchors=%d seed=%d -> %s/sample.json",
        #sample, #anchors, seed, EVAL_DIR))
end
-- }}}

-- {{{ local function cmd_embed(flags)
-- Embed the sample with the model currently served by llama.cpp. --server names
-- the config entry (so the right prompt prefix is applied) and --model is the
-- identifier sent in the request. Chunked so one over-large request cannot blow
-- the server's batch limits; a missing vector is a hard error (a partial space
-- would silently corrupt every ranking), not a skipped poem.
local function cmd_embed(flags)
    local server = flags.server or error("--server NAME required")
    local model = flags.model or error("--model NAME required")
    local chunk = tonumber(flags.chunk) or 16

    -- Late require: fuzzy-computing pulls in the embedding stack; only this step
    -- needs it, so select/report stay light and runnable without a server.
    local inference = require("inference-server-config")
    inference.set_project_root(DIR)
    inference.set_selected_server(server)
    -- Select the model too, so format_embedding_prompt resolves THIS model's
    -- prefix from the server's available_models (nomic clusters, gemma has its
    -- own clustering prompt, mxbai none) -- not the server default's.
    inference.set_selected_model(model)
    local fuzzy = require("fuzzy-computing")
    local endpoint = inference.build_host_url()
    local format_fn = inference.format_embedding_prompt
    -- Chunk to the LOADED model's context budget. mxbai-embed-large caps at 512
    -- tokens (BERT-large), while nomic and gemma allow ~2048; a poem longer than
    -- the cap is split and its chunk vectors averaged -- exactly how the real
    -- pipeline embeds long poems (Issue 10-050). Computed once per model here so
    -- we don't re-query /tokenize's budget on every batch.
    local count_fn = fuzzy.make_token_counter(endpoint)
    local max_tokens = fuzzy.embedding_chunk_budget(endpoint, format_fn)
    -- embedding_chunk_budget derives from a fixed MODEL_CONTEXT_TOKENS constant
    -- (sized for nomic/gemma's ~2048). Some models have a SMALLER trained context
    -- than that and than the server's launch --ctx-size, so their real limit must
    -- be capped explicitly or the chunker emits chunks the server rejects
    -- ("exceed_context_size_error"). mxbai-embed-large is BERT-large: 512 tokens.
    local model_ctx_cap = {
        ["mxbai-embed-large-v1"] = 500,  -- 512 trained ctx, minus specials, headroom
    }
    if flags["max-tokens"] then max_tokens = tonumber(flags["max-tokens"]) end
    if model_ctx_cap[model] then max_tokens = math.min(max_tokens, model_ctx_cap[model]) end

    local sample_doc = read_json(EVAL_DIR .. "/sample.json")
        or error("run `select` first: missing " .. EVAL_DIR .. "/sample.json")
    local sample = sample_doc.sample

    local embeddings = {}
    local total = #sample
    for start = 1, total, chunk do
        local stop = math.min(start + chunk - 1, total)
        local texts, idxs = {}, {}
        for i = start, stop do
            texts[#texts + 1] = sample[i].content
            idxs[#idxs + 1] = sample[i].poem_index
        end
        local vecs, err = fuzzy.embed_texts_with_chunking(texts, model, {
            endpoint = endpoint, format_fn = format_fn,
            count_fn = count_fn, max_tokens = max_tokens,
        })
        if not vecs then error("embedding batch failed: " .. tostring(err)) end
        for j = 1, #texts do
            if not vecs[j] then
                error(string.format("missing vector for poem_index %s (model %s)",
                    tostring(idxs[j]), model))
            end
            embeddings[tostring(idxs[j])] = vecs[j]
        end
        io.write(string.format("\r[embed %s] %d/%d", model, stop, total)); io.flush()
    end
    io.write("\n")

    local dim = 0
    for _, v in pairs(embeddings) do dim = #v; break end
    utils.ensure_directory(model_dir(model))
    write_json(model_dir(model) .. "/sample-embeddings.json", {
        model = model, server = server, dimensions = dim, embeddings = embeddings,
    })
    print(string.format("[embed] %s: %d vectors x %d dims", model, total, dim))
end
-- }}}

-- {{{ local function esc(s)
-- HTML-escape for poem text dropped into the report.
local function esc(s)
    return (tostring(s):gsub("[&<>\"]", {
        ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;",
    }))
end
-- }}}

-- {{{ local function snippet(text, n)
-- One-line preview of a poem: collapse whitespace, clip to n chars with an
-- ellipsis. Keeps the side-by-side columns scannable.
local function snippet(text, n)
    local s = tostring(text):gsub("%s+", " "):gsub("^%s+", "")
    if #s > n then s = s:sub(1, n) .. "\226\128\166" end  -- UTF-8 ellipsis
    return s
end
-- }}}

-- {{{ local function cmd_report(flags)
-- Read the sample + each model's embeddings and render the side-by-side report.
-- --models is the ordered, comma-separated column list (also the labels). For
-- each anchor we rank the pool per model, show the top-K, and compute pairwise
-- agreement (Kendall's tau + top-K overlap). Per model we also aggregate the
-- "personality" signals so a human can see WHAT each rewards.
local function cmd_report(flags)
    local top_k = tonumber(flags["top-k"]) or 10
    local models_csv = flags.models or error("--models a,b,c required")
    local models = {}
    for m in models_csv:gmatch("[^,]+") do models[#models + 1] = m:gsub("^%s+", ""):gsub("%s+$", "") end

    local sample_doc = read_json(EVAL_DIR .. "/sample.json")
        or error("missing sample.json -- run select + embed first")

    -- poem_index -> content/length, for snippets, lexical overlap, length bias.
    local text_of, len_of = {}, {}
    for _, p in ipairs(sample_doc.sample) do
        text_of[p.poem_index] = p.content
        len_of[p.poem_index] = p.length
        text_of[tostring(p.poem_index)] = p.content  -- tolerate string/number keys
        len_of[tostring(p.poem_index)] = p.length
    end

    -- Load each model's pool (poem_index -> vector). Keys are strings in JSON;
    -- normalize to the same key type the rest of the code uses.
    local pools, dims = {}, {}
    for _, m in ipairs(models) do
        local doc = read_json(model_dir(m) .. "/sample-embeddings.json")
            or error("missing embeddings for model '" .. m .. "' -- run embed for it")
        local pool = {}
        for k, v in pairs(doc.embeddings) do pool[k] = v end
        pools[m] = pool
        dims[m] = doc.dimensions
    end

    -- Per-anchor rankings, and per-model personality accumulators.
    local anchors = sample_doc.anchors
    local rankings = {}            -- rankings[anchor][model] = sorted list
    local pers = {}               -- pers[model] = { jacc={}, lenr={}, score={} }
    for _, m in ipairs(models) do pers[m] = { jacc = {}, lenr = {}, score = {} } end

    for _, anchor in ipairs(anchors) do
        local akey = tostring(anchor)
        rankings[akey] = {}
        for _, m in ipairs(models) do
            local avec = pools[m][akey]
            if avec then
                local r = evaluator.rank_anchor(avec, pools[m], akey, top_k)
                rankings[akey][m] = r
                local pp = evaluator.personality(text_of[akey] or "", len_of[akey] or 0,
                    r, text_of, len_of, top_k)
                pers[m].jacc[#pers[m].jacc + 1] = pp.mean_jaccard
                pers[m].lenr[#pers[m].lenr + 1] = pp.mean_len_ratio
                pers[m].score[#pers[m].score + 1] = pp.mean_score
            end
        end
    end

    -- ---- render HTML ----
    local h = {}
    local function w(s) h[#h + 1] = s end
    w([[<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">]])
    w([[<meta name="viewport" content="width=device-width, initial-scale=1">]])
    w("<title>Embedding model comparison</title>")
    w([[<style>
      :root{--bg:#0f1117;--card:#181b24;--ink:#e6e8ee;--mut:#9aa3b2;--line:#2a2f3a;--hi:#7cd}
      *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--ink);
        font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;padding:24px}
      h1{font-size:22px;margin:0 0 4px} .sub{color:var(--mut);margin:0 0 20px}
      .legend{background:var(--card);border:1px solid var(--line);border-radius:10px;
        padding:14px 16px;margin:0 0 24px;max-width:1100px}
      table{border-collapse:collapse;width:100%} td,th{border:1px solid var(--line);
        padding:8px 10px;vertical-align:top;text-align:left}
      th{color:var(--mut);font-weight:600;font-size:13px}
      .pers td{font-variant-numeric:tabular-nums}
      .anchor{background:var(--card);border:1px solid var(--line);border-radius:10px;
        padding:16px;margin:26px 0 10px;max-width:1100px}
      .anchor .meta{color:var(--mut);font-size:13px;margin-bottom:6px}
      .anchor .text{white-space:pre-wrap;font-size:15px}
      .cols{display:grid;gap:14px;grid-template-columns:repeat(var(--n),1fr);max-width:1100px}
      .col{background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden}
      .col h3{margin:0;padding:10px 12px;background:#1f2430;font-size:14px;border-bottom:1px solid var(--line)}
      .col ol{margin:0;padding:8px 8px 10px 30px} .col li{margin:0 0 8px;font-size:13px}
      .sc{color:var(--hi);font-variant-numeric:tabular-nums}
      .jac{color:var(--mut);font-size:11px} .agree{color:var(--mut);font-size:13px;
        margin:8px 0 0;max-width:1100px}
      .shared{outline:2px solid #3b6;outline-offset:-2px;border-radius:4px;padding:1px 3px}
      code{color:#cdb}
    </style>]])
    w("</head><body>")
    w("<h1>What does each model think \"similar\" means?</h1>")
    w(string.format([[<p class="sub">Sample of %d poems, %d anchors, seed %s. Each model embedded the SAME poems; for each anchor we show its nearest neighbours per model.</p>]],
        sample_doc.sample_size, sample_doc.anchor_count, tostring(sample_doc.seed)))

    -- legend / how to read
    w([[<div class="legend"><b>How to read this.</b> Cosine scores are only
        comparable <i>within</i> a column (each model has its own space). The
        interesting thing is <b>which poems</b> each model picks and where they
        <b>disagree</b>. Green outline = a poem two or more models both chose for
        this anchor. The personality table below is data, not a verdict:
        <code>lexical&nbsp;overlap</code> = average shared-word fraction between an
        anchor and its top matches (high = the model rewards surface wording;
        low = it rewards something deeper \226\128\148 meaning/theme/tone);
        <code>length&nbsp;ratio</code> = how close in length its picks are (near 1 =
        a length bias).</div>]])

    -- personality summary
    w("<h2 style='max-width:1100px'>Model personalities (averaged over anchors)</h2>")
    w("<table class='pers' style='max-width:1100px'><tr><th>model</th><th>dims</th>"
      .. "<th>lexical overlap</th><th>length ratio</th><th>mean top-K cosine</th></tr>")
    for _, m in ipairs(models) do
        w(string.format("<tr><td>%s</td><td>%s</td><td>%.3f</td><td>%.3f</td><td>%.3f</td></tr>",
            esc(m), tostring(dims[m]),
            evaluator.mean(pers[m].jacc) or 0,
            evaluator.mean(pers[m].lenr) or 0,
            evaluator.mean(pers[m].score) or 0))
    end
    w("</table>")

    -- per anchor
    local metrics = { models = models, top_k = top_k, anchors = {} }
    for _, anchor in ipairs(anchors) do
        local akey = tostring(anchor)
        w("<div class='anchor'>")
        w(string.format("<div class='meta'>Anchor &mdash; poem #%s, %s chars</div>",
            esc(akey), tostring(len_of[akey] or "?")))
        w("<div class='text'>" .. esc(snippet(text_of[akey] or "", 600)) .. "</div></div>")

        -- which poems are shared across >=2 models for this anchor (for green outline)
        local count_in = {}
        for _, m in ipairs(models) do
            local r = rankings[akey][m]
            if r then for _, e in ipairs(r) do
                count_in[e.poem_index] = (count_in[e.poem_index] or 0) + 1
            end end
        end

        w(string.format("<div class='cols' style='--n:%d'>", #models))
        for _, m in ipairs(models) do
            w("<div class='col'><h3>" .. esc(m) .. "</h3><ol>")
            local r = rankings[akey][m]
            if r then
                for _, e in ipairs(r) do
                    local cls = (count_in[e.poem_index] or 0) >= 2 and " class='shared'" or ""
                    local jac = evaluator.lexical_jaccard(text_of[akey] or "", text_of[e.poem_index] or "")
                    w(string.format("<li><span class='sc'>%.3f</span> "
                        .. "<span class='jac'>(words %.0f%%)</span><br><span%s>%s</span></li>",
                        e.score, jac * 100, cls, esc(snippet(text_of[e.poem_index] or "", 140))))
                end
            else
                w("<li><i>no embedding</i></li>")
            end
            w("</ol></div>")
        end
        w("</div>")

        -- pairwise agreement line + collect metrics
        local amx = { anchor = anchor, pairs = {} }
        local parts = {}
        for i = 1, #models - 1 do
            for j = i + 1, #models do
                local ra, rb = rankings[akey][models[i]], rankings[akey][models[j]]
                if ra and rb then
                    local shared = evaluator.topk_agreement(ra, rb, top_k)
                    local tau = evaluator.kendall_tau(ra, rb)
                    parts[#parts + 1] = string.format("%s vs %s: %d/%d shared%s",
                        models[i], models[j], shared, top_k,
                        tau and string.format(", \207\132=%.2f", tau) or "")
                    amx.pairs[#amx.pairs + 1] = {
                        a = models[i], b = models[j], shared = shared, kendall_tau = tau,
                    }
                end
            end
        end
        w("<p class='agree'>Agreement &mdash; " .. esc(table.concat(parts, " &nbsp;|&nbsp; ")) .. "</p>")
        metrics.anchors[#metrics.anchors + 1] = amx
    end

    w("</body></html>")

    utils.ensure_directory(EVAL_DIR)
    local html_path = EVAL_DIR .. "/comparison-report.html"
    local fh = assert(io.open(html_path, "w"), "cannot write " .. html_path)
    fh:write(table.concat(h)); fh:close()
    write_json(EVAL_DIR .. "/metrics.json", metrics)
    print("[report] wrote " .. html_path)
end
-- }}}

-- {{{ dispatch
local sub = arg[2]
local flags = parse_flags(arg, 3)
if sub == "select" then cmd_select(flags)
elseif sub == "embed" then cmd_embed(flags)
elseif sub == "report" then cmd_report(flags)
else
    io.stderr:write("usage: model-comparison.lua DIR {select|embed|report} [--flags]\n")
    os.exit(1)
end
-- }}}
