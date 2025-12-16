I've read the issue. This is a well-scoped bug fix that's already quite focused. Let me analyze whether splitting it would be beneficial.

## Analysis

This issue has **4 logical components**:

1. Modify `process_issue()` to append directly
2. Modify `review_root_issue()` to append directly  
3. Remove `OUTPUT_DIR` infrastructure
4. Add optional `--archive` flag

However, I **don't recommend splitting** this issue for these reasons:

### Why Not Split

1. **Tight coupling** - Components 1-3 are interdependent. You can't remove `OUTPUT_DIR` without first changing both functions. Doing them separately would leave the code in a broken intermediate state.

2. **Small scope** - The total change is likely ~50-80 lines of modification in a single file. This is well within the scope of a single focused work session.

3. **Atomic change** - The current/intended behavior describes one coherent transformation. Splitting would create artificial boundaries.

4. **Only one optional piece** - The `--archive` flag (step 4) is explicitly marked optional and could theoretically be a separate issue, but it's simple enough (~15 lines) that including it doesn't add significant complexity.

### If You Really Wanted to Split

The only reasonable split would be:

| ID | Name | Description |
|----|------|-------------|
| **001a** | `remove-intermediate-files` | Steps 1-3: Change both functions to append directly, remove OUTPUT_DIR |
| **001b** | `add-archive-flag` | Step 4: Add optional --archive flag for historical copies |

With **001b** depending on **001a**.

But even this feels like over-engineering for such a small change.

## Recommendation

**Keep as single issue.** Implement all 4 steps in one commit. The issue is already well-structured with clear acceptance criteria and implementation steps.
