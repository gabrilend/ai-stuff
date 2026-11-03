/*
 * crowd-film.c - draws a crossing scene from above, frame by frame, for the page's GIFs (issue 515k)
 *
 * What this is: the crowd the benchmark times, seen. It runs a scene on
 * the C crowd (one thread; the picture doesn't depend on the design, since
 * every design gives the same positions) and every EVERY ticks draws the
 * field from above into an off-screen picture: walls, and every unit as a
 * disc of its own size in its army's colour with its radius ringed (green
 * for one side, purple for the other, as the owner asked of the demo).
 * Each picture is saved as OUT/frame-NNNN.png; run-crowd-gifs.sh turns
 * them into a GIF with ffmpeg.
 *
 * Usage: crowd-film SCENE TICKS EVERY WIDTH OUT
 */
#include "raylib.h"
#include "crowd.h"
#include "crowd-common.h"

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 6) { fprintf(stderr, "usage: %s SCENE TICKS EVERY WIDTH OUT\n", argv[0]); return 64; }
    long ticks = atol(argv[2]), every = atol(argv[3]);
    int width = atoi(argv[4]);
    const char *out = argv[5];
    scene sc;
    cr_crowd *c = scene_load(argv[1], &sc);

    /* the ground again, to draw its walls: read from the scene's rows */
    FILE *f = fopen(argv[1], "r");
    int w, h;
    double cell;
    if (!f || fscanf(f, "%d %d %lf\n", &w, &h, &cell) != 3) { fprintf(stderr, "can't read %s\n", argv[1]); return 66; }
    char **rows = malloc((size_t)h * sizeof(char *));
    for (int y = 0; y < h; y++) {
        rows[y] = malloc((size_t)w + 8);
        if (fscanf(f, "%s\n", rows[y]) != 1) { fprintf(stderr, "bad row %d\n", y + 1); return 65; }
    }
    fclose(f);

    float scale = (float)width / (float)(w * cell);
    int height = (int)(h * cell * scale);
    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_WINDOW_HIDDEN);
    InitWindow(width, height, "crowd film");
    RenderTexture2D target = LoadRenderTexture(width, height);

    crossing cross;
    crossing_start(&cross, c, &sc);
    cr_unit *u = cr_units(c);
    int n = cr_count(c), frame = 0;
    for (long t = 0; t <= ticks; t++) {
        if (t > 0) { cr_tick(c, 1 / 62.5); crossing_step(&cross, c, &sc); }
        if (t % every != 0) continue;
        BeginTextureMode(target);
        ClearBackground((Color){ 52, 60, 48, 255 });
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                if (rows[y][x] == '#')
                    DrawRectangle((int)(x * cell * scale), (int)(y * cell * scale), (int)(cell * scale + 1), (int)(cell * scale + 1), (Color){ 120, 112, 100, 255 });
        for (int i = 0; i < n; i++) {
            int west = u[i].team == 1;
            Color body = west ? (Color){ 214, 72, 59, 255 } : (Color){ 59, 127, 217, 255 };
            Color ring = west ? (Color){ 70, 220, 90, 255 } : (Color){ 190, 90, 230, 255 };
            Vector2 at = { (float)(u[i].x * scale), (float)(u[i].y * scale) };
            float r = (float)(u[i].radius * scale);
            DrawCircleV(at, r, body);
            if (r >= 2.5f) DrawRing(at, r - 1.2f, r, 0, 360, 24, ring);
        }
        DrawRectangle(8, 8, 250, 26, (Color){ 0, 0, 0, 150 });
        DrawText(TextFormat("%d units   %.1f s", n, t / 62.5), 16, 13, 18, RAYWHITE);
        EndTextureMode();
        Image img = LoadImageFromTexture(target.texture);
        ImageFlipVertical(&img);   /* textures are stored bottom row first */
        const char *path = TextFormat("%s/frame-%04d.png", out, frame++);
        if (!ExportImage(img, path)) { fprintf(stderr, "can't write %s\n", path); return 73; }
        UnloadImage(img);
    }
    UnloadRenderTexture(target);
    CloseWindow();
    printf("%d frames\n", frame);
    return 0;
}
/* }}} */
