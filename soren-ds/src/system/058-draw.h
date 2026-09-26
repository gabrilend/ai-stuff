/*
 * 058-draw.h — putting rectangles and text into a grid of pixels.
 *
 * General description: a canvas is any rectangle of 0xAARRGGBB pixels —
 * a whole screen, or later (phase 6) one app's surface. These calls fill
 * rectangles, draw lines of text from the built-in 8×16 font at any whole
 * scale, and measure text. Everything is clipped to the canvas, so a
 * caller that draws past an edge loses the overhanging pixels rather than
 * writing into whatever memory lies beyond.
 */
#ifndef SOREN_DRAW_H
#define SOREN_DRAW_H

#include <stdint.h>

struct canvas {
    uint32_t *pixels;
    int       width;
    int       height;
    int       stride;           /* words from one row to the next */
};

/* The project's palette. The same names are used by the documentation
 * pages, so a screenshot and the page describing it agree. */
#define COLOUR_INK        0xFFE8E6E3u   /* text */
#define COLOUR_PAPER      0xFF16161Cu   /* background */
#define COLOUR_PANEL      0xFF22222Cu   /* a raised area */
#define COLOUR_RULE       0xFF3A3A48u   /* lines between things */
#define COLOUR_ACCENT     0xFFE0A040u   /* amber: the LED colour, used for emphasis */
#define COLOUR_GOOD       0xFF60C080u
#define COLOUR_BAD        0xFFE06060u
#define COLOUR_QUIET      0xFF8A8A96u   /* secondary text */
#define COLOUR_BLUE       0xFF5A9AE6u

struct canvas canvas_of_screen(int which);
/* A rectangle within a canvas, as a canvas of its own. Clipped. */
struct canvas canvas_part(struct canvas c, int x, int y, int w, int h);

void draw_fill(struct canvas c, uint32_t colour);
void draw_rect(struct canvas c, int x, int y, int w, int h, uint32_t colour);
void draw_frame(struct canvas c, int x, int y, int w, int h, uint32_t colour);
void draw_pixel(struct canvas c, int x, int y, uint32_t colour);
void draw_line(struct canvas c, int x0, int y0, int x1, int y1, uint32_t colour);

/* Draw text starting at (x, y), the top-left of the first character,
 * each character FONT_WIDTH×FONT_HEIGHT times `scale`. `background` of 0
 * leaves the pixels behind the text alone. Answers the x after the text. */
int  draw_text(struct canvas c, int x, int y, const char *text, int scale,
               uint32_t ink, uint32_t background);
int  text_width(const char *text, int scale);

#endif
