# Issue 006: HTML Document Generation

## Current Behavior
The system only generates PDF documents for printing purposes without any web-based interactive viewing capabilities.

## Intended Behavior
Create HTML document generation system that:
- Generates chronological view of all poems
- Creates individual similarity pages for each poem
- Uses embedding-based similarity sorting above configurable threshold
- Provides navigation between chronological and similarity views
- Maintains aesthetic consistency with PDF layout
- Pre-generates all pages for static hosting

## Suggested Implementation Steps
1. Design HTML template system for poem display
2. Create chronological page generation logic
3. Implement embedding-based similarity calculation
4. Generate individual similarity pages for each poem (~4000 pages)
5. Add navigation links between views
6. Style HTML to match PDF aesthetic
7. Create static site generation pipeline
8. Implement comprehensive testing for large-scale generation

## Related Documents
- Source: next-4 file
- Related to: PDF generation system, embedding calculations

## Metadata
- Priority: High
- Complexity: Advanced
- Dependencies: Embedding system, template engine, static site generator
- Estimated Effort: Large

## Implementation Notes
This requires significant processing for ~4000 pages. Testing processes are critical before full generation. Consider parallelization strategies and incremental generation approaches.