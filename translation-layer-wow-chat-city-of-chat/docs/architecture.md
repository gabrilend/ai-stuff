# Architecture Overview

## System Concept

```
+-------------+       +-------------------+       +-------------+
|  WoW Client | <---> |                   | <---> | CoH Server  |
+-------------+       |                   |       +-------------+
                      |  Translation      |
                      |      Layer        |
+-------------+       |                   |       +-------------+
| CoH Client  | <---> |  [LLM + Narrative]| <---> | WoW Server  |
+-------------+       +-------------------+       +-------------+
```

The translation layer sits between clients and servers of both games,
intercepting packets, translating them through LLM-guided logic, and
forwarding them to the appropriate destination.

---

## Core Components

### 1. Protocol Handler (`src/protocol/`)

Responsible for reading and writing game packets.

```
protocol/
  wow/
    parser.lua      -- Parse incoming WoW packets
    writer.lua      -- Construct outgoing WoW packets
    opcodes.lua     -- WoW opcode definitions
  coh/
    parser.lua      -- Parse incoming CoH packets
    writer.lua      -- Construct outgoing CoH packets
    opcodes.lua     -- CoH opcode definitions
```

**Separation of concerns:** Parsing (data in) is isolated from writing
(data out). Each game's protocol is fully encapsulated.

### 2. Translation Engine (`src/translation/`)

Maps data structures between games.

```
translation/
  mapper.lua        -- Core mapping logic
  rules.lua         -- Static translation rules
  dynamic.lua       -- LLM-generated dynamic rules
```

The engine applies rules in priority order:
1. Static rules (known, tested mappings)
2. Dynamic rules (LLM-generated for edge cases)
3. Narrative fallback (when translation is impossible)

### 3. LLM Integration (`src/llm/`)

Generates translation code on-the-fly.

```
llm/
  client.lua        -- API client for LLM service
  prompts.lua       -- Prompt templates for code generation
  sandbox.lua       -- Safe execution of generated code
  cache.lua         -- Cache successful translations
```

**Security:** Generated code runs in a sandboxed Lua environment with
no filesystem or network access beyond the translation layer.

### 4. Narrative System (`src/narrative/`)

Transforms untranslatable events into in-game narrative.

```
narrative/
  engine.lua        -- Core narrative generation
  archetypes.lua    -- Character archetype mappings
  worlds.lua        -- Zone/region mappings
  abilities.lua     -- Skill/power mappings
  anomalies.lua     -- Weird stuff handler (floating objects, etc.)
```

When a WoW ability has no CoH equivalent, the narrative system creates
an in-universe explanation that preserves game feel.

### 5. Network Layer (`src/network/`)

Handles actual packet interception and forwarding.

```
network/
  proxy.lua         -- Main proxy server
  intercept.lua     -- Packet interception
  forward.lua       -- Packet forwarding
  session.lua       -- Session management
```

---

## Data Flow

```
1. Client sends packet
        |
        v
2. Proxy intercepts packet
        |
        v
3. Protocol handler parses packet
        |
        v
4. Translation engine applies rules
        |
        +--> Static rule found? --> Apply and continue
        |
        +--> No static rule? --> Query LLM for dynamic rule
        |                              |
        |                              v
        |                        Sandbox executes generated code
        |                              |
        |                              v
        |                        Cache if successful
        |
        v
5. If translation fails: Narrative system generates fallback
        |
        v
6. Protocol handler constructs target packet
        |
        v
7. Proxy forwards to destination server
```

---

## Data Separation Principle

Following project guidelines, data generation and data viewing are
strictly separated:

**Data Generation:**
- Protocol parsing produces structured data objects
- Translation produces mapping objects
- LLM produces code strings
- Narrative produces text/event objects

**Data Viewing:**
- Packet visualization (debug)
- Translation log viewer
- Narrative output display
- Session state inspector

Each viewer consumes generated data without coupling to generation logic.

---

## Error Philosophy

Per project guidelines: **prefer errors over fallbacks.**

When translation fails:
1. Log the failure with full context
2. Generate an issue file if pattern is new
3. Attempt narrative fallback (explicit, not silent)
4. Notify the player something unusual happened

Silent failures corrupt the translation state and make debugging
impossible. Every unexpected state should be visible.

---

## Technology Stack

- **Language:** Lua (LuaJIT compatible)
- **Network:** LuaSocket or custom FFI bindings
- **LLM API:** HTTP client to local or remote LLM service
- **Storage:** File-based (JSON/Lua tables in `tmp/` and `assets/`)
- **Testing:** Custom test harness with packet replay

---

## Related Projects

- `world-edit-to-execute` - WC3 map parsing (relevant packet parsing patterns)
- Shared Lua libraries at `/home/ritz/programming/ai-stuff/libs/`
- TUI library for terminal interface
