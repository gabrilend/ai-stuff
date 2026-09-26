/*
 * crowd-boxes.c - the crowd's deciding as a ceramic box (issue 515k)
 *
 * What this is: the one box of the crowd's map. A task is a chunk of
 * units; the box has each of them decide its tick (cr_decide), then
 * answers with how many it did. The crowd itself is too big to travel as
 * a value, so, as large read-only data does in this design (issue 515,
 * point 5), it travels by pointer: the host sets `crowd_now` before handing
 * the tick in, and every unit's deciding reads only the tick's snapshot
 * and writes only that unit's own state, so any number of chunks may run
 * at once.
 *
 * With `crowd_timeline` on (the host's CROWD_TIMELINE), each chunk's run is
 * recorded with the worker that ran it, for the page's GIFs.
 */
#include "crowd.h"
#include "crowd-common.h"

/* A chunk to decide: its number, and units first .. last-1 (indices). */
typedef struct {
    int chunk;
    int first;
    int last;
} chunk_req;

/* The answer: which chunk, and how many units decided. */
typedef struct {
    int chunk;
    int count;
} chunk_done;

cr_crowd *crowd_now;
double crowd_dt;

/* {{{ chunk_done decide_chunk(chunk_req r) */
chunk_done decide_chunk(chunk_req r)
{
    double t0 = timeline_on() ? now_us() : 0;
    for (int i = r.first; i < r.last; i++) cr_decide(crowd_now, i, crowd_dt);
    if (timeline_on()) timeline_add(cera_pool_worker_index() + 1, r.chunk, t0, now_us());
    chunk_done d = { r.chunk, r.last - r.first };
    return d;
}
/* }}} */
