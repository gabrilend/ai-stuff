I've read the issue. It already contains two sub-issue analysis sections (both generated previously), and they're essentially in agreement. Let me provide a clean recommendation.

## Analysis

This Phase 1 demo issue combines five distinct workstreams:

1. **Sample data creation** - Fabricated packet samples (raw binary + parsed Lua)
2. **Core visualizer** - TUI-based single packet display
3. **Comparison mode** - Side-by-side dual-packet view  
4. **Translation confidence coloring** - Visual mapping status indicators
5. **Demo packaging** - Runnable phase demo script

Each has clear boundaries and testable outcomes. The dependency chain is linear with one branch.

## Recommendation

**Yes, this issue should be split.** The existing analysis in the file is sound.

| ID | Name | Description |
|----|------|-------------|
| 501a | create-sample-packets | Create fabricated packet samples in assets/samples/ with raw .bin and parsed .lua representations for WoW and CoH movement packets |
| 501b | build-core-visualizer | Build TUI-based single-packet display using shared TUI library showing parsed fields in formatted box layout |
| 501c | add-comparison-mode | Implement side-by-side view showing WoW packet alongside CoH equivalent with field alignment |
| 501d | add-confidence-coloring | Color-code fields by translation confidence green for direct yellow for approximate red for unmapped |
| 501e | package-phase-demo | Create runnable demo script at issues/completed/demos/phase-1-demo.sh with success criteria documentation |

## Dependency Chain

```
501a ──> 501b ──> 501c ──┬──> 501e
                        │
              501d ─────┘
```

Note: The issue file already has this analysis embedded twice (from previous sessions). You may want to clean that up when creating the sub-issues - keep one canonical analysis section rather than duplicates.
