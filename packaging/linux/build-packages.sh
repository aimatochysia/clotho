#!/usr/bin/env bash
# Builds the Linux release artifacts from a `flutter build linux --release`
# bundle:
#   clotho-<v>-linux-x86_64.tar.gz       portable folder
#   clotho-<v>-linux-amd64.deb           Debian/Ubuntu package
#   pkgroot/                             staged tree reused by the Arch package
# Usage: build-packages.sh <version> <bundle dir> <out dir>
set -euo pipefail

version="$1"
bundle="$(realpath "$2")"
out="$(realpath -m "$3")"
here="$(cd "$(dirname "$0")" && pwd)"
app_id="io.github.aimatochysia.clotho"
icon="$here/../../app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
mkdir -p "$out"

# Portable tarball.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
portable="$work/clotho-$version-linux-x86_64"
cp -a "$bundle" "$portable"
cp "$here/$app_id.desktop" "$portable/"
cp "$icon" "$portable/$app_id.png"
tar -C "$work" -czf "$out/clotho-$version-linux-x86_64.tar.gz" "$(basename "$portable")"

# Shared install tree: /usr/lib/clotho + launcher, desktop entry and icon.
root="$out/pkgroot"
rm -rf "$root"
install -d "$root/usr/lib/clotho" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/256x256/apps"
cp -a "$bundle/." "$root/usr/lib/clotho/"
ln -s ../lib/clotho/clotho "$root/usr/bin/clotho"
install -m644 "$here/$app_id.desktop" "$root/usr/share/applications/"
install -m644 "$icon" "$root/usr/share/icons/hicolor/256x256/apps/$app_id.png"

# Debian package. Debian versions may not contain '-' in the upstream part
# without a revision, so pre-release dashes become '~' (sorts before final).
deb="$work/deb"
cp -a "$root" "$deb"
install -d "$deb/DEBIAN"
size="$(du -sk "$deb/usr" | cut -f1)"
cat > "$deb/DEBIAN/control" <<CONTROL
Package: clotho
Version: ${version//-/\~}
Section: devel
Priority: optional
Architecture: amd64
Installed-Size: $size
Depends: libgtk-3-0 | libgtk-3-0t64, libsecret-1-0, libc6 (>= 2.35)
Recommends: git
Maintainer: Clotho <noreply@github.com>
Homepage: https://github.com/aimatochysia/clotho
Description: Manage Git and GitHub repositories anywhere on your disk
 Clotho shows the status, branches and history of all your Git repositories,
 fetches in the background, and commits, pulls and pushes with one click.
CONTROL
dpkg-deb --build --root-owner-group -Zxz "$deb" "$out/clotho-$version-linux-amd64.deb"
echo "Built Linux packages in $out"
