/*
 * 046-metrics.c — append measurement lines to a per-program file in the
 * RAM-backed work directory.
 *
 * General description: open one file per program, write one line per
 * measurement, close it. The directory is created if missing, because the
 * RAM directory is emptied at every reboot.
 */
#define _GNU_SOURCE
#include "046-metrics.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static FILE *out;

/* {{{ project_dir */
/* The project root is two levels above this executable's source tree;
 * at run time it is taken from SOREN_DIR, which every run script sets. */
static const char *project_dir(void)
{
    const char *dir = getenv("SOREN_DIR");
    if (!dir) {
        fprintf(stderr, "metrics: SOREN_DIR is not set; run through scripts/test-twin or a demo script\n");
        exit(2);
    }
    return dir;
}
/* }}} */

/* {{{ make_dirs */
static void make_dirs(const char *path)
{
    char buf[PATH_MAX];
    snprintf(buf, sizeof buf, "%s", path);
    for (char *p = buf + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(buf, 0755);
            *p = '/';
        }
    }
    mkdir(buf, 0755);
}
/* }}} */

/* {{{ metrics_open */
void metrics_open(const char *program)
{
    char dir[PATH_MAX];
    const char *given = getenv("SOREN_METRICS_DIR");
    if (given) {
        snprintf(dir, sizeof dir, "%s", given);
    } else {
        snprintf(dir, sizeof dir, "%s/tmp/shared-memory/metrics", project_dir());
    }
    make_dirs(dir);
    char path[PATH_MAX + 64];
    snprintf(path, sizeof path, "%s/%s.tsv", dir, program);
    out = fopen(path, "w");
    if (!out) {
        fprintf(stderr, "metrics: cannot write %s: %s\n", path, strerror(errno));
        exit(2);
    }
}
/* }}} */

/* {{{ metric_record */
void metric_record(const char *name, double value, const char *unit,
                   const char *anchor, const char *description)
{
    if (!out) {
        fprintf(stderr, "metrics: metric_record(\"%s\") before metrics_open\n", name);
        exit(2);
    }
    fprintf(out, "%s\t%.6g\t%s\t%s\t%s\n", name, value, unit, anchor, description);
    fflush(out);
}
/* }}} */

/* {{{ metrics_close */
void metrics_close(void)
{
    if (out) {
        fclose(out);
        out = NULL;
    }
}
/* }}} */
