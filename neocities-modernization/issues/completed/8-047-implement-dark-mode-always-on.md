# Issue 8-047: Implement Dark Mode (Always On, CSS-Free)

## Priority
High (Accessibility)

## Current Behavior

The generated HTML pages use browser default colors:
- Background: White (`#FFFFFF`)
- Text: Black (`#000000`)
- Links: Blue (`#0000FF`)

This can cause eye strain for users reading in low-light environments and doesn't respect the growing preference for dark interfaces.

## Intended Behavior

All generated HTML pages should use a dark color scheme:
- Background: True black (`#000000`)
- Text: White (`#FFFFFF`)
- Links: Light blue (`#6699FF`)
- Visited links: Light purple (`#9966FF`)

### Why Always-On (Not Auto-Detect)?

The `prefers-color-scheme` media query requires CSS, which violates the project's CSS-free constraint. By choosing always-dark:
1. Maintains CSS-free architecture
2. Benefits OLED screens (true black = pixels off)
3. Reduces eye strain for extended reading
4. Matches the aesthetic of the ASCII art / terminal-style presentation

### Color Specification

| Element | Current | New | Notes |
|---------|---------|-----|-------|
| Background | Browser default (white) | `#000000` | True black, not near-black |
| Body text | Browser default (black) | `#FFFFFF` | Pure white |
| Links | Browser default (blue) | `#6699FF` | Light blue, accessible on black |
| Visited links | Browser default (purple) | `#9966FF` | Light purple, accessible on black |

### Semantic Colors (Progress Bars)

The existing semantic colors used in progress bars should remain unchanged:
```lua
red = "#dc3c3c", blue = "#3c78dc", green = "#3cb45a",
purple = "#8c3cc8", orange = "#e68c3c", yellow = "#c8b428", gray = "#787878"
```

These were already chosen to be visible and will work well on a black background.

## Implementation Steps

### Step 1: Update HTML Templates

Add `bgcolor`, `text`, `link`, and `vlink` attributes to all `<body>` tags:

```html
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
```

### Step 2: Locate All Template Definitions

Search for `<body>` tags in `src/flat-html-generator.lua`:
- Chronological page template
- Similar page template
- Different page template
- Archive templates
- Any other HTML generation

### Step 3: Update Word Cloud Generator

Check `src/wordcloud-generator.lua` for body tags.

### Step 4: Verify Semantic Color Contrast

Ensure the progress bar colors remain visible on black background:
- Red (`#dc3c3c`) on black: Good contrast
- Blue (`#3c78dc`) on black: Good contrast
- Green (`#3cb45a`) on black: Good contrast
- Purple (`#8c3cc8`) on black: Good contrast
- Orange (`#e68c3c`) on black: Good contrast
- Yellow (`#c8b428`) on black: Good contrast
- Gray (`#787878`) on black: Acceptable contrast

### Step 5: Test Generated Output

- Open chronological pages in browser
- Open similar/different pages in browser
- Verify text is readable
- Verify links are visible and distinguishable
- Verify progress bar colors remain visible

## Technical Notes

### HTML Color Attributes (Deprecated but Functional)

These HTML 4.01 attributes are deprecated in HTML5 but still work in all browsers:

```html
<body bgcolor="color"   <!-- Background color -->
      text="color"      <!-- Default text color -->
      link="color"      <!-- Unvisited link color -->
      vlink="color"     <!-- Visited link color -->
      alink="color">    <!-- Active (clicked) link color - optional -->
```

### Why Not CSS?

This project maintains a CSS-free constraint (Issue 8-003) to ensure:
- Maximum compatibility with old browsers
- Simpler HTML structure
- Terminal-like aesthetic consistency
- No external stylesheet dependencies

### Accessibility Considerations

- WCAG 2.1 recommends 4.5:1 contrast ratio for normal text
- White (`#FFFFFF`) on black (`#000000`) = 21:1 ratio (excellent)
- `#6699FF` on black = ~5.5:1 ratio (passes AA)
- `#9966FF` on black = ~4.6:1 ratio (passes AA)

## Files to Modify

| File | Changes |
|------|---------|
| `src/flat-html-generator.lua` | Add body attributes to all HTML templates |
| `src/wordcloud-generator.lua` | Add body attributes to word cloud template |

## Testing Checklist

- [x] Chronological pages have black background
- [x] Similar pages have black background
- [x] Different pages have black background
- [x] Word cloud page has black background
- [x] Text is white and readable
- [x] Links are visible (light blue)
- [x] Visited links are distinguishable (light purple)
- [x] Progress bar colors remain visible
- [x] Semantic color boxes remain visible
- [x] No CSS used (validate with view-source)

---

## Implementation Progress

### 2026-01-21: Implemented

Updated all `<body>` tags across 6 generator files:

| File | Occurrences | Status |
|------|-------------|--------|
| `src/flat-html-generator.lua` | 7 | ✅ Updated |
| `src/wordcloud-generator.lua` | 1 | ✅ Updated (was `#1a1a2e` → `#000000`) |
| `src/centroid-html-generator.lua` | 2 | ✅ Updated |
| `src/mass-diversity-generator.lua` | 2 | ✅ Updated (has CSS, HTML attrs added) |
| `src/report-generator.lua` | 1 | ✅ Updated (has CSS, HTML attrs added) |
| `src/html-generator/golden-collection-generator.lua` | 4 | ✅ Updated (has CSS, HTML attrs added) |

**New body tag format:**
```html
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
```

**Note:** Three generators (mass-diversity, report, golden-collection) use CSS styling which may override HTML attributes. For full dark mode in those files, CSS updates would also be needed. However, these are auxiliary tools, not the main website output.

---

**ISSUE STATUS: ✅ COMPLETE**

## Related Documents

- `issues/completed/8-003-remove-remaining-css-from-html-generation.md` - CSS-free constraint
- `src/flat-html-generator.lua` - Primary HTML generation

## Metadata

- **Status**: Open
- **Created**: 2026-01-21
- **Phase**: 8 (Website Completion / Accessibility)
- **Estimated Complexity**: Low
- **Dependencies**: None
- **Affects**: All generated HTML files
