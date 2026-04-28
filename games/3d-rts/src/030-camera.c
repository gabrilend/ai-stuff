// 030-camera.c — RTS-style 3D camera implementation.
//
// World coordinate convention: X and Y are the horizontal plane, Z is
// height (up). This matches the vision document's terminology
// ("the point those X/Y values intersect with the terrain"). raylib's
// Camera3D does not enforce a specific up-axis; setting
// up = (0, 0, 1) and using DrawLine3D / DrawCube etc. with explicit
// Z heights renders correctly. The camera carries this convention so
// every later issue inherits it without revisiting the choice.
//
// The camera is described by a target on the ground plus yaw (rotation
// around Z), pitch (tilt from horizontal, positive = looking down),
// and distance (how far the eye sits from the target). Those four
// numbers are recomputed into a raylib Camera3D each frame in
// recompute_ray(). All input handling lives in camera_update().

#include "030-camera.h"

#include <math.h>

// Tunables. Phase 1 hard-codes them here; future issues can promote
// individual values to 010-config.h once more places need to know
// about them. The reason for the explicit constants rather than
// magic numbers in code: every value below is a felt-quality decision
// (zoom rate, pan rate, default tilt) and the comments next to them
// are the only documentation of why each was chosen.

// Pan velocity in world units per second when the user holds WASD,
// scaled by current zoom so a far-out view pans coarsely and a
// zoomed-in view pans finely. The base value matches "comfortably
// crosses the default 64-tile world in two seconds at default zoom."
static const float CAMERA_PAN_SPEED   = 30.0f;

// Middle-mouse drag scale: world units per pixel of mouse motion,
// also scaled by current zoom. The 0.05 figure is empirical — small
// enough to feel like "grabbing" the world, not flinging it.
static const float CAMERA_DRAG_SCALE  = 0.05f;

// Per-tick scroll zoom factor. 0.10 means each scroll click changes
// distance by 10%. Exponential because that produces uniform-feeling
// zoom: every click is the same proportional change regardless of
// current distance.
static const float CAMERA_ZOOM_FACTOR = 0.10f;

// Distance clamps. Min keeps the camera from clipping into objects
// at the target; max keeps the world from shrinking to a dot.
static const float CAMERA_DIST_MIN    = 8.0f;
static const float CAMERA_DIST_MAX    = 120.0f;

// Yaw rotation rate when Q or E is held, radians per second.
static const float CAMERA_YAW_RATE    = 1.5f;

// Default tilt and distance. ~54° down from horizontal is a typical
// RTS angle; 50 world units sees roughly a 60-tile area at FOV 60°.
static const float CAMERA_PITCH_INIT  = 0.95f;
static const float CAMERA_DIST_INIT   = 50.0f;

// Singleton state. Owned by the main thread; never read by the sim
// thread. File-static rather than passed-around because every call
// site lives on the main render loop and threading it through would
// only obscure the read-only-from-elsewhere contract.
static struct {
	Vector3  target;
	float    yaw;
	float    pitch;
	float    distance;
	Camera3D ray;
} g_cam;

// {{{ static void recompute_ray()
// Rebuilds the raylib Camera3D from the four state numbers. Called
// at end of camera_update() and once during camera_init() so a fresh
// camera is renderable before the first update tick.
static void recompute_ray(void)
{
	float horiz = g_cam.distance * cosf(g_cam.pitch);
	float vert  = g_cam.distance * sinf(g_cam.pitch);
	g_cam.ray.position.x = g_cam.target.x - horiz * cosf(g_cam.yaw);
	g_cam.ray.position.y = g_cam.target.y - horiz * sinf(g_cam.yaw);
	g_cam.ray.position.z = g_cam.target.z + vert;
	g_cam.ray.target     = g_cam.target;
	g_cam.ray.up         = (Vector3){ 0.0f, 0.0f, 1.0f };
	g_cam.ray.fovy       = 60.0f;
	g_cam.ray.projection = CAMERA_PERSPECTIVE;
}
// }}}

// {{{ static void apply_pan()
// Translates the target in the X/Y plane along the camera's local
// forward and right directions. Forward at yaw=0 is +X; right at
// yaw=0 is -Y (so "right" in Z-up looking east is south, matching
// the player's physical right hand). The reason this lives in its
// own function: both keyboard pan and middle-mouse drag use it.
static void apply_pan(float forward, float right)
{
	float fx =  cosf(g_cam.yaw);
	float fy =  sinf(g_cam.yaw);
	float rx =  sinf(g_cam.yaw);
	float ry = -cosf(g_cam.yaw);
	g_cam.target.x += fx * forward + rx * right;
	g_cam.target.y += fy * forward + ry * right;
}
// }}}

// {{{ void camera_init()
void camera_init(void)
{
	g_cam.target   = (Vector3){ 0.0f, 0.0f, 0.0f };
	g_cam.yaw      = 0.0f;
	g_cam.pitch    = CAMERA_PITCH_INIT;
	g_cam.distance = CAMERA_DIST_INIT;
	recompute_ray();
}
// }}}

// {{{ void camera_update()
void camera_update(float dt)
{
	// Pan speed scales with distance: far-zoom pans coarsely, close-
	// zoom pans finely. The CAMERA_DIST_INIT divisor makes the speed
	// feel "right" at default zoom and proportional elsewhere.
	float pan = CAMERA_PAN_SPEED * dt * (g_cam.distance / CAMERA_DIST_INIT);
	if (IsKeyDown(KEY_W)) apply_pan(+pan,    0);
	if (IsKeyDown(KEY_S)) apply_pan(-pan,    0);
	if (IsKeyDown(KEY_A)) apply_pan(   0, -pan);
	if (IsKeyDown(KEY_D)) apply_pan(   0, +pan);

	// Middle-mouse drag pan. The forward (X-aligned at yaw=0, "red")
	// axis matches the mouse Y delta directly. The right (Y-aligned
	// at yaw=0, "green") axis is *negated* relative to mouse X — the
	// straight mapping felt inverted during 103 testing. See
	// docs/balance-updates.md 2026-04-27 entry.
	if (IsMouseButtonDown(MOUSE_BUTTON_MIDDLE)) {
		Vector2 d = GetMouseDelta();
		float scale = CAMERA_DRAG_SCALE *
		              (g_cam.distance / CAMERA_DIST_INIT);
		apply_pan(d.y * scale, -d.x * scale);
	}

	// Scroll-wheel zoom. Exponential form so each click is the same
	// proportional change regardless of current distance.
	float scroll = GetMouseWheelMove();
	if (scroll != 0.0f) {
		g_cam.distance *= (1.0f - scroll * CAMERA_ZOOM_FACTOR);
		if (g_cam.distance < CAMERA_DIST_MIN) {
			g_cam.distance = CAMERA_DIST_MIN;
		}
		if (g_cam.distance > CAMERA_DIST_MAX) {
			g_cam.distance = CAMERA_DIST_MAX;
		}
	}

	// Q / E yaw rotation around the target. Q rotates clockwise (yaw
	// increases), E counter-clockwise. Initial mapping was the
	// opposite and felt backwards during 103 testing — see
	// docs/balance-updates.md 2026-04-27 entry.
	if (IsKeyDown(KEY_Q)) g_cam.yaw += CAMERA_YAW_RATE * dt;
	if (IsKeyDown(KEY_E)) g_cam.yaw -= CAMERA_YAW_RATE * dt;

	recompute_ray();
}
// }}}

// {{{ Camera3D camera_get()
Camera3D camera_get(void)
{
	return g_cam.ray;
}
// }}}
