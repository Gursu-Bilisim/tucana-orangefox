#!/usr/bin/env bash
set -euo pipefail
OUT=~/fox_12.1/out/target/product/tucana
TREE=~/fox_12.1/device/xiaomi/tucana
REPO=Gursu-Bilisim/tucana-orangefox
PATCH=$(grep '^PLATFORM_SECURITY_PATCH' "$TREE/BoardConfig.mk" | awk '{print $3}')
TAG="v$(date +%Y.%m.%d)${1:+-$1}"
W=$(mktemp -d)
cp "$OUT/OrangeFox-R12.0_1_Retrofit-Unofficial-tucana.img" "$W/OrangeFox-tucana-$TAG-los23-$PATCH.img"
cp "$OUT/OrangeFox-R12.0_1_Retrofit-Unofficial-tucana.zip" "$W/OrangeFox-tucana-$TAG-los23-$PATCH.zip"
(cd "$W" && sha256sum *.img *.zip > SHA256SUMS)
cat > "$W/notes.md" <<NOTES
OrangeFox R12.0_1 for Xiaomi Mi Note 10 / Mi Note 10 Pro (tucana), retrofit dynamic partitions.

- ROM: LineageOS 23.2, security patch $PATCH
- Decryption: FBE v2 + metadata encryption + wrapped keys (wrappedkey_v0)
- Tested on Mi Note 10 and Mi Note 10 Pro

**Flash only if your ROM's security patch is $PATCH.** A mismatch can make keymaster upgrade
the metadata key, after which the ROM may no longer unlock /data. If you use spoofing modules,
getprop may show a fake patch level; check the boot image header instead.

- \`.img\`: fastboot flash recovery
- \`.zip\`: install from a running OrangeFox
NOTES
gh release create "$TAG" "$W"/*.img "$W"/*.zip "$W/SHA256SUMS" \
  --repo "$REPO" --title "$TAG" --notes-file "$W/notes.md"
echo "Yayımlandı: $TAG"
