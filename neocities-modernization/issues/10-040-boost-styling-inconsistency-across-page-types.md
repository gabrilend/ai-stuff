# Issue 10-040: Boost Styling Inconsistency Across Page Types

## Current Behavior

Fediverse_boost entries display with different visual styling depending on which page type they appear on:

### Chronological Pages (basic styling):
```
 -> file: fediverse_boost/6356
══════════════════════════════════════════════════════════════════════════════─────
 Story idea: God somehow exists and made Man in His image: filled with nasty
 impulses and faulty cognitive heuristics...
┌─────────┐                                                           ┌───────────┐
│ similar │                                                           │ different │
╘═════════╧═══════════════════════════════════════════════════════════╧═══════────┘
```

### Similar/Different Pages (boost box styling):
```
--- #3 fediverse_boost/6357 ---
◀─╔════════════════════════════════[BOOST]══════════════════════════════════─────╗
║ ┌────────────────────────────────────────────────────────────────────────────┐ ║
║ │ External post: https://tech.lgbt/users/paleblueyedot/statuses/115644789217659891 │ ║
║ └────────────────────────────────────────────────────────────────────────────┘ ║
╠─────────┐                                                            ┌───────────╣
║ similar │                       chronological                       │ different ║
╚═════════╧════════════════════════════════════════════════════════════╧══─────╝─▶
```

Boosts on chronological pages use the same styling as regular posts, while similar/different pages use the special [BOOST] box formatting with:
- Red arrows (◀─ and ─▶)
- Blue outer frame (╔═╗║╚═╝)
- Teal inner content box (┌─┐│└─┘)
- Yellow content text
- [BOOST] label in the top border

## Intended Behavior

Boost entries should use the distinctive [BOOST] box styling consistently across ALL page types:
- Chronological pages
- Similar pages
- Different pages
- Word pages (if boosts appear there)

The special boost styling serves to:
1. Visually distinguish shared content from original posts
2. Indicate the content is from another author
3. Provide consistent visual language across the entire site

## Investigation Notes

Looking at `src/flat-html-generator.lua`:
- Lines 2156-2200+ handle boost detection and formatting
- `is_boost_poem()` function checks `poem.metadata.is_boost`
- Boost formatting functions exist (generate_boost_top_border, etc.)

The issue may be:
1. Different code paths for chronological vs similar/different generation
2. `is_boost` check not being performed in chronological generation
3. Boost formatting functions not being called in chronological context

## Suggested Implementation Steps

1. **Trace code paths**: Identify where chronological page poem rendering occurs
   - Compare to similar/different page rendering
   - Find where `is_boost_poem()` check should be added

2. **Unify boost rendering**: Ensure same formatting functions are called:
   - `generate_boost_top_border()`
   - `generate_boost_content_line()`
   - `generate_boost_inner_box_top()`
   - `generate_boost_inner_box_bottom()`
   - `generate_boost_nav_separator()`
   - `generate_boost_nav_line()`
   - `generate_boost_bottom_border()`

3. **Test all page types**: Verify boost styling appears correctly on:
   - Chronological pages (main, paginated)
   - Similar pages
   - Different pages

4. **Visual regression check**: Ensure styling is consistent across all instances

## Related Files

- `src/flat-html-generator.lua:1526-1534` - is_boost_poem() function
- `src/flat-html-generator.lua:1811-2030` - Boost formatting functions
- `src/flat-html-generator.lua:2156-2200` - Boost rendering decision point
- `src/flat-html-generator.lua:3322-3604` - Worker thread boost handling

## Dependencies

- Should be addressed after 10-041 (malformed boost box formatting)
- Boost formatting functions need to be correct before propagating

---

**Priority**: Medium - Visual consistency issue

**Phase**: 10 - Developer Experience & Tooling
