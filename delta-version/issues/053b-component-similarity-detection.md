# Issue 053b: Component Similarity Detection

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-23
**Parent**: Issue 053 (TODONE - Cross-Project Roadmap Coordinator)
**Dependencies**: Issue 053a (Project Scanning and Analysis)

---

## Current Behavior

After scanning projects (053a), we have lists of components mentioned across projects. However:

- Components may have different names for the same concept
- "threadpool" vs "worker-pool" vs "task-queue" vs "job-system"
- No automated way to detect semantic similarity
- Manual grouping would be error-prone and time-consuming

---

## Intended Behavior

Create a similarity detection system that:

1. **Groups semantically similar components** across projects
2. **Handles naming variations** (synonyms, abbreviations, hyphenation)
3. **Uses tiered analysis**: quick heuristics first, LLM for uncertain cases
4. **Outputs similarity clusters** with confidence scores

### Similarity Detection Tiers

```
Tier 1: Exact/Near-Exact Matching (instant)
─────────────────────────────────────────
"threadpool" == "thread-pool" == "thread_pool" == "ThreadPool"
Confidence: 1.0

Tier 2: Known Synonym Lookup (instant)
─────────────────────────────────────────
"threadpool" ~ "worker-pool" ~ "job-queue"  (from synonym dictionary)
Confidence: 0.95

Tier 3: Fuzzy String Matching (fast)
─────────────────────────────────────────
"threadpool" ~ "thredpool" (typo)
Levenshtein distance < 2
Confidence: 0.8

Tier 4: Ollama Quick Check (cheap)
─────────────────────────────────────────
"Is 'task-executor' similar to 'threadpool'? Answer: yes/no/maybe"
Confidence: 0.7-0.9 based on response

Tier 5: Opus Deep Analysis (expensive)
─────────────────────────────────────────
Full context analysis with implementation details
"Given these descriptions and code snippets, are these
 components functionally equivalent?"
Confidence: variable, with reasoning
```

### Output Format

```json
{
  "clusters": [
    {
      "canonical_name": "threadpool",
      "members": [
        {"name": "threadpool", "projects": ["symbeline-realms", "llm-http"], "confidence": 1.0},
        {"name": "worker-pool", "projects": ["world-edit-to-execute"], "confidence": 0.95},
        {"name": "task-queue", "projects": ["progress-ii"], "confidence": 0.85},
        {"name": "job-system", "projects": ["handheld-office"], "confidence": 0.80}
      ],
      "total_projects": 5,
      "library_candidate": true
    },
    {
      "canonical_name": "tui-framework",
      "members": [
        {"name": "tui", "projects": ["delta-version", "progress-ii"], "confidence": 1.0},
        {"name": "terminal-ui", "projects": ["authorship-tool"], "confidence": 0.95},
        {"name": "ncurses-wrapper", "projects": ["console-demakes"], "confidence": 0.75}
      ],
      "total_projects": 4,
      "library_candidate": true
    }
  ],
  "unclustered": [
    {"name": "unique-component", "projects": ["single-project"], "reason": "no similar components found"}
  ],
  "analysis_stats": {
    "tier1_matches": 45,
    "tier2_matches": 12,
    "tier3_matches": 8,
    "tier4_queries": 15,
    "tier5_queries": 3,
    "total_components": 156,
    "total_clusters": 23
  }
}
```

---

## Suggested Implementation Steps

### 1. Normalization Functions

```lua
-- -- {{{ normalize_for_comparison
local function normalize_for_comparison(name)
    return name:lower()
               :gsub("[_%-]", "")     -- Remove separators
               :gsub("s$", "")        -- Remove trailing 's' (plurals)
               :gsub("ing$", "")      -- Remove trailing 'ing'
               :gsub("er$", "")       -- Remove trailing 'er'
end

-- "threadpool", "thread-pool", "ThreadPools" all become "threadpool"
-- }}}
```

### 2. Synonym Dictionary

```lua
-- -- {{{ SYNONYMS
local SYNONYMS = {
    ["threadpool"] = {"worker-pool", "thread-pool", "task-queue", "job-queue", "executor", "job-system"},
    ["tui"] = {"terminal-ui", "text-ui", "ncurses", "curses", "framebuffer-ui"},
    ["parser"] = {"lexer", "tokenizer", "syntax-analyzer"},
    ["database"] = {"storage", "persistence", "data-store", "sqlite", "db"},
    ["http"] = {"web-server", "api-server", "rest-api", "http-server"},
    ["client"] = {"http-client", "api-client", "fetcher"},
    ["llm"] = {"language-model", "ai-model", "ollama", "anthropic-client", "gpt-client"},
    ["cache"] = {"memoization", "lru-cache", "memory-cache"},
    ["config"] = {"configuration", "settings", "preferences", "options"},
    ["logger"] = {"logging", "log-system", "debug-output"},
    ["json"] = {"json-parser", "json-encoder", "json-decoder", "serialization"},
    ["state-machine"] = {"fsm", "finite-state", "state-manager"},
    ["entity-system"] = {"ecs", "entity-component", "game-objects"],
    ["file-watcher"] = {"fs-watcher", "inotify", "file-monitor"],
    ["git"] = {"version-control", "vcs", "repository-manager"}
}

local function get_synonym_group(name)
    local normalized = normalize_for_comparison(name)
    for canonical, synonyms in pairs(SYNONYMS) do
        if normalized == normalize_for_comparison(canonical) then
            return canonical, synonyms
        end
        for _, syn in ipairs(synonyms) do
            if normalized == normalize_for_comparison(syn) then
                return canonical, synonyms
            end
        end
    end
    return nil, nil
end
-- }}}
```

### 3. Levenshtein Distance

```lua
-- -- {{{ levenshtein_distance
local function levenshtein_distance(s1, s2)
    local len1, len2 = #s1, #s2
    local matrix = {}

    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (s1:sub(i, i) == s2:sub(j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,      -- deletion
                matrix[i][j-1] + 1,      -- insertion
                matrix[i-1][j-1] + cost  -- substitution
            )
        end
    end

    return matrix[len1][len2]
end

local function fuzzy_match(name1, name2, threshold)
    threshold = threshold or 2
    local n1 = normalize_for_comparison(name1)
    local n2 = normalize_for_comparison(name2)
    return levenshtein_distance(n1, n2) <= threshold
end
-- }}}
```

### 4. Ollama Quick Check

```lua
-- -- {{{ ollama_similarity_check
local function ollama_similarity_check(component1, component2, context1, context2)
    local prompt = string.format([[
Are these two software components functionally similar?

Component A: %s
Context: %s

Component B: %s
Context: %s

Answer with ONLY one word: yes, no, or maybe
]], component1, context1 or "no context", component2, context2 or "no context")

    local response = ollama_query(prompt, {
        model = "llama3",
        temperature = 0.1,
        max_tokens = 10
    })

    local answer = response:lower():match("yes") and "yes" or
                   response:lower():match("no") and "no" or "maybe"

    local confidence = (answer == "yes") and 0.85 or
                       (answer == "maybe") and 0.5 or 0.1

    return answer == "yes" or answer == "maybe", confidence
end
-- }}}
```

### 5. Opus Deep Analysis

```lua
-- -- {{{ opus_deep_similarity
local function opus_deep_similarity(components_batch)
    -- Only called for uncertain cases or when building final clusters
    local prompt = [[
Analyze these software components and group them by functional similarity.
Components that do the same thing but have different names should be grouped together.

Components to analyze:
]] .. json.encode(components_batch) .. [[

For each group:
1. Choose a canonical name
2. List all similar components
3. Explain WHY they are similar
4. Rate your confidence (0.0-1.0)

Output as JSON:
{
  "groups": [
    {
      "canonical": "name",
      "members": ["component1", "component2"],
      "reasoning": "Both handle concurrent task execution...",
      "confidence": 0.92
    }
  ]
}
]]

    local response = anthropic_query(prompt, {
        model = "claude-opus-4-5-20251101",
        max_tokens = 4000,
        temperature = 0.2
    })

    -- Wrap in Ollama format per 053e spec
    return wrap_anthropic_response(response)
end
-- }}}
```

### 6. Tiered Clustering Algorithm

```lua
-- -- {{{ cluster_components
local function cluster_components(all_components)
    local clusters = {}
    local unclustered = {}
    local stats = {tier1 = 0, tier2 = 0, tier3 = 0, tier4 = 0, tier5 = 0}

    -- Build adjacency based on tiers
    local adjacency = {}
    for i, comp1 in ipairs(all_components) do
        adjacency[i] = adjacency[i] or {}
        for j, comp2 in ipairs(all_components) do
            if i < j then
                local similar, tier = check_similarity(comp1, comp2)
                if similar then
                    adjacency[i][j] = tier
                    adjacency[j] = adjacency[j] or {}
                    adjacency[j][i] = tier
                    stats["tier" .. tier] = stats["tier" .. tier] + 1
                end
            end
        end
    end

    -- Union-find clustering
    local parent = {}
    for i = 1, #all_components do parent[i] = i end

    local function find(x)
        if parent[x] ~= x then parent[x] = find(parent[x]) end
        return parent[x]
    end

    local function union(x, y)
        parent[find(x)] = find(y)
    end

    for i, neighbors in pairs(adjacency) do
        for j, _ in pairs(neighbors) do
            union(i, j)
        end
    end

    -- Group by root
    local groups = {}
    for i, comp in ipairs(all_components) do
        local root = find(i)
        groups[root] = groups[root] or {}
        table.insert(groups[root], comp)
    end

    -- Convert to output format
    for _, members in pairs(groups) do
        if #members > 1 then
            table.insert(clusters, {
                canonical_name = choose_canonical(members),
                members = members,
                total_projects = count_unique_projects(members),
                library_candidate = #members >= 3
            })
        else
            table.insert(unclustered, members[1])
        end
    end

    return {clusters = clusters, unclustered = unclustered, stats = stats}
end
-- }}}
```

---

## CLI Interface

```bash
# Run similarity detection
todone-similarity.sh

# Use specific tier only
todone-similarity.sh --max-tier=2   # Only exact + synonyms (fast)
todone-similarity.sh --max-tier=4   # Include Ollama checks

# Adjust thresholds
todone-similarity.sh --confidence=0.8   # Minimum confidence for grouping

# Output
todone-similarity.sh --format=json
todone-similarity.sh --format=matrix    # Show similarity matrix
todone-similarity.sh --show-reasoning   # Include LLM reasoning
```

---

## Acceptance Criteria

- [ ] Groups components with identical normalized names (Tier 1)
- [ ] Groups known synonyms from dictionary (Tier 2)
- [ ] Catches typos via fuzzy matching (Tier 3)
- [ ] Uses Ollama for uncertain cases (Tier 4)
- [ ] Falls back to Opus for complex analysis (Tier 5)
- [ ] Outputs clusters with confidence scores
- [ ] Identifies library candidates (3+ projects)
- [ ] Tracks analysis statistics by tier

---

## Related Documents

- Issue 053: TODONE main issue
- Issue 053a: Project Scanning (dependency)
- Issue 053d: Ollama Integration
- Issue 053e: Anthropic API Integration

---

## Notes

The tiered approach is crucial for cost efficiency. Most components will cluster via Tiers 1-3 (instant, free). Only truly ambiguous cases require LLM analysis, and Opus is reserved for final validation of high-value clusters.

The synonym dictionary should be expanded over time as new patterns emerge. Consider making it a configuration file that can be updated without code changes.
