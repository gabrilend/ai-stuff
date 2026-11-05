/*
 * w-client-start.c (world-edit-to-execute issue 913) - the W client's own
 * start, up to its window, as a stand-in W client for Test Map's tests
 *
 * For a general audience: the W client (custom-client) checks everything
 * it needs before it opens a window: its options (067), its goodbye
 * receipt (068), the converted map's map.lua (073), and the world's start
 * (087: its tables, the map's folder, the ground under the start). This
 * program runs exactly those parts of the client, in the order its
 * src/043-main.c runs them, and stops where the window would open. It is
 * compiled by src/tests/test_test_map.lua from the W client's sources
 * ($W_CLIENT_SRC) with the client's window-free parts (its scripts/build's
 * CORE), so what it accepts or refuses is what the client accepts or
 * refuses. Nothing here is the client's own code; it only calls it.
 *
 * On a good start it prints the map, the start and the ground under it,
 * and writes a "closed" receipt with 0 frames (no window was drawn); on a
 * failure, as 043 does: the sentence on stderr, an "error" receipt, and
 * exit 2 for the options, 1 for anything else.
 */
#include "013-errors.h"
#include "014-settings.h"
#include "067-test-map.h"
#include "068-goodbye.h"
#include "073-converted-map.h"
#include "087-world-start.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* the client's own options and their values (043-main.c's CLIENT_OPTIONS) */
static const ClientOption CLIENT_OPTIONS[] = {
    { "--maps", 1 }, { "--settings", 1 }, { "--world", 1 }, { "--no-read-ahead", 0 }, { "--client", 1 }, { "--shot", 1 },
    { "--zoom", 1 }, { "--front", 0 }, { "--turn", 1 }, { "--pitch", 1 }, { "--pose", 2 }, { "--clock", 1 }, { "--hour", 1 },
    { "--face", 1 }, { "--walk", 1 }, { "--walking", 0 }, { "--dive", 1 }, { "--wait", 1 }, { "--wear", 1 }, { "--map", 3 },
    { "--goto", 2 }, { "--assets", 1 }, { NULL, 0 },
};

static Goodbye *bye;

static int failed(int status, const char *format, ...) __attribute__((format(printf, 2, 3)));
static int failed(int status, const char *format, ...)
{
    char text[600];
    va_list ap;
    va_start(ap, format);
    vsnprintf(text, sizeof text, format, ap);
    va_end(ap);
    fprintf(stderr, "%s\n", text);
    WWhy why;
    if (goodbye_end(bye, GOODBYE_ERROR, text, &why)) fprintf(stderr, "%s\n", why.text);
    return status;
}

int main(int argc, char **argv)
{
    WWhy why;
    TestMap *tm = NULL;
    WErr asked = test_map_parse(argc, argv, CLIENT_OPTIONS, getenv(TEST_MAP_PASSWORD_VARIABLE), &tm, &why);
    unsetenv(TEST_MAP_PASSWORD_VARIABLE);
    if (tm) {
        WWhy no_receipt;
        if (goodbye_begin(test_map_receipt(tm), test_map_folder(tm), &bye, &no_receipt)) {
            fprintf(stderr, "%s\n", no_receipt.text);
            return 2;
        }
    }
    if (asked) return failed(2, "%s", why.text);
    if (!tm) { fprintf(stderr, "this stand-in runs a --test-map start only\n"); return 2; }
    const char *maps = NULL, *client = NULL, *settings_file = NULL, *assets_dir = NULL;
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--maps") && i + 1 < argc) maps = argv[++i];
        else if (!strcmp(argv[i], "--client") && i + 1 < argc) client = argv[++i];
        else if (!strcmp(argv[i], "--settings") && i + 1 < argc) settings_file = argv[++i];
        else if (!strcmp(argv[i], "--assets") && i + 1 < argc) assets_dir = argv[++i];
    }
    if (!maps || !client) return failed(2, "the client needs --maps (the server's map files) and --client (the game's Data folder); scripts/run gives both");
    ConvertedMap conv;
    const char *folder = test_map_folder(tm);
    if (converted_map_read(folder, &conv, &why)) return failed(1, "test map: %s", why.text);
    double x = conv.start_x, y = conv.start_y, cx, cy;
    int camera = test_map_camera(tm, &cx, &cy);
    if (camera) { x = cx; y = cy; }
    printf("test map: map %d, World\\Maps\\%s, its start at (%.1f, %.1f)%s\n", conv.id, conv.directory, conv.start_x, conv.start_y,
           camera ? "; --camera given" : "");
    Settings *st = settings_new();
    if (settings_file) settings_load(st, settings_file, stderr);
    WorldStartIn in = { .client = client, .maps = maps, .assets_dir = assets_dir, .settings = st, .test_map = tm,
                        .conv = &conv, .map_id = conv.id, .start_x = x, .start_y = y, .log = stdout };
    WorldStart ws;
    if (world_start_open(&in, &ws, &why)) return failed(1, "%s", why.text);
    printf("start: (%.2f, %.2f) on map %d, World\\Maps\\%s, ground z %.3f, steepest walkable %.1f (%s)\n",
           x, y, conv.id, ws.map_name, ws.z, ws.max_slope, ws.slope_from);
    world_start_close(&ws);
    printf("stopped where the window would open (a stand-in: no frames drawn)\n");
    fflush(stdout);
    if (goodbye_end(bye, GOODBYE_CLOSED, NULL, &why)) { fprintf(stderr, "%s\n", why.text); return 1; }
    goodbye_free(bye);
    test_map_free(tm);
    settings_free(st);
    return 0;
}
