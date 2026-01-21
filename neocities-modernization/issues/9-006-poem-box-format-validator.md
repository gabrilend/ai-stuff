# Issue 9-006: Poem Box Format Validator

## Current Behavior

Poem box formatting is manually verified by visual inspection. Formatting errors (wrong character counts, missing junction characters, misaligned elements) are discovered late in development.

## Intended Behavior

A programmatic validator that checks character counts and structure for each line of a formatted poem box:

### Expected Structure (Regular Poems - 82 chars)
```
═══════════════════════════════════════════════════════════════────────────────────  (82 chars: progress bar)
 content line 1 (up to 80 chars)
 content line 2
┌─────────┐                                                            ┌───────────┐  (82 chars: 11 + 58 + 13)
│ similar │                      chronological                         │ different │  (82 visible chars)
╘═════════╧══════════════════════════════════════════════════──────────┴───────────┘  (84 chars with corners)
```

### Validation Rules
1. **Top progress bar**: Exactly 82 characters (═ and ─ only)
2. **Content lines**: Start with single space, up to 80 chars content
3. **Nav top line**: Exactly 82 chars (11 + 58 spaces + 13)
4. **Nav middle line**: 82 visible chars (excluding HTML tags)
5. **Bottom line**: 84 chars total (╘ + 82 interior + ┘), with junctions at positions 10 and 69

### Junction Character Rules
- Position 10: ╧ if in progress section, ┴ if in remaining section
- Position 69: ╧ if in progress section, ┴ if in remaining section

## Suggested Implementation Steps

1. Create `validate_poem_box_format(formatted_output)` function
2. Strip HTML tags for visible character counting
3. Check each line type against expected character count
4. Verify junction characters at correct positions
5. Return validation report with line-by-line results
6. Optionally integrate into HTML generation pipeline for automatic validation

## Example Validation Output
```
Line 1 (progress bar): 82 chars - OK
Line 2 (content): 45 chars - OK
Line 3 (nav top): 82 chars - OK
Line 4 (nav mid): 82 visible chars - OK
Line 5 (bottom): 84 chars - OK
  - Left junction at 10: ╧ (in progress) - OK
  - Right junction at 69: ┴ (in remaining) - OK
```

## Related Documents

- Issue 9-003: HTML Rendering and Performance Fixes (formatting fixes)

## Priority

Medium - Useful for development and preventing regression.

## Implementation Notes

### Character Count Reference
- Regular poem width: 82 chars interior
- Golden poem width: 84 chars interior (with ╔ and ┐/┤ borders)
- Progress bar: 82 chars (═ for progress, ─ for remaining)
- Nav box left: 11 chars (┌─────────┐ or │ similar │)
- Nav box right: 13 chars (┌───────────┐ or │ different │)
- Nav box gap: 58 chars (for regular) or 60 chars (for golden)
