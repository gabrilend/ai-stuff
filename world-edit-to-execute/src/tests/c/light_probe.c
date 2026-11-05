/*
 * light_probe.c - the W client's light, read from a converted build (issue W02i's test)
 *
 * Compiled by src/tests/test_wow_light.lua with the W client's window-free
 * parts (its scripts/build's CORE list) from $W_CLIENT_SRC, into a library
 * LuaJIT loads. It does what the W client's headless run (089) does for
 * the light where she ends: the build folder as an overlay (060), the
 * tables through it (074), the light from them (026, light_open and
 * light_at), and a test map's own fog from its war3map.w3i (084), laid
 * over as the window does.
 */
#include "026-light.h"
#include "060-resolver.h"
#include "074-tables.h"
#include "084-map-fog.h"

#include <stdio.h>
#include <string.h>

/* out: [0] light id, [1] tables none, [2] lights read, [3] fog start,
 * [4] fog end, [5-7] fog colour, [8-10] sky overhead, [11-13] sky at the
 * horizon, [14-17] water opacity (ocean shallow, ocean deep, river
 * shallow, river deep), [18-20] sun, [21] the map's fog laid over (1/0),
 * [22-23] fog start and end after it, [24-26] fog colour after it,
 * [27-29] ocean near. Returns 0, or 1 with `said` naming the failure. */
int wete_light_probe(const char *build, int map, float x, float y, float z, float hours, int kind,
                     double yards_per_unit, double *out, char *said, size_t said_len)
{
    ResolverPlace place;
    memset(&place, 0, sizeof place);
    place.noverlays = 1;
    place.distinctness = 0.5;
    snprintf(place.overlays[0], sizeof place.overlays[0], "%s", build);
    WWhy why = { 0 };
    Resolver *r = NULL;
    if (resolver_open(&place, &r, &why)) { snprintf(said, said_len, "resolver: %s", why.text); return 1; }
    Tables *ts = tables_new(r, NULL);
    LightTables lt;
    if (light_open(&lt, ts, NULL, &why)) {
        snprintf(said, said_len, "light_open: %s", why.text);
        tables_free(ts); resolver_free(r);
        return 1;
    }
    LightNow now;
    memset(&now, 0, sizeof now);
    out[0] = light_at(&lt, map, x, y, z, hours, kind, &now);
    out[1] = lt.none; out[2] = lt.nlights;
    out[3] = now.fog_start; out[4] = now.fog_end;
    for (int c = 0; c < 3; ++c) {
        out[5 + c] = now.fog[c]; out[8 + c] = now.sky[0][c]; out[11 + c] = now.sky[4][c];
        out[18 + c] = now.sun[c]; out[27 + c] = now.water[0][c];
    }
    for (int i = 0; i < 4; ++i) out[14 + i] = now.water_alpha[i];
    W3iInfo info;
    WWhy fw;
    WErr rc = map_w3i_read(r, NULL, &info, &fw);
    MapFog mf;
    map_fog_from_w3i(rc ? NULL : &info, yards_per_unit, &mf);
    out[21] = map_fog_apply(&mf, &now);
    out[22] = now.fog_start; out[23] = now.fog_end;
    for (int c = 0; c < 3; ++c) out[24 + c] = now.fog[c];
    snprintf(said, said_len, "%s", mf.on ? "the map's fog" : (mf.why_off ? mf.why_off : ""));
    light_close(&lt);
    tables_free(ts);
    resolver_free(r);
    return 0;
}
