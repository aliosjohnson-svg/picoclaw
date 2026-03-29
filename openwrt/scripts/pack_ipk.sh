#!/bin/bash
# Pack a staged directory into an OpenWRT IPK file (ar archive).
# Usage: pack_ipk.sh <staged_dir> <output.ipk>
#
# staged_dir layout:
#   control         (required)  package metadata
#   conffiles       (optional)  list of config files
#   postinst        (optional)  post-install script
#   prerm           (optional)  pre-remove script
#   usr/, etc/, ... (optional)  installed filesystem tree

set -euo pipefail

SRC="${1:?Usage: pack_ipk.sh <staged_dir> <output.ipk>}"
OUT="${2:?Usage: pack_ipk.sh <staged_dir> <output.ipk>}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Strip leading whitespace from control files (heredoc indentation artifact)
for f in control conffiles postinst prerm preinst postrm; do
    [ -f "$SRC/$f" ] || continue
    sed 's/^[[:space:]]*//' "$SRC/$f" > "$tmp/_${f}_clean"
    mv "$tmp/_${f}_clean" "$SRC/$f"
done

# data.tar.gz — installed filesystem (exclude IPK control-plane files)
(
    cd "$SRC"
    find . \( \
        -name "control"   -o -name "conffiles" -o \
        -name "postinst"  -o -name "prerm"     -o \
        -name "preinst"   -o -name "postrm" \
    \) -prune -o -not -name "." -print \
    | sort \
    | tar czf "$tmp/data.tar.gz" --no-recursion -T -
)

# control.tar.gz — package metadata files only
(
    cd "$SRC"
    meta=""
    for f in control conffiles postinst prerm preinst postrm; do
        [ -f "$f" ] && meta="$meta ./$f"
    done
    # shellcheck disable=SC2086
    tar czf "$tmp/control.tar.gz" $meta
)

echo "2.0" > "$tmp/debian-binary"

mkdir -p "$(dirname "$OUT")"
(cd "$tmp" && ar rc "$OUT" debian-binary control.tar.gz data.tar.gz)
echo "Packed: $OUT  ($(du -sh "$OUT" | cut -f1))"
