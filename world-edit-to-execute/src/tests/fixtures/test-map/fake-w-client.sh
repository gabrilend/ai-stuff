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
#
# Before its mode it refuses what the real one refuses in a test-map run
# (W client issue 1109, its 067-test-map.c), writing an error receipt with
# the real one's sentence and exiting with 2: no W_CLIENT_PASSWORD or an
# empty one, a bad --account or --realm. Good receipts are written in the
# real one's layout (its 068-goodbye.c: the comment line, one field a
# line, seconds to the millisecond). The first word may be the client's
# folder, as scripts/run takes it; it is recorded as client-dir=.

client_dir=""
if [[ -n "$1" && "$1" != --* && -n "$2" && "$2" != --* ]]; then client_dir="$1"; shift; fi
mode="$1"; shift
folder="" receipt="" realm="" account="" refused=""
args=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --test-map) folder="$2"; shift 2 ;;
        --receipt) receipt="$2"; shift 2 ;;
        --realm)    # host:port, a port from 1 to 65535, no spaces (its read_realm)
            realm="$2"
            [[ "$2" =~ ^[^[:space:]]+:[0-9]+$ ]] && (( ${2##*:} >= 1 && ${2##*:} <= 65535 )) \
                || refused="--realm takes the login server as host:port, a port from 1 to 65535 (127.0.0.1:3724); \"$2\" isn't that"
            shift 2 ;;
        --camera)   # world x and y in yards, as the W client's read_camera takes them (its 067-test-map.c)
            [[ "$2" =~ ^-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?$ ]] || { echo "bad --camera $2" >&2; exit 2; }
            shift 2 ;;
        --account)  # 1 to 63 characters, no spaces (its read_account)
            account="$2"
            [[ ${#2} -ge 1 && ${#2} -le 63 && ! "$2" =~ [[:space:][:cntrl:]] ]] \
                || refused="--account takes an account name of 1 to 63 characters, with no spaces; \"$2\" isn't that"
            shift 2 ;;
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
    echo "client-dir=${client_dir}"
    echo "wete=${WETE:-}"
} > "${out}"

started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write() {   # the receipt, written whole: to a temporary name, then renamed
    printf '%s\n' "$1" > "${receipt}.part" && mv "${receipt}.part" "${receipt}"
}
ended="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
real() {    # the real one's layout (068-goodbye.c): reason, seconds, frames[, why already quoted]
    local text
    text="-- the W client's goodbye receipt (issue 1109): the editor's Test Map reads it back
return {
    format  = 1,
    map     = \"${folder}\",
    started = \"${started}\",
    ended   = \"${ended}\",
    seconds = $2,
    frames  = $3,
    reason  = \"$1\","
    [[ -n "$4" ]] && text="${text}
    why     = $4,"
    write "${text}
}"
}
if [[ -z "${W_CLIENT_PASSWORD:-}" && -z "${refused}" ]]; then
    state=empty; [[ -z "${W_CLIENT_PASSWORD+x}" ]] && state="not set"
    refused="a --test-map run reads the account's password from W_CLIENT_PASSWORD, and it is ${state} (it is never taken on the command line, where every user of this machine can read it)"
fi
if [[ -n "${refused}" ]]; then  # the start stops with a receipt saying why, and 2
    real error 0.000 0 "\"${refused//\"/\\\"}\""
    echo "${refused}" >&2
    exit 2
fi
case "${mode}" in
    closed) real closed 1.500 90 ;;
    lost) real lost-connection 4.000 240 ;;
    error) real error 0.500 3 '"The map ground tiles are missing: \"World\\Maps\\x\"\n(two lines)."' ;;
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
