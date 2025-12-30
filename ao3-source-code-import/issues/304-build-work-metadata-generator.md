# 304: Build Work Metadata Generator

## Status
- [ ] Not started

## Current Behavior

No work metadata generation exists.

## Intended Behavior

A Lua module that:
- Generates AO3 work metadata from project info
- Creates title (project name + version/date)
- Creates summary (from README/vision)
- Suggests appropriate tags
- Generates author's notes (from git log summary)
- Sets appropriate ratings and warnings

## Default Metadata Template

```
Title: world-edit-to-execute (v2024.12.29)
Rating: General Audiences
Warnings: No Archive Warnings Apply
Fandom: Original Work
Category: Gen
Characters: (none)
Relationships: (none)
Additional Tags: Software, Source Code, Lua, Game Development,
                 Warcraft III, Code Preservation, LLM Collaboration
Summary: [Generated from README/vision]
Notes: [Git log summary, contributors]
```

## Suggested Implementation Steps

1. Create src/metadata-generator.lua
2. Build title from project name + timestamp
3. Extract summary from project docs
4. Build tag list from file types and content analysis
5. Generate author's notes from git history
6. Create complete metadata structure for upload

## Related Documents

- 103-research-work-creation-form.md
- 204-build-project-metadata-parser.md

## Notes

Tags make the work findable. Think about what someone searching for code archives would look for.
