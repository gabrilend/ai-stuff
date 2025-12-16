# Issue 001: Implement HTML Generation System

## Current Behavior
- No HTML generation system exists
- Similarity engine produces data but no web interface
- Poems exist only as JSON data without presentation layer
- No navigation system between related poems

## Intended Behavior
- Generate static HTML pages for each poem
- Create similarity-based poem recommendation system
- Implement hierarchical URL structure and navigation
- Provide clean, readable presentation of poetry content
- Enable discovery of related poems through similarity links

## Suggested Implementation Steps
1. **HTML Template System**: Create reusable templates for poem pages
2. **URL Structure Design**: Implement clean, hierarchical URL scheme
3. **Similarity Integration**: Use similarity matrix for poem recommendations
4. **Navigation System**: Create links between related poems
5. **Index Pages**: Generate category and similarity-based index pages
6. **Static File Organization**: Organize output for easy deployment

## Technical Requirements

### **HTML Template System**
```lua
-- {{{ local function generate_poem_html
local function generate_poem_html(poem, similar_poems, template_path)
    local template = utils.read_file(template_path)
    
    -- Substitute poem content
    template = template:gsub("{POEM_TITLE}", poem.title or "Untitled")
    template = template:gsub("{POEM_CONTENT}", poem.content)
    template = template:gsub("{POEM_ID}", poem.id)
    
    -- Generate similar poems section
    local similar_html = ""
    for _, similar in ipairs(similar_poems) do
        similar_html = similar_html .. string.format(
            '<li><a href="%s">%s</a> (%.2f similarity)</li>',
            similar.url, similar.title, similar.score
        )
    end
    template = template:gsub("{SIMILAR_POEMS}", similar_html)
    
    return template
end
-- }}}
```

### **URL Structure Design**
```
Generated Structure:
poems/
├── index.html                    # Main poetry index
├── by-similarity/
│   ├── index.html               # Similarity-based browsing
│   ├── poem-001.html           # Individual poem pages
│   ├── poem-002.html
│   └── ...
├── by-category/                 # Future: category-based organization
└── search/                      # Future: search functionality
```

### **Similarity-Based Recommendations**
```lua
-- {{{ function generate_recommendations
function generate_recommendations(poem_id, similarity_matrix, poems_data, count)
    count = count or 5
    
    local recommendations = {}
    local current_similarities = similarity_matrix.data[poem_id]
    
    if current_similarities then
        -- Sort by similarity score
        local sorted_pairs = {}
        for other_id, score in pairs(current_similarities) do
            if other_id ~= poem_id then
                table.insert(sorted_pairs, {id = other_id, score = score})
            end
        end
        
        table.sort(sorted_pairs, function(a, b) return a.score > b.score end)
        
        -- Get top recommendations
        for i = 1, math.min(count, #sorted_pairs) do
            local rec = sorted_pairs[i]
            local poem = poems_data.poems[rec.id]
            if poem then
                table.insert(recommendations, {
                    id = rec.id,
                    title = poem.title or ("Poem " .. rec.id),
                    url = string.format("poem-%03d.html", rec.id),
                    score = rec.score
                })
            end
        end
    end
    
    return recommendations
end
-- }}}
```

## User Experience Improvements

### **Enhanced Navigation**
```html
<!-- Poem page template -->
<nav class="poem-navigation">
    <div class="breadcrumb">
        <a href="../../index.html">Poetry</a> > 
        <a href="../index.html">By Similarity</a> > 
        <span>Current Poem</span>
    </div>
    
    <div class="poem-controls">
        <button onclick="randomPoem()">Random Poem</button>
        <button onclick="toggleSimilarity()">Show Similar</button>
    </div>
</nav>

<main class="poem-content">
    <h1>{POEM_TITLE}</h1>
    <div class="poem-text">{POEM_CONTENT}</div>
    
    <aside class="similar-poems">
        <h3>Similar Poems</h3>
        <ul>{SIMILAR_POEMS}</ul>
    </aside>
</main>
```

### **Responsive Design**
```css
/* Mobile-first responsive design */
.poem-content {
    max-width: 800px;
    margin: 0 auto;
    padding: 1rem;
    line-height: 1.6;
}

.poem-text {
    font-family: 'Georgia', serif;
    font-size: 1.1rem;
    white-space: pre-line;
    margin-bottom: 2rem;
}

.similar-poems {
    background: #f5f5f5;
    padding: 1rem;
    border-radius: 8px;
}

@media (min-width: 768px) {
    .poem-content {
        padding: 2rem;
    }
}
```

## Quality Assurance Criteria
- All poems have generated HTML pages with proper formatting
- Similarity recommendations are accurate and relevant
- Navigation between poems works correctly
- URLs are clean and hierarchical
- HTML validates and renders properly across browsers
- Mobile-responsive design works on various screen sizes

## Success Metrics
- **Coverage**: 100% of poems have generated HTML pages
- **Performance**: Pages load quickly (< 2 seconds)
- **Accessibility**: HTML validates and meets accessibility standards
- **Usability**: Navigation between similar poems is intuitive
- **Integration**: Clean deployment to neocities platform

## Edge Cases Handled
- **Missing Similarity Data**: Graceful degradation when no similar poems found
- **Special Characters**: Proper HTML escaping of poem content
- **Long Poems**: Responsive handling of varying poem lengths
- **Broken Links**: Validation of all generated links
- **File System Limits**: Handling of filename restrictions

## Implementation Validation
1. Generate HTML for sample poems with similarity data
2. Test navigation between related poems
3. Validate HTML markup and CSS rendering
4. Test responsive design on mobile devices
5. Verify deployment compatibility with neocities
6. Performance test with full poem dataset

**USER REQUEST FULFILLMENT:**
This ticket addresses the user's requirement for:
1. ✅ HTML generation system for poem presentation
2. ✅ Similarity-based poem recommendations
3. ✅ Clean URL structure and navigation
4. ✅ Static file organization for deployment

## Implementation Completed

### Sub-Issues Successfully Completed
All sub-issues for this parent issue have been completed:

- ✅ **001a**: HTML template system (`001a-create-html-template-system.md`) 
- ✅ **001b**: URL structure design (`001b-implement-url-structure-design.md`)
- ✅ **001c**: Similarity navigation (`001c-build-similarity-navigation.md`)
- ✅ **001d**: Responsive design implementation (`001d-responsive-design-implementation.md`)

### System Status
The complete HTML generation system is operational with:
- ✅ HTML template system for individual poem pages
- ✅ Clean, hierarchical URL structure 
- ✅ Similarity-based poem recommendations and navigation
- ✅ Mobile-first responsive design
- ✅ Static file organization for deployment

### Integration Results
- **Foundation Complete**: HTML generation system fully operational
- **Template System**: Reusable templates for consistent poem presentation
- **Navigation**: Similarity-based discovery between related poems
- **Responsive Design**: Cross-device compatibility achieved
- **Deployment Ready**: Static files organized for neocities hosting

**ISSUE STATUS: COMPLETED** ✅

**Completion Date**: December 4, 2025  
**Implementation Approach**: Successfully broken down into manageable sub-issues
**Quality**: All technical requirements fulfilled through sub-issue implementations