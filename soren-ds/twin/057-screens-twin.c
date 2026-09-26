/*
 * 057-screens-twin.c — PNG pictures of the twin's two screens.
 *
 * General description: read the screen memory row by row, drop the alpha
 * byte, and hand each row to libpng. Stacking both screens copies the top
 * screen's rows, then a band of dark case colour, then the bottom screen's.
 */
#include "../src/engine/025-platform.h"
#include "057-screens-twin.h"

#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define GAP 24                     /* pixels of case between the two screens */
#define CASE_COLOUR 0x202028u

/* {{{ write_png */
/* Write `height` rows of `width` pixels, fetching each row from `row_of`. */
static int write_png(const char *path, int width, int height,
                     const uint32_t *(*row_of)(int y, void *ctx), void *ctx)
{
    FILE *f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "screens: cannot write %s\n", path);
        return 1;
    }
    png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop info = png_create_info_struct(png);
    if (setjmp(png_jmpbuf(png))) {
        fprintf(stderr, "screens: libpng failed writing %s\n", path);
        png_destroy_write_struct(&png, &info);
        fclose(f);
        return 1;
    }
    png_init_io(png, f);
    png_set_IHDR(png, info, (png_uint_32)width, (png_uint_32)height, 8, PNG_COLOR_TYPE_RGB,
                 PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
    png_write_info(png, info);
    uint8_t *row = malloc((size_t)width * 3);
    for (int y = 0; y < height; y++) {
        const uint32_t *src = row_of(y, ctx);
        for (int x = 0; x < width; x++) {
            uint32_t p = src ? src[x] : CASE_COLOUR;
            row[x * 3 + 0] = (uint8_t)(p >> 16);
            row[x * 3 + 1] = (uint8_t)(p >> 8);
            row[x * 3 + 2] = (uint8_t)p;
        }
        png_write_row(png, row);
    }
    free(row);
    png_write_end(png, NULL);
    png_destroy_write_struct(&png, &info);
    fclose(f);
    return 0;
}
/* }}} */

/* {{{ one_screen_row */
static const uint32_t *one_screen_row(int y, void *ctx)
{
    struct platform_screen *s = ctx;
    return s->pixels + (size_t)y * (size_t)s->stride;
}
/* }}} */

/* {{{ twin_screen_save_png */
int twin_screen_save_png(int which, const char *path)
{
    struct platform_screen s = platform_screen(which);
    return write_png(path, s.width, s.height, one_screen_row, &s);
}
/* }}} */

/* {{{ stacked_row */
/* Two sources for a row: the top screen above the gap, the bottom screen
 * below it; the gap itself has no source and is drawn in case colour. */
static const uint32_t *stacked_row(int y, void *ctx)
{
    struct platform_screen *both = ctx;
    if (y < both[0].height) {
        return both[0].pixels + (size_t)y * (size_t)both[0].stride;
    }
    y -= both[0].height + GAP;
    if (y < 0) {
        return NULL;
    }
    return both[1].pixels + (size_t)y * (size_t)both[1].stride;
}
/* }}} */

/* {{{ twin_screens_save_png */
int twin_screens_save_png(const char *path)
{
    struct platform_screen both[2] = { platform_screen(0), platform_screen(1) };
    return write_png(path, both[0].width, both[0].height + GAP + both[1].height, stacked_row, both);
}
/* }}} */
