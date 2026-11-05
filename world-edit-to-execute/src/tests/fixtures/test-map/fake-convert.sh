#!/bin/bash
# A fake W02 converter for the Test Map tests (issue 913). It stands where
# src/cli/wow-convert.lua does, writing a small build of the same shape:
#
#   fake-convert.sh <mode> <map.w3x> <build folder>
#
#   ok        writes a small build: the map's checksum, the server's rows
#             (server/world.sql, holding the map's checksum), the server's
#             stamp as W02's real one is written (wowbuild.server_stamp), and a
#             conversion-report.lua whose placement puts WC3's (0, 0) at
#             the W client's (1000, 2000), 30.72 WC3 units a yard, the map
#             running from -5000 to 5000 both ways
#   noreport  as ok, without the report (a converter that writes none)
#   noplace   as ok, the report giving no placement
#   badplace  as ok, the placement's scale not a number
#   toonew    as ok, the report's format 2
#   fail      exits with code 2
#   slow      takes a second, then as ok
#   stamped   as ok, the report also holding when it was written and how
#             long that took, as W02's real report does (so it differs on
#             every conversion of the same map)
#   nostamp   as ok, without the server's stamp
#   nomap     as ok, without map.lua
#   badmap    as ok, map.lua's format 2
#   disagree  as ok, map.lua's wc3_to_wow putting WC3's (0, 0) at (1100, 2000)
#
# Every mode but nomap and fail writes map.lua as W02c does (format 1, the
# map, its start, wc3_to_wow), its rule the same as the report's placement.
mode="$1" map="$2" build="$3"
[[ -f "${map}" ]] || { echo "no map ${map}" >&2; exit 1; }
case "${mode}" in
    fail) echo "conversion failed (pretend)" >&2; exit 2 ;;
    slow) sleep 1 ;;
esac
mkdir -p "${build}/server"
cksum < "${map}" > "${build}/map.cksum"
{ echo "-- rows for $(basename "${map}")"; echo "-- $(cat "${build}/map.cksum")"; } > "${build}/server/world.sql"
report="${build}/conversion-report.lua"
rm -f "${report}"
format=1 scale="1 / 30.72" placement=yes
case "${mode}" in
    noreport) placement="" ;;
    noplace)  placement=none ;;
    badplace) scale='"wide"' ;;
    toonew)   format=2 ;;
esac
written=""
[[ "${mode}" == stamped ]] && written="written = \"$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)\", seconds = 0.$(date +%N),"
if [[ "${placement}" == yes ]]; then
    cat > "${report}" <<EOF
-- the fake converter's report
return { format = ${format}, map = "fake", ${written} placement = { client = {
    scale = ${scale}, x0 = 1000, y0 = 2000, wc3_min = { -5000, -5000 }, wc3_max = { 5000, 5000 } } } }
EOF
elif [[ "${placement}" == none ]]; then
    echo 'return { format = 1, map = "fake" }' > "${report}"
fi
mapx0=1000 mapformat=1
case "${mode}" in
    disagree) mapx0=1100 ;;
    badmap)   mapformat=2 ;;
esac
rm -f "${build}/map.lua"
if [[ "${mode}" != nomap ]]; then
    cat > "${build}/map.lua" <<EOF
-- W02c: the map the W client's Test Map opens (the fake converter)
return { format = ${mapformat}, map = { id = 900, directory = "WC3_fake", name = "fake" },
    start = { x = ${mapx0}, y = 2000, z = 0 },
    wc3_to_wow = { scale = 1 / 30.72, x0 = ${mapx0}, y0 = 2000 },
    creatures = "world/creatures-900.tsv" }
EOF
fi
# the server's stamp, last, by the converter's own code (this project's src/)
rm -f "${build}/server-stamp"
if [[ "${mode}" != nostamp ]]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
    FAKE_BUILD="${build}" FAKE_HERE="${here}" luajit -e "local here = os.getenv('FAKE_HERE')
        package.path = here .. '/src/?.lua;' .. here .. '/src/?/init.lua;' .. package.path
        require('wowbuild.server_stamp').write(os.getenv('FAKE_BUILD'))" || exit 1
fi
echo "converted ${map}"
