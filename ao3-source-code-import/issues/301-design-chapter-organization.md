# 301: Design Chapter Organization Strategy

## Status
- [ ] Not started

## Current Behavior

No chapter organization strategy defined.

## Intended Behavior

A clear scheme for how source code becomes chapters:

### Proposed Structure

1. **Chapter 1: Overview** - Project summary, vision, README
2. **Chapter 2: Architecture** - Directory structure, file manifest
3. **Chapters 3-N: Source Code** - One chapter per major module/directory
4. **Chapter N+1: Documentation** - docs/ contents
5. **Chapter N+2: Issue History** - Completed issues as development log
6. **Chapter N+3: Git Log** - Commit history
7. **Final Chapters: Transcripts** - LLM development conversations

### Alternative Structures

- One chapter per file (may be too granular)
- One chapter per phase (groups by development timeline)
- Flat structure with dividers (simpler but less navigable)

## Suggested Implementation Steps

1. Analyze world-edit-to-execute structure
2. Determine natural chapter boundaries
3. Document the chapter mapping rules
4. Create configuration option for structure choice
5. Update docs/code-to-html-spec.md with decisions

## Related Documents

- docs/code-to-html-spec.md
- 201-build-directory-scanner.md
- 205-include-llm-transcripts.md

## Notes

AO3 works can have unlimited chapters. Balance between granularity (findability) and coherence (readability as a whole).
