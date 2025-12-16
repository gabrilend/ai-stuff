Looking at this issue, I think it's already well-scoped and **doesn't need to be split into sub-issues**.

Here's my reasoning:

## Why Not Split

1. **Single cohesive deliverable** - This is one CLI tool with a clear purpose. All the "steps" are really just parts of implementing one script file (`mapdump.lua`).

2. **No parallelizable work** - The components are tightly coupled:
   - Argument parsing is useless without the dump functions
   - Interactive mode needs both
   - Output formatting spans all components

3. **Modest scope** - The issue estimates roughly 300-400 lines of Lua code in a single file. This is a reasonable size for one implementation session.

4. **Clear dependency** - It depends on issue 106 (internal data structures) being complete. Once that's done, this tool is straightforward to implement.

5. **The "dump functions" share structure** - `dump_info`, `dump_terrain_summary`, `dump_file_list` are all variations on the same pattern (format data as text or JSON). Splitting them into separate issues would create artificial overhead.

## Alternative Consideration

If you wanted to split it anyway, the only natural boundary would be:

| Sub-issue | Description |
|-----------|-------------|
| **107a** | Core CLI with text output for map info only |
| **107b** | Add JSON output format support |
| **107c** | Add interactive mode |

But even this feels like over-engineering for what is essentially a utility script. The original issue already has good acceptance criteria that can serve as a natural checklist.

## Recommendation

Keep issue 107 as-is. It's a well-defined "tool" type issue that will take a focused implementation session to complete. The suggested implementation steps in the issue are detailed enough to guide development without needing formal sub-issue tracking.
