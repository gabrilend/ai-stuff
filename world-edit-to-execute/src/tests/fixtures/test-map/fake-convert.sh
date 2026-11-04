#!/bin/bash
# A fake W02 converter for the Test Map tests (issue 913). W02's converter
# isn't built yet; this stands where it will:
#
#   fake-convert.sh <mode> <map.w3x> <build folder>
#
#   ok     writes a small build: the map's checksum, a server row
#   fail   exits with code 2
#   slow   takes a second, then as ok
mode="$1" map="$2" build="$3"
[[ -f "${map}" ]] || { echo "no map ${map}" >&2; exit 1; }
case "${mode}" in
    fail) echo "conversion failed (pretend)" >&2; exit 2 ;;
    slow) sleep 1 ;;
esac
mkdir -p "${build}/server"
cksum < "${map}" > "${build}/map.cksum"
echo "-- rows for $(basename "${map}")" > "${build}/server/rows.sql"
echo "converted ${map}"
