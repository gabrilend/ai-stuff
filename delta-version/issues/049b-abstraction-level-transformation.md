# Issue 049b: Abstraction Level Transformation

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-11
**Parent**: Issue 049 (LLM Transcript Abstraction Viewer)
**Dependencies**: Issue 049a (Detail Level Filtering), Issue 049d (Ollama Processing Pipeline)

---

## Current Behavior

After detail filtering (049a), transcript content retains its original form - a mix of conversational exchanges, code snippets, explanations, and outcomes. This content is:

- Written in conversational style (not documentation style)
- Mixed levels of technical detail without organization
- Code-heavy or discussion-heavy depending on the conversation
- Difficult to skim for architectural understanding

There is no mechanism to transform this content to different abstraction levels appropriate for different readers.

---

## Intended Behavior

A transformation system that uses Ollama to rewrite filtered transcript content at three distinct abstraction levels, each serving different documentation purposes.

### Abstraction Levels Defined

#### HIGH Abstraction

**Purpose**: Architectural overview, system design, data flow understanding

**Characteristics**:
- Describes WHAT components do and HOW they connect
- Uses datapath terminology: "inputs", "outputs", "transforms", "routes"
- Avoids implementation specifics
- Shows feature interactions as relationships
- Resembles a technical roadmap or system diagram in prose form

**Example Transformation**:
```
BEFORE (filtered transcript):
"I implemented the login function. It checks the password hash using bcrypt,
creates a session token with JWT, stores it in Redis, and redirects to the
dashboard. Had to handle the case where Redis is down by falling back to
in-memory sessions."

AFTER (high abstraction):
"The authentication module validates user credentials and establishes sessions.
Input: user credentials from the login form. Output: authenticated session
state and navigation to protected content. The session persistence layer
supports multiple backends for reliability."
```

#### MEDIUM Abstraction

**Purpose**: Feature documentation, component descriptions, workflow explanations

**Characteristics**:
- Balances conceptual and technical descriptions
- Explains what features do and roughly how
- Includes key implementation decisions without code
- Shows workflow steps in logical sequence
- Resembles user-facing technical documentation

**Example Transformation**:
```
BEFORE (filtered transcript):
"I implemented the login function. It checks the password hash using bcrypt,
creates a session token with JWT, stores it in Redis, and redirects to the
dashboard. Had to handle the case where Redis is down by falling back to
in-memory sessions."

AFTER (medium abstraction):
"The login feature performs password verification using secure hashing,
generates session tokens, and manages session storage. When the primary
session store (Redis) is unavailable, the system falls back to in-memory
storage to maintain availability. Successful authentication redirects
users to the dashboard."
```

#### LOW Abstraction

**Purpose**: Implementation reference, code patterns, detailed solutions

**Characteristics**:
- Preserves technical implementation details
- Explains code patterns and design choices
- Highlights artful solutions to specific problems
- Uses words to describe code behavior (code may be included at high detail levels)
- Resembles inline code documentation or technical blog posts

**Example Transformation**:
```
BEFORE (filtered transcript):
"I implemented the login function. It checks the password hash using bcrypt,
creates a session token with JWT, stores it in Redis, and redirects to the
dashboard. Had to handle the case where Redis is down by falling back to
in-memory sessions."

AFTER (low abstraction):
"The login function uses a layered approach to session management:

1. Password Verification: Compares submitted password against stored bcrypt
   hash. Bcrypt was chosen over SHA-256 for its built-in salt and adaptive
   cost factor.

2. Token Generation: Creates JWT tokens with configurable expiry. The token
   payload includes user ID and role information for stateless auth checks.

3. Session Persistence: Primary storage uses Redis for distributed session
   access across multiple server instances. A fallback mechanism detects
   Redis connection failures and switches to in-memory storage, trading
   distributed capability for availability.

4. Navigation: Successful auth triggers client-side redirect to dashboard
   route, carrying the session token in an HTTP-only cookie."
```

---

## Suggested Implementation Steps

### 1. Abstraction Transform Prompts

```lua
-- {{{ get_abstraction_prompt
-- Returns the transformation prompt for a given abstraction level
local function get_abstraction_prompt(level)
    local prompts = {
        high = [[
Transform this development discussion into HIGH-LEVEL documentation.

Focus on:
- System architecture and component relationships
- Data flows: what goes in, what comes out, what transforms it
- Feature interactions and dependencies
- Avoid ALL implementation details, code, or specific technologies

Write as if describing the system to a technical executive who needs to understand the architecture but not the code.

Input:
---
%s
---

High-level documentation:]],

        medium = [[
Transform this development discussion into MEDIUM-LEVEL documentation.

Focus on:
- What features do and how they work conceptually
- Key implementation decisions and their rationale
- Workflow steps in logical sequence
- Include technology choices but not code details

Write as if creating user-facing technical documentation for developers who will use (not modify) this system.

Input:
---
%s
---

Feature documentation:]],

        low = [[
Transform this development discussion into LOW-LEVEL implementation documentation.

Focus on:
- Specific code patterns and design choices
- Why particular approaches were used over alternatives
- Technical details that future maintainers need to know
- Artful solutions to unique problems

Write as if creating inline documentation or a technical blog post for developers who will maintain this code.

Input:
---
%s
---

Implementation documentation:]],
    }

    return prompts[level] or prompts.medium
end
-- }}}
```

### 2. Section-by-Section Transformation

```lua
-- {{{ transform_section
-- Transforms a single filtered section to target abstraction level
local function transform_section(ollama_client, section, abstraction_level)
    local prompt = string.format(
        get_abstraction_prompt(abstraction_level),
        section.content
    )

    local response = ollama_client:generate(prompt, {
        temperature = 0.3,  -- Lower temperature for consistent documentation style
        max_tokens = 1024,
    })

    return {
        original = section,
        transformed = response,
        abstraction = abstraction_level,
    }
end
-- }}}
```

### 3. Batch Processing with Progress

```lua
-- {{{ transform_all_sections
-- Transforms all filtered sections with progress reporting
local function transform_all_sections(ollama_client, sections, abstraction_level, progress_callback)
    local results = {}
    local total = #sections

    for i, section in ipairs(sections) do
        if progress_callback then
            progress_callback(i, total, section)
        end

        local result = transform_section(ollama_client, section, abstraction_level)
        table.insert(results, result)
    end

    return results
end
-- }}}
```

### 4. Output Assembly

```lua
-- {{{ assemble_transformed_document
-- Combines transformed sections into a cohesive document
local function assemble_transformed_document(transformed_sections, metadata)
    local output = {}

    -- Document header
    table.insert(output, string.format([[
# %s - %s Abstraction, Detail Level %d

Generated: %s
Source: %s
Sections: %d

---

]],
        metadata.project_name,
        metadata.abstraction:upper(),
        metadata.detail_level,
        os.date("%Y-%m-%d %H:%M"),
        metadata.source_file,
        #transformed_sections
    ))

    -- Table of contents
    table.insert(output, "## Table of Contents\n\n")
    for i, section in ipairs(transformed_sections) do
        local title = extract_section_title(section)
        table.insert(output, string.format("%d. [%s](#section-%d)\n", i, title, i))
    end
    table.insert(output, "\n---\n\n")

    -- Transformed sections
    for i, section in ipairs(transformed_sections) do
        table.insert(output, string.format("## Section %d: %s\n\n",
            i, extract_section_title(section)))
        table.insert(output, section.transformed)
        table.insert(output, "\n\n---\n\n")
    end

    return table.concat(output)
end
-- }}}
```

### 5. Quality Validation

```lua
-- {{{ validate_transformation
-- Ensures transformation maintains semantic content
local function validate_transformation(original, transformed, abstraction_level)
    local checks = {
        -- Minimum length check (shouldn't shrink too much)
        length_ratio = #transformed / #original,

        -- Key term preservation (important concepts should survive)
        key_terms_preserved = count_preserved_key_terms(original, transformed),

        -- Abstraction-specific checks
        has_code = transformed:match("```") ~= nil,
        has_dataflow_terms = transformed:match("[Ii]nput") and transformed:match("[Oo]utput"),
    }

    -- High abstraction shouldn't have code
    if abstraction_level == "high" and checks.has_code then
        return false, "High abstraction should not contain code blocks"
    end

    -- High abstraction should have dataflow terminology
    if abstraction_level == "high" and not checks.has_dataflow_terms then
        return false, "High abstraction should describe data flows (input/output)"
    end

    -- Minimum content preservation
    if checks.length_ratio < 0.2 then
        return false, "Transformation removed too much content"
    end

    return true, "Validation passed"
end
-- }}}
```

---

## CLI Interface

```bash
# Transform filtered content to high abstraction
./scripts/abstraction-transform.lua --level=high filtered-output.md

# Transform with validation
./scripts/abstraction-transform.lua --level=low --validate filtered-output.md

# Compare all three abstraction levels
./scripts/abstraction-transform.lua --compare-levels filtered-output.md
```

---

## File Locations

- **Script**: `delta-version/scripts/libs/abstraction-transform.lua`
- **Prompts**: `delta-version/config/abstraction-prompts.lua`
- **Output**: `delta-version/llm-transcripts/generated/{level}-abstraction/`

---

## Acceptance Criteria

- [ ] High abstraction produces architecture-focused documentation
- [ ] Medium abstraction produces feature-focused documentation
- [ ] Low abstraction produces implementation-focused documentation
- [ ] Code blocks appear only in low abstraction (and only at high detail levels)
- [ ] Dataflow terminology appears in high abstraction output
- [ ] Transformed content maintains semantic accuracy
- [ ] Quality validation catches inappropriate transformations
- [ ] Processing provides progress feedback for large transcripts
- [ ] Output includes table of contents and section numbering

---

## Technical Notes

### Temperature Setting

Lower temperature (0.3) produces more consistent, deterministic documentation. Higher temperature might produce more creative prose but risks inconsistency across sections.

### Chunk Size

Very long sections should be split before transformation to stay within LLM context limits. Aim for 500-1000 word chunks.

### Retry Logic

If validation fails, retry transformation with a refined prompt that emphasizes the failed criterion. Maximum 3 retries before falling back to original content with a warning marker.

### Caching

Cache transformed sections by (content_hash, abstraction_level) to avoid reprocessing when regenerating at different detail levels.

---

## Related

- Issue 049a: Provides filtered input for transformation
- Issue 049c: Receives transformed output for chapter organization
- Issue 049d: Provides Ollama client for LLM calls
