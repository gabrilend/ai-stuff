# 609 - Separate Player and Adversary Scores

## Status: completed

## Depends on

None - can be implemented independently.

## Problem

The adversary's score is either not tracked or not displayed. Both players' scores should be visible and separate in the stats menu.

## Current Behavior

- Player score displayed in top-left stats panel
- Adversary score not displayed (or not tracked)
- No way to compare player vs adversary performance

## Intended Behavior

- Both scores displayed separately in stats panel
- Clear visual distinction between player and adversary
- Running comparison during gameplay

### Stats Panel Layout

```
┌─────────────────────┐
│ PLAYER        1,250 │  ← Player score (top, friendly color)
│ ADVERSARY       890 │  ← Adversary score (below, different color)
├─────────────────────┤
│ Credits: 2.3        │
│ Balls: 47           │
└─────────────────────┘
```

Or side-by-side:

```
┌─────────────────────────────┐
│  YOU: 1,250  │  THEM: 890   │
├─────────────────────────────┤
│ Credits: 2.3   Balls: 47    │
└─────────────────────────────┘
```

## Implementation

```c
typedef struct GameScore {
    int player_score;
    int adversary_score;
} GameScore;

// When ball enters score zone
void on_ball_score(Ball* ball, Zone* zone) {
    int points = zone->points * zone->multiplier;

    if (ball->owner == OWNER_PLAYER) {
        game_score.player_score += points;
    } else if (ball->owner == OWNER_ADVERSARY) {
        game_score.adversary_score += points;
    }
}

// Render both scores
void render_score_panel(void) {
    // Player score (blue/green)
    DrawText("YOU:", 10, 10, 20, SKYBLUE);
    DrawText(format_number(game_score.player_score), 70, 10, 20, WHITE);

    // Adversary score (red/orange)
    DrawText("THEM:", 10, 35, 20, ORANGE);
    DrawText(format_number(game_score.adversary_score), 80, 35, 20, WHITE);
}
```

## Files to Modify

- `src/001-main.c` - Add adversary_score tracking, update rendering
- Score zone collision handling (wherever that lives)

## Notes

- Consider adding "lead" indicator (arrow or highlight on winning score)
- Could add point difference display: "+360" or "-120"
- Sound effect when adversary scores? Visual flash?
- End-game summary showing final scores

## Completion Notes

**Implemented 2026-03-19**

### Changes Made

1. **src/004-world.h** - Added `adversary_score` field to World struct alongside existing `score` field

2. **src/006-ball.h** - Added `ball_manager_collect_scores_split()` function declaration to separate score collection by ball owner

3. **src/007-ball.c** - Implemented `ball_manager_collect_scores_split()` which iterates task data and separates points by checking `balls_current[i].owner` (OWNER_PLAYER vs OWNER_ADVERSARY)

4. **src/001-main.c**:
   - Changed score collection from single total to split by owner
   - Updated score panel UI to show "YOU:" (SKYBLUE) and "THEM:" (ORANGE)
   - Added adversary_score reset on R key press

### UI Layout

Used the side-by-side format from the issue spec:
```
YOU: 1250    (SKYBLUE)
THEM: 890    (ORANGE)
```

### Future Enhancements

The notes section items (lead indicator, point difference, sound effects) were deferred as nice-to-haves for a future polish pass.
