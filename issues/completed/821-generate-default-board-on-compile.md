# 821 - Generate Default Board on Compile

## Current Behavior

The boards/ directory is tracked in git with board JSON files. This means:
- User-created boards get mixed with default boards in version control
- New installations already have boards, hiding the generation process
- The boards/ directory accumulates user experiments

## Intended Behavior

- The boards/ directory is gitignored (user-generated content)
- The compile script generates the default board if it doesn't exist
- First-time installations create their own boards/ directory
- Clean separation between tracked code and user-generated data

## Suggested Implementation Steps

1. Update scripts/compile to check for boards/stage1-default.json
2. If missing, create boards/ directory and generate default board JSON
3. Add boards/ to .gitignore
4. Remove existing boards from git tracking

## Files to Modify

- scripts/compile - Add board generation function
- .gitignore - Add boards/ entry

## Notes

The default board is a classic staggered peg grid:
- 14 columns, 10 rows
- 60px cell size
- Alternating row offsets for stagger effect
- Score zones at bottom row (10, 20, 30, 50, 100, 200, 500, 200, 100, 50, 30, 20, 10)
