#!/bin/sh
# Builds meevpn-n9_<version>_armel.deb: app + root helper + engine.
# Usage: sh packaging/build-deb.sh [output-dir]
# Needs: dpkg-deb tools (ar, tar), python3 (PIL), sha1sum, md5sum, gcc-arm-linux-gnueabihf.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n 's/^APP_VERSION = .\(.*\).$/\1/p' "$ROOT/app/main.py")
OUT=${1:-$ROOT/dist}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
D=$T/data/opt/meevpn-n9
mkdir -p "$D/bin" "$D/app/qml" "$T/data/usr/share/applications" "$T/data/usr/share/icons/hicolor/80x80/apps" "$T/ctl"
sh "$ROOT/helper/build.sh" "$D/bin/meevpn-root" >/dev/null
sed "s/^ENGINE_VERSION=.*/ENGINE_VERSION=$VERSION/" "$ROOT/engine/engine.sh" > "$D/engine.sh"
cp "$ROOT/engine/dns.sh" "$D/dns.sh"
cp "$ROOT/app/main.py" "$D/app/"; cp "$ROOT/app/qml/"* "$D/app/qml/"
cp "$ROOT/LICENSE" "$D/LICENSE"
cp "$ROOT/packaging/meevpn-n9.desktop" "$T/data/usr/share/applications/"
cp "$ROOT/art/meevpn-n9.png" "$T/data/usr/share/icons/hicolor/80x80/apps/"
chmod -R u+rwX,go+rX,go-w "$T/data"
chmod 755 "$D/bin/meevpn-root" "$D/app/main.py" "$D/engine.sh" "$D/dns.sh"
SIZE=$(du -sk "$T/data" | cut -f1)
python3 - "$ROOT/packaging/control" "$T/ctl/control" "$VERSION" "$SIZE" "$ROOT/art/meevpn-n9.png" <<'P'
import sys, base64, io
from PIL import Image
src, dst, version, size, icon = sys.argv[1:]
buf = io.BytesIO(); Image.open(icon).resize((64, 64), Image.LANCZOS).save(buf, "PNG")
b = base64.b64encode(buf.getvalue()).decode("ascii")
lines = "\n".join(" " + b[i:i + 76] for i in range(0, len(b), 76))
t = open(src).read().replace("@VERSION@", version).replace("@SIZE@", size).replace("@ICON@", lines)
open(dst, "w").write(t)
P
(cd "$T/data" && find . -type f | sed 's#^\./##' | sort | xargs md5sum) > "$T/ctl/md5sums"
# digsigsums: without it aegis-dpkg ignores the <for path> request in _aegis
entry() { printf 'S 15 com.nokia.maemo H 40 %s R %d %s\n' "$1" "${#2}" "$2"; }
(cd "$T/data" && find . -type f | sed 's#^\./##' | sort | while read -r f; do
    entry "$(sha1sum "$f" | cut -d' ' -f1)" "$f"; done) > "$T/ctl/digsigsums"
cp "$ROOT/packaging/_aegis" "$T/_aegis"
chmod 644 "$T/ctl/"*
(cd "$T/ctl" && tar czf ../control.tar.gz --owner=0 --group=0 --numeric-owner --format=gnu ./control ./md5sums ./digsigsums)
# Aegis cannot read GNU long-name tar entries: every path must stay under 100 chars
long=$(cd "$T/data" && find . | awk 'length($0) > 95')
[ -z "$long" ] || { echo "ERROR: path too long for Aegis: $long" >&2; exit 1; }
(cd "$T/data" && tar czf ../data.tar.gz --owner=0 --group=0 --numeric-owner --format=gnu .)
echo 2.0 > "$T/debian-binary"
DEB="$OUT/meevpn-n9_${VERSION}_armel.deb"
rm -f "$DEB"
(cd "$T" && ar rc "$DEB" debian-binary control.tar.gz data.tar.gz _aegis)
ls -l "$DEB"; md5sum "$DEB"
