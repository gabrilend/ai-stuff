# 004 - Raylib Integration

## Overview

Raylib handles all graphics, window management, and input. The main
thread exclusively owns the raylib context.

## Initialization

```c
// {{{ init_graphics
void init_graphics(int width, int height, const char* title) {
    InitWindow(width, height, title);
    SetTargetFPS(60);
}
// }}}
```

## Main Loop Structure

```c
// {{{ main_loop
void main_loop(World* world, ThreadPool* pool) {
    while (!WindowShouldClose()) {
        // Input
        handle_input(world);

        // Physics (parallel)
        submit_ball_tasks(world, pool);
        threadpool_wait_all(pool);
        swap_ball_buffers(world);

        // Render
        BeginDrawing();
        ClearBackground(DARKGRAY);
        render_world(world);
        render_ui(world);
        EndDrawing();
    }
}
// }}}
```

## Rendering Functions

### Pegs
```c
// {{{ render_pegs
void render_pegs(World* world) {
    for (int i = 0; i < world->peg_count; i++) {
        Peg* peg = &world->pegs[i];
        DrawCircle((int)peg->x, (int)peg->y, peg->radius, LIGHTGRAY);
    }
}
// }}}
```

### Balls
```c
// {{{ render_balls
void render_balls(World* world) {
    Ball* balls = world->current_balls;
    for (int i = 0; i < world->ball_capacity; i++) {
        if (balls[i].active) {
            Color c = GetColor(balls[i].color);
            DrawCircle((int)balls[i].x, (int)balls[i].y,
                      balls[i].radius, c);
        }
    }
}
// }}}
```

### Score Zones
```c
// {{{ render_score_zones
void render_score_zones(World* world) {
    for (int i = 0; i < world->zone_count; i++) {
        ScoreZone* z = &world->zones[i];
        DrawRectangle((int)z->x_min, world->height - 40,
                     (int)(z->x_max - z->x_min), 40, BLUE);

        char buf[16];
        sprintf(buf, "%d", z->points);
        int text_width = MeasureText(buf, 20);
        float center = (z->x_min + z->x_max) / 2;
        DrawText(buf, (int)(center - text_width/2),
                world->height - 30, 20, WHITE);
    }
}
// }}}
```

### UI
```c
// {{{ render_ui
void render_ui(World* world) {
    char buf[64];
    sprintf(buf, "Score: %d", world->score);
    DrawText(buf, 10, 10, 20, WHITE);

    sprintf(buf, "Balls: %d", count_active_balls(world));
    DrawText(buf, 10, 35, 20, WHITE);

    DrawText("SPACE to launch", 10, world->height - 20, 16, GRAY);
}
// }}}
```

## Input Handling

```c
// {{{ handle_input
void handle_input(World* world) {
    if (IsKeyPressed(KEY_SPACE)) {
        launch_ball(world);
    }

    // Optional: mouse-aimed launch
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        Vector2 pos = GetMousePosition();
        launch_ball_at(world, pos.x, pos.y);
    }
}
// }}}
```

## Build Requirements

Link against raylib:
```makefile
LDFLAGS = -lraylib -lm -lpthread
```

On Linux, additional libs may be needed:
```makefile
LDFLAGS = -lraylib -lGL -lm -lpthread -ldl -lrt -lX11
```
