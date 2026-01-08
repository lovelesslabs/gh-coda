# helpers.sh - Basic utility functions

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
