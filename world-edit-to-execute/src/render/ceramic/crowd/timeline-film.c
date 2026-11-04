/*
 * timeline-film.c - replays who ran which chunk when, every design side by side, for the page's GIF (issue 515k)
 *
 * What this is: the four ticks each design spent as the 2,000-unit armies
 * met, drawn as lanes -- one row per thread (or engine worker), a bar for
 * every chunk of units it decided, as long as it took -- with each design's
 * lanes stacked under its name, all on one time axis from the first tick's
 * start. A cursor sweeps across; bars appear as it passes their start, so
 * the GIF shows each design's threads working and waiting in real
 * proportion. A chunk's colour is its cost: pale for a quick one (units
 * that only stepped), dark and hot for a slow one (units that re-planned).
 *
 * Input: timeline files (tick, worker, chunk, start µs, end µs), as
 * crowd-common.h writes them, one per design.
 * Output: OUT/frame-NNNN.png, FRAMES of them.
 *
 * Usage: timeline-film FRAMES WIDTH OUT NAME=FILE [NAME=FILE ...]
 */
#include "raylib.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { int tick, worker, chunk; double start, end; } span;
typedef struct { char name[64]; span *spans; int n, workers; double last; } design;

/* {{{ static void load(design *d, const char *arg) */
static void load(design *d, const char *arg)
{
    const char *eq = strchr(arg, '=');
    if (!eq) { fprintf(stderr, "%s: NAME=FILE expected\n", arg); exit(64); }
    snprintf(d->name, sizeof d->name, "%.*s", (int)(eq - arg), arg);
    FILE *f = fopen(eq + 1, "r");
    if (!f) { fprintf(stderr, "can't read %s\n", eq + 1); exit(66); }
    int cap = 1024;
    d->spans = malloc((size_t)cap * sizeof(span));
    span s;
    while (fscanf(f, "%d %d %d %lf %lf", &s.tick, &s.worker, &s.chunk, &s.start, &s.end) == 5) {
        if (d->n == cap) { cap *= 2; d->spans = realloc(d->spans, (size_t)cap * sizeof(span)); }
        d->spans[d->n++] = s;
        if (s.worker + 1 > d->workers) d->workers = s.worker + 1;
        if (s.end > d->last) d->last = s.end;
    }
    fclose(f);
    if (d->n == 0) { fprintf(stderr, "%s holds no spans\n", eq + 1); exit(65); }
}
/* }}} */

/* {{{ static Color heat(double us) */
/* A chunk's colour by how long it took: pale teal under 20 µs, through
 * amber, to deep red at a millisecond and beyond. */
static Color heat(double us)
{
    double t = us <= 20 ? 0 : us >= 1000 ? 1 : (us - 20) / 980;
    t = t < 0.5 ? t * 2 * 0.6 : 0.6 + (t - 0.5) * 0.8;
    Color a = { 120, 200, 190, 255 }, b = { 230, 170, 60, 255 }, c = { 190, 50, 40, 255 };
    Color from = t < 0.6 ? a : b, to = t < 0.6 ? b : c;
    double k = t < 0.6 ? t / 0.6 : (t - 0.6) / 0.4;
    return (Color){ (unsigned char)(from.r + (to.r - from.r) * k), (unsigned char)(from.g + (to.g - from.g) * k),
                    (unsigned char)(from.b + (to.b - from.b) * k), 255 };
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc < 5) { fprintf(stderr, "usage: %s FRAMES WIDTH OUT NAME=FILE ...\n", argv[0]); return 64; }
    int frames = atoi(argv[1]), width = atoi(argv[2]);
    const char *out = argv[3];
    int nd = argc - 4;
    design *d = calloc((size_t)nd, sizeof(design));
    double span_all = 0;
    int lanes = 0;
    for (int i = 0; i < nd; i++) {
        load(&d[i], argv[4 + i]);
        if (d[i].last > span_all) span_all = d[i].last;
        lanes += d[i].workers;
    }
    int lane_h = 9, gap = 26, left = 170, top = 34;
    int height = top + lanes * lane_h + nd * gap + 20;
    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_WINDOW_HIDDEN);
    InitWindow(width, height, "timeline film");
    RenderTexture2D target = LoadRenderTexture(width, height);
    double per_px = span_all / (double)(width - left - 20);

    for (int fr = 0; fr < frames; fr++) {
        double now = span_all * (fr + 1) / frames;
        BeginTextureMode(target);
        ClearBackground((Color){ 24, 26, 30, 255 });
        DrawText(TextFormat("four ticks as 2,000 units meet: %.1f ms", now / 1000), 12, 9, 18, RAYWHITE);
        int y = top;
        for (int i = 0; i < nd; i++) {
            DrawText(d[i].name, 12, y + 4, 16, (Color){ 230, 200, 120, 255 });
            y += gap - 8;
            for (int w = 0; w < d[i].workers; w++)
                DrawRectangle(left, y + w * lane_h, width - left - 20, lane_h - 2, (Color){ 40, 44, 50, 255 });
            for (int k = 0; k < d[i].n; k++) {
                span *s = &d[i].spans[k];
                if (s->start > now) continue;
                double end = s->end < now ? s->end : now;
                int x0 = left + (int)(s->start / per_px), x1 = left + (int)(end / per_px);
                if (x1 <= x0) x1 = x0 + 1;
                DrawRectangle(x0, y + s->worker * lane_h, x1 - x0, lane_h - 2, heat(s->end - s->start));
            }
            y += d[i].workers * lane_h + 8;
        }
        int cx = left + (int)(now / per_px);
        DrawLine(cx, top, cx, height - 12, RAYWHITE);
        EndTextureMode();
        Image img = LoadImageFromTexture(target.texture);
        ImageFlipVertical(&img);
        const char *path = TextFormat("%s/frame-%04d.png", out, fr);
        if (!ExportImage(img, path)) { fprintf(stderr, "can't write %s\n", path); return 73; }
        UnloadImage(img);
    }
    UnloadRenderTexture(target);
    CloseWindow();
    printf("%d frames, %.0f us shown\n", frames, span_all);
    return 0;
}
/* }}} */
