/*
 * crowd-run.c - runs a crossing scene on the C crowd (issue 515k)
 *
 * What this is: reads a scene (crowd-scene.lua's format), puts its units
 * into the C crowd, sends each army to the other's home and, whenever
 * nobody is moving any more, back again -- exactly what the Lua runner
 * (crowd-lua-run.lua) does -- and prints every unit's position at set
 * ticks, so the two can be compared line by line.
 *
 * Output: for every EVERY-th tick, "tick T" and then "X Y" per unit (17
 * significant digits).
 *
 * Usage: crowd-run SCENE TICKS EVERY
 */
#include "crowd.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 4) { fprintf(stderr, "usage: %s SCENE TICKS EVERY\n", argv[0]); return 64; }
    FILE *f = fopen(argv[1], "r");
    if (!f) { fprintf(stderr, "can't read %s\n", argv[1]); return 66; }
    long ticks = atol(argv[2]), every = atol(argv[3]);
    int w, h;
    double cell;
    if (fscanf(f, "%d %d %lf\n", &w, &h, &cell) != 3) { fprintf(stderr, "a scene starts with W H CELL\n"); return 65; }
    unsigned char *walk = malloc((size_t)w * h);
    char *row = malloc((size_t)w + 8);
    for (int y = 0; y < h; y++) {
        if (fscanf(f, "%s\n", row) != 1 || (int)strlen(row) != w) { fprintf(stderr, "row %d of the ground is wrong\n", y + 1); return 65; }
        for (int x = 0; x < w; x++) walk[y * w + x] = row[x] != '#';
    }
    double homes[2][2];
    int n;
    if (fscanf(f, "HOMES %lf %lf %lf %lf\nUNITS %d\n", &homes[0][0], &homes[0][1], &homes[1][0], &homes[1][1], &n) != 5) {
        fprintf(stderr, "HOMES and UNITS lines expected\n"); return 65;
    }
    cr_crowd *c = cr_new(w, h, walk, cell);
    int *armies[2] = { malloc((size_t)n * sizeof(int)), malloc((size_t)n * sizeof(int)) };
    int counts[2] = { 0, 0 };
    for (int i = 0; i < n; i++) {
        double x, y, r, speed;
        int team;
        if (fscanf(f, "%lf %lf %lf %lf %d\n", &x, &y, &r, &speed, &team) != 5) { fprintf(stderr, "unit %d is wrong\n", i + 1); return 65; }
        cr_add(c, x, y, r, speed, team);
        armies[team - 1][counts[team - 1]++] = i + 1;
    }
    fclose(f);

    int across = 1;
    for (int a = 0; a < 2; a++) cr_move_group(c, armies[a], counts[a], homes[1 - a][0], homes[1 - a][1]);
    cr_unit *u = cr_units(c);
    for (long t = 1; t <= ticks; t++) {
        cr_tick(c, 1 / 62.5);
        int moving = 0;
        for (int i = 0; i < n; i++) if (u[i].moving) { moving = 1; break; }
        /* Two paths: someone moving -> carry on; nobody -> the crossing is
         * over: each army to the other side */
        if (!moving) {
            across = !across;
            for (int a = 0; a < 2; a++) {
                int to_home = !across;
                int home = to_home ? a : 1 - a;
                cr_move_group(c, armies[a], counts[a], homes[home][0], homes[home][1]);
            }
        }
        if (t % every == 0) {
            printf("tick %ld\n", t);
            for (int i = 0; i < n; i++) printf("%.17g %.17g\n", u[i].x, u[i].y);
        }
    }
    cr_free(c);
    return 0;
}
/* }}} */
