#!/usr/bin/env bash
#
# install.sh — the self-installer that rides on the cable image.
#
# In one sentence: run this once from the mounted cable and it checks the few
# things it needs, asks your permission, and copies the system into place with a
# launcher you can run from anywhere. There is no hidden autorun: silently running
# code off a plugged-in USB device is precisely the BadUSB attack this whole project
# exists to refuse, so installation is always one explicit, consenting command.
#
# Usage:  install.sh [options]
#   --target DIR    where to install the bundle (default: ~/.local/share/usb-c-universal-encoder)
#   --bindir DIR    where to put the launcher   (default: ~/.local/bin)
#   --in-place      do not copy; make a launcher that runs the bundle where it sits
#   --uninstall     remove a previous install
#   --yes, -y       skip the consent prompt (for scripted/tested installs)
#   --dir DIR       treat DIR as the bundle root instead of this script's folder

set -euo pipefail

# ${DIR} is the bundle root — i.e. the mounted cable. The installer travels to
# unknown mountpoints, so it self-locates by default; --dir / DIR= can override.
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${DIR:-$SELF}"

TARGET="$HOME/.local/share/usb-c-universal-encoder"
BINDIR="$HOME/.local/bin"
ASSUME_YES=0
INPLACE=0
UNINSTALL=0

# {{{ parse_args
while [ $# -gt 0 ]; do
    case "$1" in
        --target)    TARGET="$2"; shift 2 ;;
        --bindir)    BINDIR="$2"; shift 2 ;;
        --in-place)  INPLACE=1; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        --yes|-y)    ASSUME_YES=1; shift ;;
        --dir)       DIR="$2"; shift 2 ;;
        -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)           echo "install: unknown option '$1'" >&2; exit 2 ;;
    esac
done
# }}}

LAUNCHER="$BINDIR/usb-c-encoder"

# Uninstall path: undo a previous install and leave. This is the reverse of the
# install below — remove the copied bundle and the launcher, nothing else.
if [ "$UNINSTALL" -eq 1 ]; then
    rm -rf "$TARGET"
    rm -f "$LAUNCHER"
    echo "install: removed $TARGET and $LAUNCHER"
    exit 0
fi

# Dependency check. luajit is REQUIRED — without it nothing runs, so we stop with a
# clear error rather than install a half-working system the user would have to debug.
if ! command -v luajit >/dev/null; then
    echo "ERROR: luajit is required but was not found on PATH." >&2
    echo "       Install luajit, then re-run this installer." >&2
    exit 1
fi

# libfuse is OPTIONAL — it only enables mounting a peer under /mnt/. Its absence is
# reported as a disabled capability (not a silent fallback), so the user knows
# exactly what will and will not work.
MOUNT_CAP="unavailable (libfuse not found; file transfer still works)"
if command -v pkg-config >/dev/null && { pkg-config --exists fuse3 || pkg-config --exists fuse; }; then
    MOUNT_CAP="available"
fi

# Show exactly what will happen, then ask — unless consent was pre-granted with -y.
echo "About to install the USB-C Universal Encoder:"
echo "  from     : $DIR"
if [ "$INPLACE" -eq 1 ]; then
    echo "  mode     : run in place (no copy)"
else
    echo "  into     : $TARGET"
fi
echo "  launcher : $LAUNCHER"
echo "  mount    : $MOUNT_CAP"
if [ "$ASSUME_YES" -ne 1 ]; then
    printf 'Proceed? [y/N] '
    read -r answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "install: aborted (nothing changed)."; exit 0 ;;
    esac
fi

# Decide where the launcher will point. In-place leaves the bundle on the cable and
# runs it there; the default copies it to TARGET so it survives the cable leaving.
if [ "$INPLACE" -eq 1 ]; then
    RUNROOT="$DIR"
else
    mkdir -p "$TARGET"
    cp -a "$DIR/." "$TARGET/"
    # Drop scratch that may have tagged along (including a dangling tmp symlink);
    # the launcher recreates writable tmp/ and output/ at run time.
    rm -rf "$TARGET/tmp" "$TARGET/output"
    RUNROOT="$TARGET"
fi

# Generate the launcher: a tiny shim on PATH that hands off to the bundle's own
# entry point. Everything it needs to know is baked in as an absolute path.
mkdir -p "$BINDIR"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# usb-c-encoder — generated launcher; runs the installed bundle.
exec "$RUNROOT/launch.sh" "\$@"
EOF
chmod +x "$LAUNCHER"

# Leave a small record in the bundle's own scratch area.
LOGDIR="$RUNROOT/tmp"
mkdir -p "$LOGDIR"
echo "installed $(date -u +%Y-%m-%dT%H:%M:%SZ) from $DIR" >> "$LOGDIR/install.log"

echo "install: done."
echo "  run:  $LAUNCHER          (start with:  $LAUNCHER smoke )"
case ":$PATH:" in
    *":$BINDIR:"*) ;;
    *) echo "  note: $BINDIR is not on your PATH yet — add it to use the short name." ;;
esac
