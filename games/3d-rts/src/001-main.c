// 001-main.c — entry point for the 3d-rts game.
//
// Issue 101 lands this file as the smallest program that proves the
// build works end to end: open a raylib window, draw a status line so a
// viewer can see the link succeeded, and exit cleanly when the window
// closes. Subsequent issues add the simulation thread, the terrain, the
// units, the projectiles, the factory, and the input queue.
//
// The mono-repo convention is that programs read input/ first and write
// a goodbye to output/ last. Phase 1 has nothing to consume from
// input/, so the read just enumerates and reports a count — the call
// site is here so future phases can hook in without changing the
// lifecycle. The reason this matters: lifecycle drift between programs
// is one of the things the convention is trying to prevent, and
// retrofitting input/ reads later means every program in the mono-repo
// has slightly different startup behavior.

#include <raylib.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "020-terrain.h"
#include "030-camera.h"
#include "050-units.h"

// GAME_DIR is provided by the Makefile so the binary knows where the
// project root is regardless of which directory it is launched from.
// The fallback to "." exists only so a hand-compiled build (no Make)
// still produces a runnable binary; the Makefile path is the supported
// one.
#ifndef GAME_DIR
#define GAME_DIR "."
#endif

// {{{ static int count_input_files()
// Counts the non-hidden entries in <root>/input. Returns -1 if the
// directory cannot be opened — a fresh checkout might not yet have
// the directory populated, and that is not an error worth aborting
// the bootstrap over. Future phases will replace this with a real
// input parse and may choose stricter behavior at that point.
static int count_input_files(const char *root)
{
	char path[1024];
	int n = snprintf(path, sizeof(path), "%s/input", root);
	if (n < 0 || (size_t)n >= sizeof(path)) {
		fprintf(stderr, "error: input path too long\n");
		return -1;
	}

	DIR *d = opendir(path);
	if (!d) {
		return -1;
	}

	int count = 0;
	struct dirent *e;
	while ((e = readdir(d)) != NULL) {
		if (e->d_name[0] == '.') {
			continue;
		}
		count++;
	}
	closedir(d);
	return count;
}
// }}}

// {{{ static void write_goodbye()
// Writes "goodbye\n" to <root>/output/goodbye.txt. Per mono-repo
// convention this is the last thing the program does. A failure to
// write is logged but not fatal — the program is already on its way
// out the door at this point.
static void write_goodbye(const char *root)
{
	char path[1024];
	int n = snprintf(path, sizeof(path), "%s/output/goodbye.txt", root);
	if (n < 0 || (size_t)n >= sizeof(path)) {
		fprintf(stderr, "warning: goodbye path too long\n");
		return;
	}

	FILE *f = fopen(path, "w");
	if (f == NULL) {
		fprintf(stderr, "warning: could not open %s for writing\n", path);
		return;
	}
	fputs("goodbye\n", f);
	fclose(f);
}
// }}}

// {{{ int main()
int main(void)
{
	const char *root = GAME_DIR;

	// First: read input/. There is nothing to act on yet, but the
	// call site is in place for future phases.
	int input_count = count_input_files(root);
	if (input_count < 0) {
		fprintf(stderr, "note: input/ not readable at %s; proceeding\n", root);
	} else {
		printf("input/ files at %s: %d\n", root, input_count);
	}

	InitWindow(1024, 768, "3d-rts");
	SetTargetFPS(60);
	camera_init();
	terrain_init();
	units_init();

	while (!WindowShouldClose()) {
		camera_update(GetFrameTime());

		BeginDrawing();
		ClearBackground((Color){ 30, 32, 40, 255 });

		// Cursor-on-terrain pick. Recomputed every frame because the
		// camera and mouse may both be moving; the cost is one
		// ray-march of the heightmap, which is cheap. Result is
		// rendered as a small wireframe disc on the surface so the
		// pick is visible. Future issues (selection, move orders,
		// factory placement, rally drag) all reuse this same pick.
		Vector3 pick_pt;
		bool pick_ok = terrain_pick(camera_get(), GetMousePosition(),
		                             &pick_pt);

		BeginMode3D(camera_get());
		terrain_draw();
		units_render();
		if (pick_ok) {
			// A flat wireframe circle on the ground plus a tiny
			// floating sphere makes the pick easy to see at any
			// camera angle. raylib's DrawCircle3D draws in the
			// local X/Y plane, which is the ground in our Z-up
			// world — so no rotation is needed (axis ignored when
			// angle is 0). The 0.05 Z lift avoids z-fighting with
			// the terrain surface.
			DrawCircle3D((Vector3){ pick_pt.x, pick_pt.y, pick_pt.z + 0.05f },
			             0.5f,
			             (Vector3){ 0.0f, 0.0f, 1.0f },
			             0.0f,
			             YELLOW);
			DrawSphereWires(pick_pt, 0.15f, 6, 6, YELLOW);
		}
		EndMode3D();

		DrawText("3d-rts — issue 106 units", 20, 20, 22, RAYWHITE);
		DrawText("WASD pan  •  Q/E rotate  •  scroll zoom  •  mid-drag pan",
		         20, 50, 14, LIGHTGRAY);
		DrawText("close the window to exit", 20, 70, 12, LIGHTGRAY);
		DrawFPS(20, 740);
		EndDrawing();
	}

	// Shut down GPU resources before CloseWindow tears down the GL
	// context — UnloadMesh calls into rlgl which needs the context
	// alive.
	terrain_shutdown();
	CloseWindow();

	// Last: write goodbye.
	write_goodbye(root);
	return 0;
}
// }}}
