# 705 - Stage 2 Ramp Layout Design

## Current Behavior

No stage 2 exists. Stage 1 (the original board) is a simple staggered peg grid.

## Intended Behavior

Stage 2 is the first purchasable expansion stage. It features a ramp-based layout that guides balls left and right across the stage before funneling them toward the center for the drop to the next gate row.

**Design goals:**
- Create interesting horizontal ball movement
- Extend ball travel time (more time on screen = more engagement)
- Funnel balls toward center gates (higher value)
- Mirrored layout for player and adversary

**Layout concept (top to bottom for player stage 2):**

```
   [From stage 1 gates]
         |   |   |
    /----+   |   +----\      <- Outer ramps catch edge balls
   /         |         \
  /   /------+------\   \    <- Inner ramps redirect center
 /   /       |       \   \
|   /   /----+----\   \   |  <- Zigzag pattern
|  /   /     |     \   \  |
| /   /      V      \   \ |
|/   /    [DROP]     \   \|  <- Center drop zone
    [To stage 2 gates]
```

**Ramp configuration:**
- Stage height: ~200 pixels (shorter than peg stage)
- 6-8 ramps per stage arranged in converging pattern
- Alternating left/right directions create zigzag path
- Center "funnel" area with no ramps for final drop

## Suggested Implementation Steps

### Step 1: Define stage 2 constants

```c
#define STAGE_2_HEIGHT 200.0f
#define STAGE_2_RAMP_COUNT 8
#define STAGE_2_RAMP_WIDTH 120.0f
#define STAGE_2_RAMP_HEIGHT 40.0f
```

### Step 2: Ramp layout generator

```c
void stage_generate_ramps_stage2(Stage* stage, float table_x, float table_width) {
    stage->ramp_count = STAGE_2_RAMP_COUNT;
    stage->ramps = malloc(sizeof(Ramp) * stage->ramp_count);

    float center_x = table_x + table_width / 2.0f;
    float y = stage->y_top + 20.0f;

    // Row 1: Outer catchers (2 ramps pointing inward)
    stage->ramps[0] = ramp_create(
        table_x + 20.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_RIGHT
    );
    stage->ramps[1] = ramp_create(
        table_x + table_width - 20.0f - STAGE_2_RAMP_WIDTH, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_LEFT
    );

    y += 50.0f;

    // Row 2: Inner redirectors (2 ramps, alternating)
    stage->ramps[2] = ramp_create(
        center_x - STAGE_2_RAMP_WIDTH - 40.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_LEFT
    );
    stage->ramps[3] = ramp_create(
        center_x + 40.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_RIGHT
    );

    y += 50.0f;

    // Row 3: Zigzag (4 ramps creating crossing pattern)
    float spacing = table_width / 5.0f;
    stage->ramps[4] = ramp_create(
        table_x + spacing * 0.5f, y,
        80.0f, 30.0f, RAMP_RIGHT
    );
    stage->ramps[5] = ramp_create(
        table_x + spacing * 1.5f, y,
        80.0f, 30.0f, RAMP_LEFT
    );
    stage->ramps[6] = ramp_create(
        table_x + spacing * 2.5f, y,
        80.0f, 30.0f, RAMP_RIGHT
    );
    stage->ramps[7] = ramp_create(
        table_x + spacing * 3.5f, y,
        80.0f, 30.0f, RAMP_LEFT
    );

    // Center drop zone is empty - balls fall through naturally
}
```

### Step 3: Mirrored layout for adversary

For adversary stage 2, the layout is vertically mirrored:
- Ramps point opposite directions (left becomes right)
- Y coordinates are flipped within stage bounds
- Balls travel upward through the stage

```c
void stage_generate_ramps_stage2_mirrored(Stage* stage, float table_x,
                                          float table_width) {
    // Similar to above but with:
    // - RAMP_LEFT and RAMP_RIGHT swapped
    // - y positions calculated from y_bottom upward
    // - Ramp heights negated for upward slope
}
```

### Step 4: Stage 2 creation function

```c
Stage* stage_create_type2(float y_top, float table_x, float table_width,
                          int is_adversary) {
    Stage* stage = malloc(sizeof(Stage));
    stage->type = STAGE_TYPE_RAMPS;
    stage->y_top = y_top;
    stage->height = STAGE_2_HEIGHT;
    stage->y_bottom = y_top + STAGE_2_HEIGHT;

    stage->pegs = NULL;
    stage->peg_count = 0;

    if (is_adversary) {
        stage_generate_ramps_stage2_mirrored(stage, table_x, table_width);
    } else {
        stage_generate_ramps_stage2(stage, table_x, table_width);
    }

    return stage;
}
```

### Step 5: Visual polish

- Add subtle background shading to stage 2 area
- Ramp colors: warm tones for right-pointing, cool for left-pointing
- Optional: particle trails showing recent ball paths

## Files to Modify

- `src/015-stage.c` - Stage 2 generation functions
- `src/014-stage.h` - Stage 2 constants

## Dependencies

- Issue 1002 (Stage system architecture)
- Issue 1005 (Ramp obstacle type)

## Testing

1. Verify ramps arranged in converging pattern
2. Verify balls deflected toward center
3. Verify adversary layout is correctly mirrored
4. Verify balls can traverse full stage without getting stuck
5. Verify edge balls caught by outer ramps
6. Playtest for fun factor - adjust ramp angles/positions as needed

## Balance Notes

The ramp layout should be tuned for:
- Average ball survival rate ~60-70% (similar to peg stage)
- Most surviving balls exit through center gates
- Horizontal movement creates visual interest
- Not too chaotic - player should feel some control
