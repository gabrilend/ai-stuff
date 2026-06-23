# Issue 10-046: Interleave Poems with LLM Transcripts in Chronological Timeline

## Priority
Medium

## Current Behavior

The chronological timeline displays poems in chronological order, but does not include moments from LLM transcript sessions. These transcripts (stored in `llm-transcripts/`) contain valuable context about the creative process, decision-making, and development journey that occurred between poem creation.

Currently:
- Poems are displayed chronologically
- LLM transcripts exist separately in `llm-transcripts/` directory
- No unified view showing the relationship between creative output (poems) and development work (LLM sessions)

## Intended Behavior

Create a unified chronological timeline that interleaves poems with LLM transcript moments, sorted by absolute timestamp. The timeline should:

1. **Display both poems and LLM moments** in strict chronological order
2. **Show only relevant LLM content**:
   - User's comments and questions
   - Response summaries (not full source code)
   - Key decisions and insights
3. **Maintain temporal fidelity**: Each moment should feel authentic to when it occurred
4. **Create narrative flow**: Like "an island floating in the clouds, learning to consider itself"

Example timeline:
```
[2026-01-15 14:23] Poem: "winter's gentle whisper"
[2026-01-15 15:47] LLM: User asked about implementing word cloud
[2026-01-15 15:52] LLM: Summary: Added word cloud feature with stop words
[2026-01-16 09:12] Poem: "code and consciousness"
[2026-01-16 11:30] LLM: User: "can we make the colors semantic?"
```

## Technical Analysis

### Data Sources

1. **Poems** (existing):
   - Source: `assets/poems.json`
   - Timestamp field: `timestamp` (Unix timestamp)
   - Already sorted and indexed

2. **LLM Transcripts** (new source):
   - Location: `llm-transcripts/`
   - Files: `*_summary.md` files
   - Format: Markdown with timestamps
   - Need to parse and extract:
     - User messages (not tool calls or system messages)
     - Response summaries (exclude code blocks)
     - Timestamps for each interaction

### Parsing LLM Transcripts

Create `src/extract-llm-transcripts.lua`:
- Read all `*_summary.md` files from `llm-transcripts/`
- Parse markdown structure to identify user vs assistant messages
- Extract timestamps (may need to infer from file metadata if not in content)
- Filter out:
  - Source code blocks
  - Tool invocations
  - System messages
- Keep:
  - User questions/comments
  - Brief summaries of assistant responses (1-2 sentences)
  - Key decisions or insights

### Timeline Generation

Modify `src/flat-html-generator.lua`:
- Load both poems and LLM transcript moments
- Sort by absolute timestamp
- Render with visual distinction between poem vs LLM moment
- Use different styling/formatting for each type

### Visual Design

**Poem entry** (existing):
```
┌────────────────────────────┐
│ Poem Title                 │
│ 2026-01-15 14:23          │
│                            │
│ poem content here...       │
└────────────────────────────┘
```

**LLM moment entry** (new):
```
┌────────────────────────────┐
│ 🤖 Development Moment      │
│ 2026-01-15 15:47          │
│                            │
│ User: "can we add..."      │
│ → Summary: Added feature   │
└────────────────────────────┘
```

## Suggested Implementation Steps

1. **Create LLM transcript extractor**:
   - `src/extract-llm-transcripts.lua`
   - Parse `llm-transcripts/*_summary.md` files
   - Extract user messages and response summaries
   - Generate `assets/llm-moments.json`

2. **Modify timeline generation**:
   - Update `src/flat-html-generator.lua`
   - Load both `poems.json` and `llm-moments.json`
   - Merge and sort by timestamp
   - Render unified chronological timeline

3. **Add configuration**:
   - `config.lua`: Add `llm_transcripts` section:
     ```lua
     llm_transcripts = {
         enabled = true,
         source_dir = "llm-transcripts",
         include_in_chronological = true,
         max_response_summary_length = 200, -- chars
     }
     ```

4. **Create tests**:
   - Verify parsing of LLM transcript files
   - Test timestamp sorting across both sources
   - Validate HTML rendering

5. **Update documentation**:
   - Document the unified timeline feature
   - Explain how LLM moments are extracted and displayed

## Additional Ideas (Future Enhancements)

The user mentioned some interesting ideas for deeper interaction capture:

### Button Cadences and Mouse Tracking
"we don't have the button cadences... maybe we could design a daemon that records them when they change? and we could easily scroll to whatever part of the file we wanted. Mouse positions, too. Like, a reverse Runescape bot controller. Auto-hotkey and such."

This could be a separate issue (10-047):
- Daemon to record keyboard/mouse activity
- Timestamps for every interaction
- Playback functionality (like replay)
- Integration with timeline to show "what was happening" at any moment

Could be implemented as:
- Lua daemon using input event monitoring
- JSON log of interactions with timestamps
- Visualization showing activity patterns
- "Rewind to this moment" functionality

## Related Issues

- Issue 10-042a: Gallery pages (completed) - Similar concept of integrating external content
- Issue 10-044: Conversation starters integration - Another unified source
- Future: Issue 10-047: Input activity recording daemon

## Metadata

- **Status**: Open
- **Created**: 2026-04-10
- **Phase**: 10 (Website Completion / Integration)
- **Estimated Complexity**: Medium
- **Dependencies**: None (llm-transcripts already exist)
- **Affects**: Chronological timeline, potentially new "unified timeline" page
