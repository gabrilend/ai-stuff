# 104 — Platform seam header

**Phase:** 1
**Blocked by:** 102 (project structure).
**Blocks:** 107, 108, and every render/input/audio/save issue in later phases.

## Current behavior

No platform abstraction exists. Gameplay code, were it to be written
today, would have to `#include <nds.h>` directly, locking the trunk to
the DS profile.

## Intended behavior

A single header `src/01-platform.h` declares every operation that a
profile may implement differently. Gameplay code includes only this
header. The header has *no* implementation in trunk; implementations live
in profile-specific source files that are selected via the patch system
in 103.

### Surface (initial draft)

The exact field layout is determined per profile; gameplay code uses only
the typedefs and functions:

```c
/* {{{ platform_init() */
typedef struct platform_config platform_config;
void platform_init(const platform_config* cfg);
/* }}} */

/* {{{ platform_frame_begin() / platform_frame_end() */
void platform_frame_begin(void);
void platform_frame_end(void);   /* swaps buffers / waits for vblank */
/* }}} */

/* {{{ platform_input — buttons + stylus, normalized to logical names */
typedef struct platform_input platform_input;
void  platform_input_poll(platform_input* out);
bool  platform_input_pressed(const platform_input* in, int logical_button);
bool  platform_input_held   (const platform_input* in, int logical_button);
void  platform_input_stylus (const platform_input* in, fx_t* x, fx_t* y, bool* down);
/* }}} */

/* {{{ platform_render — minimum 3D submission API */
void platform_render_clear(uint16_t color_rgb555);
void platform_render_sprite(const sprite_handle s, fxw_t x, fxw_t y);
void platform_render_mesh  (const mesh_handle m, const transform_t* t);
/* }}} */

/* {{{ platform_audio — fixed-channel mixer */
typedef struct platform_audio platform_audio;
void platform_audio_play(int channel, const sound_handle s);
void platform_audio_stop(int channel);
/* }}} */

/* {{{ platform_file — save/load */
size_t platform_file_read (const char* path, void* buf, size_t cap);
bool   platform_file_write(const char* path, const void* buf, size_t len);
/* }}} */

/* {{{ platform_log — for tmp/ logs */
void platform_log(const char* fmt, ...);
/* }}} */

/* {{{ platform_time — ticks since boot, monotonic */
uint32_t platform_time_ticks(void);
/* }}} */
```

### Implementation routing

The default implementation source files in the trunk are the **DS**
implementations (because the trunk is DS-shaped). The native profile
applies a `B###` patch that:

1. Renames (or symlinks) the DS implementation files out of the
   compile set, OR uses a preprocessor switch driven by a single
   patch-introduced `#define SYMBELINE_PROFILE_NATIVE`.
2. Brings in the native implementation files from
   `src/platform/native/`.

The exact mechanism (symlink swap vs. `#define` flip) is decided during
implementation. The `B###` patch documents the choice so the unapply step
is exact.

## Suggested implementation steps

1. Author `src/01-platform.h` with the surface above. No implementation.
2. Author `src/platform/nds/01-platform-nds.c` with stubs for every
   declared function. Stubs may `platform_log("not implemented: %s", __func__)`.
3. Author `src/platform/native/01-platform-native.c` with the same stub
   shape. Will not compile into NDS builds — that's the patch's job.
4. Author `src/01-platform.info.md` describing the surface (per the
   global rule that every source file has a `.info.md` sibling).
5. Reserve patch ID `B100-native-platform-impl.sh` (to be filled when
   issue 108 lands) which routes the native implementation files into
   the compile set on the `native` profile.
6. Bump `.file-index-counter` to 1 (the platform header is index 01).

## Deliverable artifacts

- `src/01-platform.h`
- `src/01-platform.info.md`
- `src/platform/nds/01-platform-nds.c`
- `src/platform/native/01-platform-native.c`
- Reserved patch slot `B100`.

## Related documents

- `docs/004-architecture.md` — platform seam discussion.
- `docs/005-divergence-grid.md` — most grid rows are platform-seam-shaped.
- `docs/008-fixed-point-math.md` — `fx_t`, `fxw_t` types used in the API.
