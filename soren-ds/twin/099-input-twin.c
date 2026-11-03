/*
 * 099-input-twin.c — the laptop twin's buttons, sticks and touch panels
 * (issues 502, 503, 504).
 *
 * General description: see 099-input-twin.h. The buttons are one word;
 * the sticks and the panels are several words each, so each is kept
 * behind a small mutex and copied out whole.
 */
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include "../src/system/096-input.h"
#include "099-input-twin.h"

static _Atomic uint32_t pressed_now;
static pthread_mutex_t  lock = PTHREAD_MUTEX_INITIALIZER;
static int32_t          sticks_now[STICK_AXES];
static int32_t          touch_now[TOUCH_SCREENS][TOUCH_FIELDS];

/* {{{ twin_input_set_buttons */
void twin_input_set_buttons(uint32_t pressed)
{
    atomic_store(&pressed_now, pressed);
}
/* }}} */

/* {{{ input_buttons_now */
uint32_t input_buttons_now(void)
{
    return atomic_load(&pressed_now);
}
/* }}} */

/* {{{ twin_input_set_sticks */
void twin_input_set_sticks(int32_t left_x, int32_t left_y, int32_t right_x, int32_t right_y)
{
    pthread_mutex_lock(&lock);
    sticks_now[0] = left_x;
    sticks_now[1] = left_y;
    sticks_now[2] = right_x;
    sticks_now[3] = right_y;
    pthread_mutex_unlock(&lock);
}
/* }}} */

/* {{{ input_sticks_now */
void input_sticks_now(int32_t axes[STICK_AXES])
{
    pthread_mutex_lock(&lock);
    for (int i = 0; i < STICK_AXES; i++) {
        axes[i] = sticks_now[i];
    }
    pthread_mutex_unlock(&lock);
}
/* }}} */

/* {{{ twin_input_set_touch */
void twin_input_set_touch(int screen, int32_t down, int32_t x, int32_t y, int32_t pressure)
{
    if (screen < 0 || screen >= TOUCH_SCREENS) {
        return;
    }
    pthread_mutex_lock(&lock);
    touch_now[screen][0] = down;
    touch_now[screen][1] = x;
    touch_now[screen][2] = y;
    touch_now[screen][3] = pressure;
    pthread_mutex_unlock(&lock);
}
/* }}} */

/* {{{ input_touch_now */
void input_touch_now(int screen, int32_t out[TOUCH_FIELDS])
{
    for (int i = 0; i < TOUCH_FIELDS; i++) {
        out[i] = 0;
    }
    if (screen < 0 || screen >= TOUCH_SCREENS) {
        return;
    }
    pthread_mutex_lock(&lock);
    for (int i = 0; i < TOUCH_FIELDS; i++) {
        out[i] = touch_now[screen][i];
    }
    pthread_mutex_unlock(&lock);
}
/* }}} */
