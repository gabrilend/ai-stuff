# Issue 001: Embedding Hyperlink Navigation System

## Current Behavior
The PDF generation system only creates static documents without any interactive navigation capabilities. Users cannot explore relationships between poems or words within the text.

## Intended Behavior
Implement an interactive navigation system that:
- Creates hyperlinks between words using embeddings to determine semantic relationships
- Allows users to click or type words to navigate to the most closely related content
- Gradually eliminates shown poems from the system over time
- Provides immortal version options for preservation

## Suggested Implementation Steps
1. Research and integrate embeddings library (likely Ollama-based)
2. Pre-calculate word embeddings for all text content
3. Create embedding similarity computation functions
4. Design hyperlink data structure and caching system
5. Implement word-to-content mapping algorithms
6. Create navigation logic for finding nearest semantic matches

## Related Documents
- Source: next-1 file
- Related to: compile-pdf.lua main application

## Metadata
- Priority: High
- Complexity: Advanced
- Dependencies: Embeddings library, caching system
- Estimated Effort: Large (multi-week implementation)

## Implementation Notes
This feature represents a significant architectural change from static PDF generation to interactive content navigation. Consider creating a separate module or extending the existing Lua framework.