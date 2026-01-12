# Issue 6-012: Implement words-pdf Styled Export System

**Phase**: 6 (Visual Content & User Experience Enhancements)
**Priority**: Medium
**Status**: Open
**Created**: 2026-01-12

## Current Behavior

The similar/different HTML pages exist only as web pages in the browser. There is no mechanism to export these pages as printable PDF documents with the words-pdf styling that users are familiar with from the original poetry collection.

## Intended Behavior

Users should be able to generate printable "hope card" PDFs from the similar/different pages. Each PDF should:
- Use the words-pdf styling and formatting conventions
- Contain approximately 200 poems per page (or per document)
- Be optimized for printing on physical paper
- Maintain the visual aesthetic of the original words-pdf project
- Focus on hopeful content rather than darker themes

The system should integrate with the existing words-pdf project located at `/home/ritz/programming/ai-stuff/words-pdf` to leverage its styling and formatting capabilities.

## Suggested Implementation Steps

### Step 1: Design PDF Export Architecture
1. Research the words-pdf project structure and styling system
2. Determine how to hook the similar/different page generation into the PDF export pipeline
3. Design a configuration system for selecting which poems to include in each PDF
4. Plan the page layout and formatting specifications

### Step 2: Implement Content Filtering
1. Create a filtering system to identify "hopeful" poems vs "insano" ones
2. Implement content selection based on:
   - Similarity/difference scores
   - Thematic classification
   - User-defined preferences
3. Add configuration options for content filtering

### Step 3: Integrate with words-pdf Pipeline
1. Create an adapter layer between the HTML generator and words-pdf
2. Extract poem content from similar/different pages
3. Format the content according to words-pdf specifications
4. Pass formatted content to the PDF generation system

### Step 4: Implement PDF Generation
1. Generate PDF files using words-pdf styling
2. Support batch generation for multiple similar/different pages
3. Add page numbering and metadata
4. Ensure proper text encoding and font rendering

### Step 5: Create Export Interface
1. Add command-line interface for PDF export
2. Create configuration file for export settings
3. Add options for:
   - Poem selection criteria
   - Number of poems per PDF
   - Output directory
   - Filtering preferences
4. Implement progress tracking for batch exports

### Step 6: Testing and Validation
1. Generate sample PDFs from various similar/different pages
2. Validate formatting and styling consistency
3. Test printing on physical paper
4. Verify poem content accuracy

## Related Documents

- Project vision: `/notes/vision` (mentions words-pdf integration)
- words-pdf project: `/home/ritz/programming/ai-stuff/words-pdf`
- HTML generator: `/src/flat-html-generator.lua`
- Similar/different pages: `/output/similar/` and `/output/different/`

## Related Tools

- words-pdf export system (to be investigated)
- PDF generation libraries (to be determined)
- Content filtering utilities (to be created)

## Technical Considerations

### Content Selection
- Each PDF should contain ~200 poems for manageable printing
- Need mechanism to identify "hopeful" vs "insano" content
- Should respect the thematic grouping of similar/different pages

### Styling Integration
- Must maintain words-pdf visual aesthetic
- Font selection and sizing important for readability
- Page margins and layout should support standard paper sizes

### Performance
- Batch generation should be efficient
- Consider caching formatted content
- Progress tracking for long-running exports

## Dependencies

- Phase 6 completion (HTML generation system)
- Access to words-pdf project and its styling system
- PDF generation library or tool integration

## Success Criteria

- [ ] PDF export system integrated with words-pdf styling
- [ ] Printable hope cards generated from similar/different pages
- [ ] Content filtering system distinguishes hopeful vs darker themes
- [ ] Batch export supports multiple pages efficiently
- [ ] Generated PDFs print correctly on physical paper
- [ ] Documentation for using the export system

## Notes

Original idea from sort-me-three:
> "similar-different should be hooked up to ../words-pdf/ to produce a prettified PDF version of each similar/different page. If they're only ~200 poems each, we should be able to make many printable hope cards. just, be sure to print the hopeful ones, and not the insano ones. kookydookerie and magic."

The emphasis on printing "hopeful" content suggests this feature is designed to create encouraging, uplifting physical artifacts from the digital poetry collection.
