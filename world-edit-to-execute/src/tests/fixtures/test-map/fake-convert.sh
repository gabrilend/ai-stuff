#!/bin/bash
# A fake W02 converter for the Test Map tests (issue 913). It stands where
# src/cli/wow-convert.lua does, writing a small build of the same shape:
#
#   fake-convert.sh <mode> <map.w3x> <build folder>
#
#   ok        writes a small build: the map's checksum, a server row, and a
#             conversion-report.lua whose placement puts WC3's (0, 0) at
#             the W client's (1000, 2000), 30.72 WC3 units a yard, the map
#             running from -5000 to 5000 both ways
#   noreport  as ok, without the report (a converter that writes none)
#   noplace   as ok, the report giving no placement
#   badplace  as ok, the placement's scale not a number
#   toonew    as ok, the report's format 2
#   fail      exits with code 2
#   slow      takes a second, then as ok
mode="$1" map="$2" build="$3"
[[ -f "${map}" ]] || { echo "no map ${map}" >&2; exit 1; }
case "${mode}" in
    fail) echo "conversion failed (pretend)" >&2; exit 2 ;;
    slow) sleep 1 ;;
esac
mkdir -p "${build}/server"
cksum < "${map}" > "${build}/map.cksum"
echo "-- rows for $(basename "${map}")" > "${build}/server/rows.sql"
report="${build}/conversion-report.lua"
rm -f "${report}"
format=1 scale="1 / 30.72" placement=yes
case "${mode}" in
    noreport) placement="" ;;
    noplace)  placement=none ;;
    badplace) scale='"wide"' ;;
    toonew)   format=2 ;;
esac
if [[ "${placement}" == yes ]]; then
    cat > "${report}" <<EOF
-- the fake converter's report
return { format = ${format}, map = "fake", placement = { client = {
    scale = ${scale}, x0 = 1000, y0 = 2000, wc3_min = { -5000, -5000 }, wc3_max = { 5000, 5000 } } } }
EOF
elif [[ "${placement}" == none ]]; then
    echo 'return { format = 1, map = "fake" }' > "${report}"
fi
echo "converted ${map}"
