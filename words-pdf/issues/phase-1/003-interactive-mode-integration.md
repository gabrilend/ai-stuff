# Issue 003: Interactive Mode Integration

## Current Behavior
The main script only generates PDFs and doesn't provide alternative execution modes or argument-based navigation features.

## Intended Behavior
Integrate interactive navigation into the main generator script by:
- Adding interactive mode option to main menu argument collection
- Pre-calculating and caching embeddings during generation phase
- Providing dual functionality: generation mode vs navigation mode
- Ensuring embeddings are available when interactive mode is selected

## Suggested Implementation Steps
1. Modify main script argument parsing to include interactive mode flag
2. Create embedding calculation and caching system during PDF generation
3. Implement mode detection and routing logic
4. Design data persistence layer for embedding cache
5. Add interactive mode startup and initialization
6. Create fallback behavior when embeddings aren't pre-calculated

## Related Documents
- Source: next-1 file (lines 33-38)
- Related to: compile-pdf.lua main script
- Dependencies: Issues 001, 002

## Metadata
- Priority: Medium
- Complexity: Medium
- Dependencies: Existing main script, embedding system
- Estimated Effort: Medium

## Implementation Notes
This serves as the integration point between existing PDF generation and new interactive features. Consider security implications mentioned in the source.