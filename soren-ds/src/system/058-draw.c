/*
 * 058-draw.c — the drawing primitives.
 *
 * General description: every call works out which pixels of the canvas it
 * would touch, trims that to the canvas edges, and writes 32-bit pixel
 * words directly. Text is the font table read one bit at a time, each bit
 * becoming a `scale`×`scale` square.
 */
#include "../engine/025-platform.h"
#include "056-font-8x16.h"
#include "058-draw.h"

/* {{{ canvas_of_screen */
struct canvas canvas_of_screen(int which)
{
    struct platform_screen s = platform_screen(which);
    struct canvas c = { s.pixels, s.width, s.height, s.stride };
    return c;
}
/* }}} */

/* {{{ canvas_part */
struct canvas canvas_part(struct canvas c, int x, int y, int w, int h)
{
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > c.width) w = c.width - x;
    if (y + h > c.height) h = c.height - y;
    if (w < 0) w = 0;
    if (h < 0) h = 0;
    struct canvas part = { c.pixels + (long)y * c.stride + x, w, h, c.stride };
    return part;
}
/* }}} */

/* {{{ draw_rect */
void draw_rect(struct canvas c, int x, int y, int w, int h, uint32_t colour)
{
    struct canvas r = canvas_part(c, x, y, w, h);
    for (int row = 0; row < r.height; row++) {
        uint32_t *p = r.pixels + (long)row * r.stride;
        for (int col = 0; col < r.width; col++) {
            p[col] = colour;
        }
    }
}
/* }}} */

/* {{{ draw_fill */
void draw_fill(struct canvas c, uint32_t colour)
{
    draw_rect(c, 0, 0, c.width, c.height, colour);
}
/* }}} */

/* {{{ draw_frame */
void draw_frame(struct canvas c, int x, int y, int w, int h, uint32_t colour)
{
    draw_rect(c, x, y, w, 1, colour);
    draw_rect(c, x, y + h - 1, w, 1, colour);
    draw_rect(c, x, y, 1, h, colour);
    draw_rect(c, x + w - 1, y, 1, h, colour);
}
/* }}} */

/* {{{ draw_pixel */
void draw_pixel(struct canvas c, int x, int y, uint32_t colour)
{
    if (x >= 0 && y >= 0 && x < c.width && y < c.height) {
        c.pixels[(long)y * c.stride + x] = colour;
    }
}
/* }}} */

/* {{{ draw_line */
/* Bresenham's line: step along the longer axis one pixel at a time, and
 * move along the shorter one whenever the accumulated error says so. */
void draw_line(struct canvas c, int x0, int y0, int x1, int y1, uint32_t colour)
{
    int dx = x1 > x0 ? x1 - x0 : x0 - x1;
    int dy = y1 > y0 ? y0 - y1 : y1 - y0;
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    for (;;) {
        draw_pixel(c, x0, y0, colour);
        if (x0 == x1 && y0 == y1) {
            break;
        }
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}
/* }}} */

/* {{{ draw_text */
int draw_text(struct canvas c, int x, int y, const char *text, int scale,
              uint32_t ink, uint32_t background)
{
    if (scale < 1) {
        scale = 1;
    }
    for (const unsigned char *t = (const unsigned char *)text; *t; t++) {
        const uint8_t *glyph = font_8x16[*t];
        for (int row = 0; row < FONT_HEIGHT; row++) {
            for (int col = 0; col < FONT_WIDTH; col++) {
                /* Two kinds of pixel: a set bit (ink) and a clear one
                 * (background, or untouched when the background is 0). */
                int set = (glyph[row] >> (7 - col)) & 1;
                if (set || background) {
                    draw_rect(c, x + col * scale, y + row * scale, scale, scale, set ? ink : background);
                }
            }
        }
        x += FONT_WIDTH * scale;
    }
    return x;
}
/* }}} */

/* {{{ text_width */
int text_width(const char *text, int scale)
{
    int n = 0;
    while (text[n]) {
        n++;
    }
    return n * FONT_WIDTH * (scale < 1 ? 1 : scale);
}
/* }}} */
