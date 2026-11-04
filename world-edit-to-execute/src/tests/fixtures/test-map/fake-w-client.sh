#!/bin/bash
# A fake W client for the Test Map tests (issue 913). No W client runs in
# the tests. Takes the contract's options after its mode:
#
#   fake-w-client.sh <mode> --test-map <folder> --receipt <file>
#       [--camera x,y] [--realm host:port] [--account name]
#
# Writes what it was given to <folder of the receipt>/fake-w-client.args
# (each argument on a line; the password's checksum, never the password),
# then by mode:
#   closed, lost, error   a good receipt with that reason
#   crash                 exits with code 3 and no receipt
#   badopt                exits with code 2 and no receipt (an option refused)
#   malformed             a receipt without frames
#   toonew                a receipt of format 2
#   loop                  a "receipt" that runs forever
#   othermap              a receipt for another folder
#   hang                  stays open until it is stopped

mode="$1"; shift
folder="" receipt="" realm=""
args=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --test-map) folder="$2"; shift 2 ;;
        --receipt) receipt="$2"; shift 2 ;;
        --realm) realm="$2"; shift 2 ;;
        --camera|--account) shift 2 ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
done
[[ -n "${folder}" && -n "${receipt}" ]] || { echo "needs --test-map and --receipt" >&2; exit 2; }

out="$(dirname "${receipt}")/fake-w-client.args"
{
    printf '%s\n' "${args[@]}"
    if [[ -n "${W_CLIENT_PASSWORD+x}" ]]; then
        echo "password-cksum=$(printf '%s' "${W_CLIENT_PASSWORD}" | cksum | cut -d' ' -f1)"
    else
        echo "password-cksum=none"
    fi
    realm_state=closed
    if [[ -n "${realm}" ]] && (exec 3<>"/dev/tcp/${realm%%:*}/${realm##*:}") 2>/dev/null; then
        realm_state=open
    fi
    echo "realm=${realm_state}"
    echo "pwd=$(pwd)"
} > "${out}"

started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write() {   # the receipt, written whole: to a temporary name, then renamed
    printf '%s\n' "$1" > "${receipt}.part" && mv "${receipt}.part" "${receipt}"
}
ended="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
case "${mode}" in
    closed) write "return { format = 1, map = \"${folder}\", started = \"${started}\", ended = \"${ended}\", seconds = 1.5, frames = 90, reason = \"closed\" }" ;;
    lost) write "return { format = 1, map = \"${folder}\", started = \"${started}\", ended = \"${ended}\", seconds = 4, frames = 240, reason = \"lost-connection\" }" ;;
    error) write "return { format = 1, map = \"${folder}\", started = \"${started}\", ended = \"${ended}\", seconds = 0.5, frames = 3, reason = \"error\", why = \"The map's ground tiles are missing.\" }" ;;
    crash) echo "segmentation fault (pretend)" >&2; exit 3 ;;
    badopt) echo "unknown option (pretend)" >&2; exit 2 ;;
    malformed) write "return { format = 1, map = \"${folder}\", started = \"${started}\", ended = \"${ended}\", seconds = 1, reason = \"closed\" }" ;;
    toonew) write "return { format = 2, map = \"${folder}\", started = \"${started}\", ended = \"${ended}\", seconds = 1, frames = 60, reason = \"closed\" }" ;;
    loop) write "while true do end" ;;
    othermap) write "return { format = 1, map = \"/somewhere/else\", started = \"${started}\", ended = \"${ended}\", seconds = 1, frames = 60, reason = \"closed\" }" ;;
    hang) sleep 600 & wait ;;
    *) echo "unknown mode ${mode}" >&2; exit 2 ;;
esac
exit 0
