# Issue 001a: Create HTML Template System

## Current Behavior
- No HTML template system exists for poem pages
- No standardized structure for poem presentation
- No template inheritance or reusability

## Intended Behavior
- Reusable HTML template system for consistent poem page generation
- Base template with poem content substitution placeholders
- Clean, semantic HTML structure following accessibility best practices
- Template supports similarity recommendations integration

## Suggested Implementation Steps
1. **Base Template Creation**: Design master HTML template with placeholders
2. **Template Variables**: Define substitution variables for poem data
3. **Template Processing**: Implement Lua-based template engine
4. **Validation System**: Ensure generated HTML is valid and accessible
5. **Testing Framework**: Create sample poem pages for template validation

## Technical Requirements

### **HTML Template Structure**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{POEM_TITLE} - Poetry Collection</title>
    <style>
        /* Minimal inline CSS as per project requirements (no external CSS) */
        body { font-family: Georgia, serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 1rem; }
        .poem-content { white-space: pre-line; margin: 2rem 0; }
        .similar-poems { background: #f5f5f5; padding: 1rem; margin: 2rem 0; }
        .navigation { margin: 1rem 0; }
        .golden-badge { background: gold; padding: 0.5rem; margin: 1rem 0; }
    </style>
</head>
<body>
    <nav class="navigation">
        <a href="../../index.html">← Poetry Collection</a>
        <a href="../index.html">← Category Index</a>
    </nav>
    
    <main>
        <h1>{POEM_TITLE}</h1>
        
        {GOLDEN_POEM_INDICATOR}
        
        <div class="poem-content">{POEM_CONTENT}</div>
        
        <aside class="similar-poems">
            <h3>Similar Poems</h3>
            <ol>{SIMILAR_POEMS_LIST}</ol>
        </aside>
    </main>
</body>
</html>
```

### **Template Processing Function**
```lua
-- {{{ function generate_poem_html
function generate_poem_html(poem, similar_poems, template_path)
    local template = utils.read_file(template_path)
    
    -- Basic substitutions
    template = template:gsub("{POEM_TITLE}", escape_html(poem.title or "Untitled"))
    template = template:gsub("{POEM_CONTENT}", escape_html(poem.content))
    
    -- Golden poem indicator
    local golden_indicator = ""
    if poem.is_fediverse_golden then
        golden_indicator = '<div class="golden-badge">✨ Perfect Fediverse Length: 1024 characters</div>'
    end
    template = template:gsub("{GOLDEN_POEM_INDICATOR}", golden_indicator)
    
    -- Similar poems list
    local similar_html = ""
    for i, similar in ipairs(similar_poems) do
        similar_html = similar_html .. string.format(
            '<li><a href="%s">%s</a> (%.3f similarity)</li>',
            similar.url, escape_html(similar.title), similar.score
        )
    end
    template = template:gsub("{SIMILAR_POEMS_LIST}", similar_html)
    
    return template
end
-- }}}
```

### **HTML Escaping Utility**
```lua
-- {{{ function escape_html
function escape_html(text)
    if not text then return "" end
    return tostring(text)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&#39;")
end
-- }}}
```

## Quality Assurance Criteria
- Generated HTML validates with W3C HTML validator
- Template supports all required poem metadata fields
- Accessibility: proper heading hierarchy, semantic markup
- Mobile responsive design works on various screen sizes
- Template processing handles edge cases (missing data, special characters)

## Success Metrics
- **Template Reusability**: Single template generates all poem pages consistently
- **Performance**: Template processing under 100ms per poem
- **Validity**: 100% valid HTML output
- **Accessibility**: Meets WCAG 2.1 AA standards
- **Maintainability**: Clear separation of template and data

## Dependencies
- Poem data from `assets/poems.json`
- Similarity data (when available)
- HTML validation tools

## Related Issues
- **Issue 001b**: URL Structure Design (dependent on template paths)
- **Issue 001c**: Similarity Navigation (uses template placeholders)

**ISSUE STATUS: COMPLETED** ✅

## Implementation Summary

**Completed on:** December 4, 2025

### ✅ Deliverables Completed:
1. **HTML Template System** (`templates/poem-page.html`):
   - Clean, semantic HTML5 structure
   - Inline CSS following project requirements (no external stylesheets)
   - Mobile-responsive design with proper viewport meta tag
   - Accessibility features (ARIA labels, semantic markup)
   - Support for golden poem indicators and character counts

2. **Template Processing Engine** (`src/html-generator/template-engine.lua`):
   - Lua-based template substitution system
   - HTML escaping for security and validity
   - Support for all required placeholders: title, content, breadcrumbs, golden indicators
   - Integration with existing project utilities and JSON library

3. **Testing and Validation**:
   - Automated template validation system
   - HTML structure validation
   - Special character escaping verification
   - Test file generation with sample poems

### ✅ Key Features Implemented:
- **Template Variables**: All placeholders working correctly
  - `{POEM_TITLE}`, `{POEM_CONTENT}`, `{BREADCRUMB_HTML}`
  - `{GOLDEN_POEM_INDICATOR}`, `{CHARACTER_COUNT_DISPLAY}`
  - `{SIMILAR_POEMS_SECTION}`
- **Security**: Proper HTML escaping prevents XSS issues
- **Accessibility**: Screen reader friendly, semantic HTML
- **Mobile Support**: Responsive design with mobile-first approach
- **Integration**: Works with existing poem data structure

### ✅ Quality Assurance Results:
- **HTML Validation**: Generated HTML passes structural validation
- **Template Processing**: Sub-100ms performance per poem
- **Security Testing**: Proper escaping of special characters verified
- **Integration Testing**: Successfully loads and processes poem data

### 📁 Files Created:
- `/templates/poem-page.html` - Base HTML template
- `/src/html-generator/template-engine.lua` - Template processing engine  
- `/libs/json.lua` - JSON wrapper for dkjson integration
- `/test-poem.html` - Generated test output

### 🔗 Ready for Integration:
This template system is now ready to be used by:
- **Issue 001b**: URL Structure Design (will use template paths)
- **Issue 001c**: Similarity Navigation (will integrate with template placeholders)
- **Issue 001d**: Responsive Design (template already includes mobile support)

**IMPLEMENTATION COMPLETE** 🎉