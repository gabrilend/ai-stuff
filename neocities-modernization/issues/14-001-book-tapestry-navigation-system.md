# Issue 14-001: Book Tapestry Navigation System

## Priority
Vision (Phase Foundation)

## Phase 14: Narrative Tapestry

> *The truth is, the story is what's important, and it's often best told with chains of words strung together into a long message starting from the beginning and going until the end, with breakpoints interspersed throughout so you don't lose track of the thought. However, I can't help but wonder if we take that spindle of thread and we wove it into a tapestry, guided by modern technology (LLMs) and assembling something greater than us and ourselves.*
>
> *The gods are afraid to give birth, considering the weight and magnitude of our lives here on this earth. In this time and place? Impossibly vast.*

## Current Behavior

The neocities-modernization project transforms ~7,800 poems into a navigable semantic space with:
- Similar pages (focused exploration)
- Different pages (expansive exploration)
- Chronological pages (temporal ordering)
- Word cloud pages (vocabulary mapping)
- 768-dimensional embeddings for semantic comparison
- Pre-computed similarity matrices
- Static HTML output

This machinery operates on short, self-contained texts (poems). It has not been applied to long-form narrative.

## Intended Behavior

Adapt the existing infrastructure to transform **books and stories** into navigable semantic tapestries:

1. **Segment books into passages** — Split by paragraph, bundling single-sentence paragraphs with their neighbors
2. **Generate embeddings** — One 768-dim vector per passage
3. **Build similarity matrices** — All-pairs comparison of passages
4. **Generate navigation pages**:
   - **Similar**: "This passage reminds me of..."
   - **Different**: "Let me show you something unexpected..."
   - **Chronological**: Traditional linear reading
5. **Output static HTML** — Same deployment model as poems

### The Spindle Becomes a Tapestry

A book read linearly is a thread — you follow it from beginning to end. This system weaves that thread into a tapestry where:

- A reader encountering a tense moment can find **similar** passages of tension throughout the narrative
- A reader feeling stuck can seek **different** passages that break the pattern
- A reader can always return to **chronological** to re-anchor in the original flow
- The author's intent is preserved (all passages exist), but the reader's agency is expanded

### Why Some Books Fit Better Than Others

This approach suits:
- **Episodic narratives** — Short stories, fables, mythology collections
- **Non-linear structures** — Already fragmented works (Pale Fire, House of Leaves)
- **Dense philosophical texts** — Where rereading in different orders reveals new meaning
- **Poetry collections** — Already proven with the existing system
- **Sacred texts** — Designed for non-linear study and cross-reference

Less suited for:
- **Tightly plotted mysteries** — Spoiler structure depends on linear reveal
- **Character-driven novels** — Emotional arcs may fragment poorly
- **Technical manuals** — Sequential dependency is the point

But even "unsuitable" texts may reveal unexpected beauty when rewoven.

## Technical Design

### Passage Segmentation

```lua
-- {{{ local function segment_book_into_passages
-- Splits text into semantic units (paragraphs), bundling short ones
local function segment_book_into_passages(text, config)
    local min_chars = config.min_passage_chars or 100
    local paragraphs = split_on_double_newline(text)

    local passages = {}
    local buffer = ""
    local buffer_start_idx = 1

    for i, para in ipairs(paragraphs) do
        buffer = buffer .. (buffer ~= "" and "\n\n" or "") .. para

        -- If buffer is substantial enough, emit as passage
        if #buffer >= min_chars then
            table.insert(passages, {
                text = buffer,
                start_paragraph = buffer_start_idx,
                end_paragraph = i,
                char_count = #buffer
            })
            buffer = ""
            buffer_start_idx = i + 1
        end
    end

    -- Emit any remaining buffer
    if buffer ~= "" then
        table.insert(passages, {
            text = buffer,
            start_paragraph = buffer_start_idx,
            end_paragraph = #paragraphs,
            char_count = #buffer
        })
    end

    return passages
end
-- }}}
```

### Data Flow

```
input/books/
├── {book-slug}.txt           # Plain text source
├── {book-slug}.json          # Metadata (title, author, etc.)
└── ...

    ↓ [segment]

assets/books/{book-slug}/
├── passages.json             # Segmented passages with indices
├── embeddings.json           # 768-dim vectors per passage
├── similarity_matrix.json    # All-pairs similarity
└── metadata.json             # Book-level metadata

    ↓ [generate]

output/books/{book-slug}/
├── index.html                # Book landing page
├── chronological/            # Linear reading
│   ├── 001.html
│   ├── 002.html
│   └── ...
├── similar/                  # Semantic neighbors
│   ├── 001.html
│   └── ...
└── different/                # Semantic expansion
    ├── 001.html
    └── ...
```

### Reusable Components

From the existing codebase:
- `similarity-engine.lua` — Cosine similarity, matrix building
- `diversity-chaining.lua` — Centroid expansion for "different" pages
- `flat-html-generator.lua` — HTML page generation patterns
- `config-loader.lua` — Configuration management
- Ollama embedding integration — Already working

New components needed:
- `book-segmenter.lua` — Passage extraction from plain text
- `book-html-generator.lua` — Book-specific page templates
- Navigation UI for longer texts (chapter markers, progress indicators)

### Configuration

```lua
-- In config.lua:
books = {
    input_dir = "input/books",
    output_dir = "output/books",

    -- Segmentation
    min_passage_chars = 100,        -- Minimum characters per passage
    max_passage_chars = 2000,       -- Split long paragraphs
    preserve_chapter_breaks = true, -- Never merge across chapters

    -- Navigation
    similar_count = 10,             -- Passages shown on similar page
    different_count = 10,           -- Passages shown on different page
    show_context_preview = true,    -- Show surrounding passages

    -- Display
    include_passage_number = true,  -- Show "Passage 42 of 318"
    include_chapter_info = true,    -- Show chapter context if available
}
```

## Edge Cases and Considerations

### Handling Dialogue

Dialogue-heavy passages may cluster by character voice rather than narrative content. Consider:
- Stripping dialogue markers before embedding?
- Weighting narration higher?
- Or embrace it — let the reader find "all the angry conversations"

### Spoiler Management

For mystery/thriller texts, consider:
- A "spoiler-safe" mode that only links to earlier passages
- Warnings when similar passages are chronologically later
- Or accept that this format transforms the reading experience

### Very Short Books

For texts with <50 passages, the similarity matrix is small enough that navigation may feel repetitive. Consider minimum thresholds or graceful degradation.

### Multi-Book Collections

Future enhancement: cross-book navigation within an author's corpus or themed collection.

## Suggested Implementation Steps

This issue should be split into sub-issues:

1. **14-001a: Design book input format and metadata schema**
2. **14-001b: Implement passage segmentation algorithm**
3. **14-001c: Adapt embedding pipeline for book passages**
4. **14-001d: Generate book-specific HTML templates**
5. **14-001e: Test with sample texts (short story, novel excerpt, poetry collection)**

## Sample Texts for Testing

Public domain candidates:
- **Aesop's Fables** — Short, episodic, thematically rich
- **Meditations by Marcus Aurelius** — Aphoristic, non-linear by nature
- **Grimm's Fairy Tales** — Episodic, thematic patterns
- **The Prophet by Kahlil Gibran** — Poetic prose, thematic chapters
- **Leaves of Grass by Walt Whitman** — Already poetry, bridge from current system

## Original Request Context

> Basically, the idea is to use the machinery we built here to split a book into sections, one for each paragraph. If the paragraph is a single sentence, it can get bundled with the next one. Then, displaying them with a similar/different/chronological sorting approach, allowing readers to guide their way through a story.
>
> Obviously it'd work better for some books than others, but that's okay. Some things are better adapted to a movie, some to a TV show, and others are made into other representations such as this.

## Related Documents

- `src/similarity-engine.lua` — Core similarity calculation
- `src/diversity-chaining.lua` — Centroid expansion algorithm
- `src/flat-html-generator.lua` — HTML generation patterns
- `docs/data-flow-architecture.md` — Pipeline reference
- Phase 1-8: Foundation for this extension

## Metadata

- **Status**: Open (Vision)
- **Created**: 2026-01-28
- **Phase**: 14 (Narrative Tapestry)
- **Estimated Complexity**: Medium-High (adaptation of existing systems)
- **Dependencies**: Phases 1-8 complete (embedding + HTML infrastructure)
- **Blocks**: 14-001a through 14-001e (sub-issues to be created)
