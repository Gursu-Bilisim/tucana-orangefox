#!/usr/bin/env bash
set -euo pipefail
# TREE: <device tree folder>, the folder this script is in (device/xiaomi/tucana).
# FOX_TREE: <OrangeFox source tree>, three levels above it. Set FOX_TREE to override.
# Before running: update test-notes.md for this build (including the tested image's
# SHA-256), commit and push.
TREE=$(cd "$(dirname "$0")" && pwd)
FOX_TREE=${FOX_TREE:-$(cd "$TREE/../../.." && pwd)}
OUT=$FOX_TREE/out/target/product/tucana
IMG=$(ls -t "$OUT"/OrangeFox-*-tucana.img 2>/dev/null | head -1 || true)
ZIP=${IMG%.img}.zip
[ -n "$IMG" ] && [ -f "$ZIP" ] || { echo "No OrangeFox build (.img and .zip) found in $OUT. Set FOX_TREE=<OrangeFox source tree>." >&2; exit 1; }
[ -f "$TREE/test-notes.md" ] || { echo "test-notes.md is missing." >&2; exit 1; }
if [ "$TREE/test-notes.md" -ot "$IMG" ]; then
  echo "test-notes.md is older than $(basename "$IMG"). Update it for this build first." >&2; exit 1
fi
SUM=$(sha256sum "$IMG" | cut -d' ' -f1)
grep -q "$SUM" "$TREE/test-notes.md" || {
  echo "The SHA-256 of $(basename "$IMG") ($SUM) is not in test-notes.md. Test this build and record its hash first." >&2; exit 1; }

# The recovery is built from OrangeFox bootable/recovery with recovery-patches/bootable_recovery.diff.
BASE=$(awk '/^bootable_recovery.diff/{f=1} f&&/^commit:/{print $2; exit}' "$TREE/recovery-patches/BASE_REVISION")
if ! git -C "$FOX_TREE/bootable/recovery" diff "$BASE" | cmp -s - "$TREE/recovery-patches/bootable_recovery.diff"; then
  echo "bootable/recovery differs from recovery-patches/bootable_recovery.diff. Regenerate the patch, commit it and push." >&2; exit 1
fi

REPO=Gursu-Bilisim/tucana-orangefox
PATCH=$(grep -E '^PLATFORM_SECURITY_PATCH[[:space:]]*:=' "$TREE/BoardConfig.mk" | awk '{print $3}')
VPATCH=$(grep -E '^VENDOR_SECURITY_PATCH[[:space:]]*:=' "$TREE/BoardConfig.mk" | awk '{print $3}')
PV=$(grep -E '^PLATFORM_VERSION[[:space:]]*:=' "$TREE/BoardConfig.mk" | awk '{print $3}')
case "$PV" in
  16) LOS=23.2 ;;
  17) LOS=24.0 ;;
  *) echo "Unknown PLATFORM_VERSION $PV; add its LineageOS version to release.sh." >&2; exit 1 ;;
esac
TAG="v$(date +%Y.%m.%d)${1:+-$1}"
NAME="OrangeFox-tucana-$TAG-los${LOS%%.*}-$PATCH"
W=$(mktemp -d)
cp "$IMG" "$W/$NAME.img"
cp "$ZIP" "$W/$NAME.zip"
cp "$TREE/patch-check.ps1" "$TREE/recovery-inspect.ps1" "$W/"
cp "$TREE/test-notes.md" "$W/TEST-NOTES.md"
(cd "$W" && sha256sum *.img *.zip *.ps1 TEST-NOTES.md > SHA256SUMS)
{
cat <<NOTES
OrangeFox R12.0_1 for Xiaomi Mi Note 10 / Mi Note 10 Pro (tucana), retrofit dynamic partitions.
Installed to the recovery partition.

- ROM: LineageOS $LOS (Android $PV), security patch $PATCH, vendor patch $VPATCH
  (build named in the test notes below)
- Decryption: FBE v2 + metadata encryption + wrapped keys (wrappedkey_v0)

**Flash only if your ROM reports the same Android version and security patch.** Keymaster binds
the metadata key to both. With a lower patch level /data stays encrypted (keymaster error -38);
with a higher one keymaster may upgrade the key, after which the ROM may no longer unlock /data.
If you use spoofing modules, getprop may show a fake patch level; \`patch-check.ps1\` reads the
boot image header instead.

- \`.img\`: \`fastboot flash recovery <img>\`, then hold Power + Volume Up to boot into recovery
  (the tucana bootloader does not act on \`fastboot reboot recovery\`)
- \`.zip\`: install from a running OrangeFox
- \`patch-check.ps1 -BootImg <ROM boot.img> -RecoveryImg <img>\` or \`-Zip <ota.zip>\`
- \`recovery-inspect.ps1 -Img <img or zip>\`

Source: device tree in this repository at tag $TAG; changes to the OrangeFox/TWRP recovery
source (GPL-3.0-or-later) in \`recovery-patches/\`. Credits: see NOTICE.

NOTES
cat "$TREE/test-notes.md"
} > "$W/notes.md"
gh release create "$TAG" "$W"/*.img "$W"/*.zip "$W"/*.ps1 "$W/TEST-NOTES.md" "$W/SHA256SUMS" \
  --repo "$REPO" --title "$TAG" --notes-file "$W/notes.md"
echo "Published: $TAG"
