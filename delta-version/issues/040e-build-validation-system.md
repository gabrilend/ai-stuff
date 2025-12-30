# Issue 040e: Build Validation and Conflict Detection System

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: Medium
- **Type**: Implementation
- **Dependencies**: 040a (Event Taxonomy), 040d (History System)
- **Blocks**: 040f (Interactive Interface)

## Current Behavior
When new guidelines are proposed, there is no automated way to:
- Detect if they conflict with existing guidelines
- Identify semantic duplicates or near-duplicates
- Validate that proposed guidelines are well-formed
- Check if existing guidelines have become stale or contradictory

## Intended Behavior
Create a validation system that:
1. Detects conflicts between new and existing guidelines
2. Identifies semantic similarity (duplicates, overlaps)
3. Validates guideline format and clarity
4. Monitors guideline health over time
5. Surfaces conflicts for human resolution

## Conflict Types

### 1. Direct Contradiction
Two guidelines that cannot both be followed.

**Example**:
```
Existing: "Use tabs for indentation"
Proposed: "Use 2 spaces for indentation"
→ CONFLICT: Direct contradiction on indentation
```

**Detection**: Keyword extraction + opposite/alternative matching

### 2. Scope Overlap
Guidelines that may conflict in certain contexts.

**Example**:
```
Existing: "All functions should have docstrings"
Proposed: "Trivial helper functions don't need documentation"
→ OVERLAP: Conflicting scope for "trivial" functions
```

**Detection**: Shared subject + narrowing/broadening qualifiers

### 3. Semantic Duplicate
Guidelines that express the same thing differently.

**Example**:
```
Existing: "Prefer error messages over fallbacks"
Proposed: "Always throw errors rather than silently failing"
→ DUPLICATE: Same semantic meaning
```

**Detection**: High semantic similarity score

### 4. Implicit Conflict
Guidelines that work individually but cause problems together.

**Example**:
```
Existing: "All API responses must be under 100ms"
Proposed: "Always validate input against remote schema"
→ IMPLICIT: Remote validation may exceed 100ms
```

**Detection**: Requires domain knowledge (hardest to automate)

## Validation Pipeline

```
New Proposal
     │
     ▼
┌─────────────────────┐
│  Format Validator   │ → Reject if malformed
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Keyword Extractor  │ → Extract: subject, verb, qualifiers
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Conflict Detector  │ → Check against all existing guidelines
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Duplicate Finder   │ → Semantic similarity check
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Resolution Advisor │ → Suggest how to resolve conflicts
└──────────┬──────────┘
           │
           ▼
    Validation Result
```

## Format Validation

### Well-Formed Guideline Criteria

```lua
-- {{{ function validate_format
function validate_format(guideline)
    local errors = {}
    local warnings = {}

    -- Length check
    if #guideline < 10 then
        table.insert(errors, "Guideline too short (min 10 chars)")
    end
    if #guideline > 500 then
        table.insert(warnings, "Guideline very long, consider splitting")
    end

    -- Actionable check (contains verb)
    local verbs = {"should", "must", "prefer", "always", "never", "use", "avoid", "ensure", "write", "create"}
    local has_verb = false
    for _, verb in ipairs(verbs) do
        if guideline:lower():find(verb) then
            has_verb = true
            break
        end
    end
    if not has_verb then
        table.insert(warnings, "Guideline may not be actionable (no imperative verb)")
    end

    -- Specificity check
    local vague_terms = {"stuff", "things", "etc", "somehow", "maybe"}
    for _, term in ipairs(vague_terms) do
        if guideline:lower():find(term) then
            table.insert(warnings, "Guideline contains vague term: " .. term)
        end
    end

    -- Contradiction in self
    if guideline:find("but") or guideline:find("however") or guideline:find("except") then
        table.insert(warnings, "Guideline contains exception - consider splitting")
    end

    return {
        valid = #errors == 0,
        errors = errors,
        warnings = warnings
    }
end
-- }}}
```

## Keyword Extraction

```lua
-- {{{ function extract_keywords
function extract_keywords(guideline)
    local result = {
        subjects = {},    -- What the guideline is about
        actions = {},     -- What to do
        qualifiers = {},  -- Scope modifiers
        negations = {}    -- What NOT to do
    }

    -- Subject extraction (nouns after articles)
    for subject in guideline:gmatch("the (%w+)") do
        table.insert(result.subjects, subject:lower())
    end
    for subject in guideline:gmatch("all (%w+)") do
        table.insert(result.subjects, subject:lower())
    end

    -- Action extraction
    local action_verbs = {
        "use", "avoid", "prefer", "ensure", "write", "create",
        "should", "must", "never", "always"
    }
    for _, verb in ipairs(action_verbs) do
        if guideline:lower():find(verb) then
            table.insert(result.actions, verb)
        end
    end

    -- Qualifier extraction
    local qualifiers = {
        "always", "never", "sometimes", "usually", "only",
        "except", "unless", "when", "if", "all", "some"
    }
    for _, qual in ipairs(qualifiers) do
        if guideline:lower():find(qual) then
            table.insert(result.qualifiers, qual)
        end
    end

    -- Negation detection
    if guideline:find("not") or guideline:find("never") or
       guideline:find("don't") or guideline:find("avoid") then
        result.negations = extract_after_negation(guideline)
    end

    return result
end
-- }}}
```

## Conflict Detection

```lua
-- {{{ function detect_conflicts
function detect_conflicts(proposal, existing_guidelines)
    local conflicts = {}

    local proposal_kw = extract_keywords(proposal.content)

    for _, existing in ipairs(existing_guidelines) do
        local existing_kw = extract_keywords(existing.content)

        -- Check for same subject
        local shared_subjects = intersection(proposal_kw.subjects, existing_kw.subjects)

        if #shared_subjects > 0 then
            -- Check for opposing actions
            if has_opposing_actions(proposal_kw, existing_kw) then
                table.insert(conflicts, {
                    type = "direct_contradiction",
                    existing = existing,
                    shared_subjects = shared_subjects,
                    severity = "high"
                })
            -- Check for scope conflict
            elseif has_scope_conflict(proposal_kw, existing_kw) then
                table.insert(conflicts, {
                    type = "scope_overlap",
                    existing = existing,
                    shared_subjects = shared_subjects,
                    severity = "medium"
                })
            end
        end
    end

    return conflicts
end
-- }}}

-- {{{ function has_opposing_actions
function has_opposing_actions(kw1, kw2)
    -- Check for negation of same action
    if intersection(kw1.negations, kw2.actions) or
       intersection(kw2.negations, kw1.actions) then
        return true
    end

    -- Check for mutually exclusive actions
    local opposites = {
        {"use", "avoid"},
        {"always", "never"},
        {"prefer", "disprefer"},
        {"tabs", "spaces"},
        {"error", "fallback"}
    }

    for _, pair in ipairs(opposites) do
        if (contains(kw1.actions, pair[1]) and contains(kw2.actions, pair[2])) or
           (contains(kw1.actions, pair[2]) and contains(kw2.actions, pair[1])) then
            return true
        end
    end

    return false
end
-- }}}
```

## Semantic Similarity

```lua
-- {{{ function calculate_similarity
function calculate_similarity(text1, text2)
    -- Simple word overlap similarity (Jaccard)
    local words1 = extract_words(text1:lower())
    local words2 = extract_words(text2:lower())

    local intersection = 0
    local union_set = {}

    for word, _ in pairs(words1) do
        union_set[word] = true
        if words2[word] then
            intersection = intersection + 1
        end
    end

    for word, _ in pairs(words2) do
        union_set[word] = true
    end

    local union = table_size(union_set)

    return intersection / union  -- Jaccard coefficient
end
-- }}}

-- {{{ function find_duplicates
function find_duplicates(proposal, existing_guidelines)
    local duplicates = {}
    local DUPLICATE_THRESHOLD = 0.7
    local SIMILAR_THRESHOLD = 0.5

    for _, existing in ipairs(existing_guidelines) do
        local similarity = calculate_similarity(proposal.content, existing.content)

        if similarity >= DUPLICATE_THRESHOLD then
            table.insert(duplicates, {
                type = "duplicate",
                existing = existing,
                similarity = similarity
            })
        elseif similarity >= SIMILAR_THRESHOLD then
            table.insert(duplicates, {
                type = "similar",
                existing = existing,
                similarity = similarity
            })
        end
    end

    return duplicates
end
-- }}}
```

## Resolution Suggestions

```lua
-- {{{ function suggest_resolution
function suggest_resolution(conflict)
    local suggestions = {}

    if conflict.type == "direct_contradiction" then
        table.insert(suggestions, {
            action = "replace",
            description = "Replace existing guideline with new one",
            risk = "May break established workflows"
        })
        table.insert(suggestions, {
            action = "scope",
            description = "Add scope qualifier to one or both guidelines",
            example = "Add 'for Lua files' or 'except in tests'"
        })
        table.insert(suggestions, {
            action = "reject",
            description = "Keep existing guideline, reject proposal",
            risk = "May lose valid insight"
        })
    elseif conflict.type == "scope_overlap" then
        table.insert(suggestions, {
            action = "merge",
            description = "Combine both guidelines with explicit exceptions",
            example = "Base rule + exception clause"
        })
        table.insert(suggestions, {
            action = "hierarchy",
            description = "Establish precedence (general vs specific)",
            example = "Specific overrides general"
        })
    elseif conflict.type == "duplicate" then
        table.insert(suggestions, {
            action = "keep_existing",
            description = "Proposal is redundant, keep existing wording"
        })
        table.insert(suggestions, {
            action = "update_wording",
            description = "Proposal has better wording, update existing"
        })
    end

    return suggestions
end
-- }}}
```

## Health Monitoring

### Stale Guideline Detection

```lua
-- {{{ function check_guideline_health
function check_guideline_health(guideline)
    local health = {
        status = "healthy",
        issues = {}
    }

    -- Check for violations in history
    local violations = count_violations(guideline.id)
    if violations > 5 then
        health.status = "degraded"
        table.insert(health.issues, {
            type = "frequent_violations",
            count = violations,
            suggestion = "Guideline may be too strict or unclear"
        })
    end

    -- Check age without review
    local days_since_review = days_since(guideline.last_reviewed)
    if days_since_review > 180 then
        table.insert(health.issues, {
            type = "stale",
            days = days_since_review,
            suggestion = "Consider reviewing for continued relevance"
        })
    end

    -- Check for conflicting guidelines added later
    local later_conflicts = find_conflicts_added_after(guideline)
    if #later_conflicts > 0 then
        health.status = "conflicted"
        table.insert(health.issues, {
            type = "post_hoc_conflict",
            conflicts = later_conflicts,
            suggestion = "Resolve conflicts or clarify scope"
        })
    end

    return health
end
-- }}}
```

## Suggested Implementation Steps

1. **Implement format validator** (`src/validation/format.lua`)
   - Length checks
   - Actionability checks
   - Vague term detection

2. **Build keyword extractor** (`src/validation/keywords.lua`)
   - Subject extraction
   - Action extraction
   - Qualifier detection

3. **Create conflict detector** (`src/validation/conflicts.lua`)
   - Direct contradiction detection
   - Scope overlap detection
   - Opposing action logic

4. **Implement similarity checker** (`src/validation/similarity.lua`)
   - Word tokenization
   - Jaccard coefficient
   - Duplicate/similar thresholds

5. **Build resolution advisor** (`src/validation/resolution.lua`)
   - Conflict-specific suggestions
   - Risk assessments
   - Example generations

6. **Create health monitor** (`src/validation/health.lua`)
   - Violation tracking
   - Staleness detection
   - Conflict monitoring

7. **Integration with API** (update 040b handlers)
   - Run validation on all proposals
   - Return conflicts with proposals
   - Add health endpoint

## Validation Report Format

```lua
{
    proposal = "prop_001",
    timestamp = 1735480000,

    format = {
        valid = true,
        warnings = {"Guideline very long"}
    },

    conflicts = {
        {
            type = "direct_contradiction",
            existing_id = "g015",
            existing_content = "Use tabs for indentation",
            severity = "high",
            suggestions = {...}
        }
    },

    duplicates = {
        {
            type = "similar",
            existing_id = "g042",
            similarity = 0.65
        }
    },

    recommendation = "review_required",  -- auto_approve | review_required | auto_reject
    reason = "Direct conflict with existing guideline g015"
}
```

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [Issue 040a](./040a-design-event-taxonomy.md) - Event classification used here
- [Issue 040d](./040d-create-history-audit-system.md) - History for health checks

## Notes
- Start with simple keyword matching; upgrade to semantic similarity later
- Consider using external NLP library for better similarity (if LuaJIT compatible)
- False positives are acceptable; false negatives are not (err on side of flagging)
- Human review is always final arbiter of conflicts
