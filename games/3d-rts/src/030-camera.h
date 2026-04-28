// 030-camera.h — RTS-style 3D camera, singleton, main-thread only.
//
// The camera is purely a viewer concern: it never affects game state
// and never crosses the sim/render boundary (docs/004-architecture.md
// has the rationale). Lifecycle: call camera_init() once after the
// window opens, then camera_update(dt) each frame before rendering,
// then BeginMode3D(camera_get()) to use it.

#ifndef CAMERA_H_
#define CAMERA_H_

#include <raylib.h>

void camera_init(void);
void camera_update(float dt);
Camera3D camera_get(void);

#endif
