# Issue 8-030: Add Chronological Anchor Links to Poem Navigation

## Current Behavior

Each poem displayed on similarity/diversity pages has two navigation links:
- **similar** → links to `similar/{category}-{id}.html`
- **different** → links to `different/{category}-{id}.html`

```
┌─────────┐                                                          ┌───────────┐
│ similar │                                                          │ different │
╘═════════╧══════════════════════════════════════════════════════════╧═══════════╛
```

Users currently have no way to:
1. See where a poem appears in the chronological timeline
2. Navigate from a similarity/diversity page back to the main chronological view
3. Understand the temporal context of a poem they're reading

## Intended Behavior

Add a third navigation option: **chronological** that links to `chronological.html` with an anchor that scrolls directly to that poem's position.

```
┌─────────┐                     ┌──────────────┐                     ┌───────────┐
│ similar │                     │ chronological │                     │ different │
╘═════════╧═════════════════════╧══════════════╧═════════════════════╧═══════════╛
```

When clicked:
- Navigates to `chronological.html#poem-{category}-{id}`
- Browser scrolls to show that poem in the chronological list
- User can see surrounding poems (temporal neighbors)

## Implementation Steps

### Step 1: Add anchor IDs to chronological.html
- [ ] Each poem in chronological.html needs an anchor ID
- [ ] Format: `id="poem-{category}-{id}"` (e.g., `id="poem-fediverse-0042"`)
- [ ] Add to the poem separator line or a wrapper element
- [ ] Ensure IDs are unique (category-id format guarantees this)

### Step 2: Update poem navigation template
- [ ] Add "chronological" link between "similar" and "different"
- [ ] Link format: `chronological.html#poem-{category}-{id}`
- [ ] Update box-drawing layout to accommodate third link
- [ ] Maintain visual symmetry (chronological centered between similar/different)

### Step 3: Update box-drawing characters
Current layout uses 84-character width. New layout options:

**Option A: Three equal boxes**
```
┌─────────┐               ┌──────────────┐               ┌───────────┐
│ similar │               │ chronological │               │ different │
```

**Option B: Chronological as center text (no box)**
```
┌─────────┐                   chronological                   ┌───────────┐
│ similar │                                                   │ different │
```

### Step 4: Test anchor scrolling
- [ ] Verify anchors work in major browsers (Firefox, Chrome)
- [ ] Ensure scroll position places poem visibly (not at very bottom)
- [ ] Test with poems at start, middle, and end of chronological list

## Technical Notes

### Anchor ID Format
Using `poem-{category}-{id}` format ensures uniqueness:
- `poem-fediverse-0042`
- `poem-messages-0767`
- `poem-notes-what-a-lame-movie`

### HTML Anchor Syntax
```html
<!-- In chronological.html -->
<span id="poem-fediverse-0042"></span>
 -> file: fediverse/42.txt
═══════════════════════════════════════════════════════════════════════════════════
  poem content here...

<!-- In similar/fediverse-0042.html -->
<a href='chronological.html#poem-fediverse-0042'>chronological</a>
```

### Pure HTML Requirement
- No JavaScript for scrolling (use native anchor behavior)
- No CSS for scroll padding (browser handles positioning)
- Link is standard `<a href="">` tag

## Quality Assurance Criteria

- [ ] Every poem in similar/*.html has chronological link
- [ ] Every poem in different/*.html has chronological link
- [ ] Clicking chronological link scrolls to correct poem
- [ ] Anchor IDs are valid HTML (no spaces, special chars escaped)
- [ ] Visual layout is balanced and readable
- [ ] Box-drawing characters align correctly

## Related Issues

- **Issue 8-007**: Box-drawing borders around navigation links (COMPLETED)
- **Issue 8-001**: Unified website generation pipeline
- **Issue 8-012**: Paginated similarity chapters (may need pagination anchors)

## Notes

This feature helps users understand poems in context:
- "This melancholy poem was written right after a joyful one"
- "These similar poems were actually written years apart"
- "This poet's style evolved - see the chronological neighbors"

The chronological view becomes an anchor point users can always return to.

---

**ISSUE STATUS: OPEN**

**Created**: 2026-01-04
**Phase**: 8 (Website Completion)
**Priority**: Medium (navigation enhancement)
