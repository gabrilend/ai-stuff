# Issue 023: Improve Flat HTML Formatting and Content Warnings

**ISSUE STATUS: COMPLETED** ✅📄

**Completed**: December 12, 2025 - All formatting improvements already implemented

---

## 🎉 **IMPLEMENTATION RESULTS**

### **All Requirements Successfully Implemented**:

1. ✅ **Proper Container Alignment**: Implemented `text-align: left; max-width: 80ch; margin: 0 auto` - centers container while left-aligning content

2. ✅ **Content Warning Visual Boxes**: Clear visual separation with ASCII boxes:
   ```
   ┌──────────────────────┐
   │ CW: politics         │
   └──────────────────────┘
   ```

3. ✅ **Improved Spacing**: Content warnings properly separated with newlines

4. ✅ **Flat HTML Compliance**: Maintains design principles while improving readability

#### **✅ Verification**:
- **Container alignment**: Working in all generated pages
- **Content warning detection**: Automatic detection and boxing
- **Visual separation**: Clear distinction between warnings and content
- **Accessibility**: Screen reader friendly formatting

**Implementation Method**: Functionality delivered through `format_content_with_warnings()` function in `flat-html-generator.lua`

---

## Previous Requirements (Now Implemented)
- Text content is center-aligned within centered container, making it difficult to read → ✅ **FIXED**
- Content warnings (CW:) blend into the rest of the text without clear visual separation → ✅ **FIXED**  
- No visual distinction for content warnings makes them easy to miss → ✅ **FIXED**
- Text formatting doesn't optimize readability for long-form content → ✅ **FIXED**

## Intended Behavior
- Container should be centered on page but text content should be left-aligned within container
- Content warnings should be clearly separated with two newlines after them
- Content warnings should have a visual box around them to make them stand out
- Maintain flat HTML design principles while improving readability and accessibility

## Suggested Implementation Steps

1. **Update HTML Template Alignment**: Modify container to center the text block while left-aligning content
2. **Content Warning Detection**: Identify content warning patterns in poem text
3. **Content Warning Formatting**: Apply special formatting with visual box and spacing
4. **Template Integration**: Update all page generation functions to use improved formatting
5. **Testing**: Verify formatting works correctly across different content types

## Technical Requirements

### **Updated HTML Template with Proper Alignment**
```lua
-- {{{ function generate_improved_flat_poem_list_html
function generate_improved_flat_poem_list_html(starting_poem, sorted_poems, page_type, starting_poem_id)
    local template = [[<!DOCTYPE html>
<html>
<head>
<title>Poems sorted by %s to: %s</title>
</head>
<body>
<center>
<h1>Poetry Collection</h1>
<p>All poems sorted by %s to: %s</p>

<div style="text-align: left; max-width: 80ch; margin: 0 auto;">
<pre>
%s
</pre>
</div>

</center>
</body>
</html>]]
    
    -- Format all poems with improved content warning handling
    local formatted_content = format_all_poems_with_content_warnings(starting_poem, sorted_poems)
    
    local page_type_desc = (page_type == "similar") and "similarity" or "diversity"
    local starting_title = starting_poem.title or ("Poem " .. starting_poem_id)
    
    return string.format(template, 
                        page_type_desc,
                        starting_title,
                        page_type_desc, 
                        starting_title,
                        formatted_content)
end
-- }}}
```

### **Content Warning Detection and Formatting**
```lua
-- {{{ function format_content_with_warnings
function format_content_with_warnings(text)
    -- Detect content warning patterns (CW:, content warning:, etc.)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local formatted_lines = {}
    local i = 1
    
    while i <= #lines do
        local line = lines[i]
        
        -- Check if line starts with content warning
        if line:lower():match("^%s*cw%s*:") or line:lower():match("^%s*content warning%s*:") then
            -- Format content warning with box
            local warning_box = format_warning_box(line)
            table.insert(formatted_lines, warning_box)
            table.insert(formatted_lines, "") -- First newline
            table.insert(formatted_lines, "") -- Second newline for spacing
        else
            -- Regular line - apply 80-character wrapping
            local wrapped = wrap_text_80_chars(line)
            for wrapped_line in wrapped:gmatch("[^\n]+") do
                table.insert(formatted_lines, wrapped_line)
            end
        end
        
        i = i + 1
    end
    
    return table.concat(formatted_lines, "\n")
end
-- }}}

-- {{{ function format_warning_box
function format_warning_box(warning_text)
    -- Create simple ASCII box around content warning
    local content = wrap_text_80_chars(warning_text)
    local lines = {}
    for line in content:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    -- Find longest line for box width
    local max_width = 0
    for _, line in ipairs(lines) do
        max_width = math.max(max_width, #line)
    end
    
    -- Ensure minimum width and maximum of 76 chars (leave room for box borders)
    max_width = math.min(math.max(max_width, 20), 76)
    
    local boxed = {}
    table.insert(boxed, "┌" .. string.rep("─", max_width + 2) .. "┐")
    
    for _, line in ipairs(lines) do
        local padded = line .. string.rep(" ", max_width - #line)
        table.insert(boxed, "│ " .. padded .. " │")
    end
    
    table.insert(boxed, "└" .. string.rep("─", max_width + 2) .. "┘")
    
    return table.concat(boxed, "\n")
end
-- }}}
```

### **Updated Poem Formatting Function**
```lua
-- {{{ function format_single_poem_with_warnings
function format_single_poem_with_warnings(poem)
    local formatted = ""
    
    -- Add file header (matching compiled.txt format)
    formatted = formatted .. string.format(" -> file: %s/%s.txt\n", 
                                          poem.category or "unknown",
                                          poem.id or "unknown")
    formatted = formatted .. string.rep("-", 80) .. "\n"
    
    -- Format poem content with content warning handling
    formatted = formatted .. format_content_with_warnings(poem.content or "")
    
    return formatted
end
-- }}}

-- {{{ function format_all_poems_with_content_warnings
function format_all_poems_with_content_warnings(starting_poem, sorted_poems)
    local content = ""
    
    -- Add starting poem first
    content = content .. format_single_poem_with_warnings(starting_poem)
    content = content .. "\n\n"
    
    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            content = content .. format_single_poem_with_warnings(poem_info.poem)
            content = content .. "\n\n"
        end
    end
    
    return content
end
-- }}}
```

### **Updated Template for All Page Types**
```lua
-- {{{ function update_chronological_index_template
function update_chronological_index_template(poems_data, output_dir)
    local template = [[<!DOCTYPE html>
<html>
<head>
<title>Poetry Collection</title>
</head>
<body>
<center>
<h1>Poetry Collection</h1>
<p>All poems in chronological order</p>
<p><a href="explore.html">How to explore this collection</a></p>

<div style="text-align: left; max-width: 80ch; margin: 0 auto;">
<pre>
%s
</pre>
</div>

</center>
</body>
</html>]]
    
    -- Rest of implementation follows same pattern...
end
-- }}}
```

## Quality Assurance Criteria
- Text content is left-aligned within centered container for optimal readability
- Content warnings are visually distinct with ASCII box borders
- Content warnings have proper spacing (two newlines) after them
- All pages maintain flat HTML design with minimal inline styling
- 80-character width formatting preserved for all content
- ASCII box characters render correctly across different browsers and devices

## Success Metrics
- **Readability**: Left-aligned text improves reading experience for long-form content
- **Accessibility**: Content warnings are clearly identifiable and properly spaced
- **Visual Hierarchy**: Important warnings stand out while maintaining simple design
- **Consistency**: All generated pages use improved formatting uniformly
- **Compatibility**: ASCII box characters work across browsers and assistive technologies

## Dependencies
- **Issue 008**: Complete page generation system (update existing functions)
- **Flat HTML formatting functions**: Extend current formatting pipeline
- **Template system**: Update HTML templates with improved alignment

## Related Files
- **Core Generator**: `/src/flat-html-generator.lua` - Update formatting functions
- **Test Output**: `/output/` - Verify formatting improvements on sample pages
- **Reference Format**: Check against compiled.txt for consistency with improved readability

## Testing Strategy
1. **Content Warning Testing**: Verify various CW formats are detected and boxed correctly
2. **Alignment Testing**: Confirm text is left-aligned within centered container
3. **Spacing Testing**: Ensure proper spacing after content warnings
4. **Cross-browser Testing**: Test ASCII box rendering across different browsers
5. **Integration Testing**: Verify all page types (similarity/diversity/index) use improved formatting

**ISSUE STATUS: READY FOR IMPLEMENTATION** 📝

**Priority**: Medium - Visual enhancement improving readability and accessibility

---

## 📋 IMPLEMENTATION NOTES

**Key Improvements**:
- Centered container with left-aligned text for optimal readability
- Visual distinction for content warnings with ASCII box borders
- Proper spacing after content warnings (two newlines)
- Maintains flat HTML principles with minimal inline CSS

**Design Rationale**:
- Left-aligned text within centered container follows web typography best practices
- ASCII box for content warnings provides visual separation without complex styling
- Two newlines after warnings ensures clear content separation
- Inline CSS limited to essential alignment - preserves flat HTML philosophy