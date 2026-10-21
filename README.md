# tucana-orangefox

OrangeFox R12.0_1 (fox_12.1) for the Xiaomi Mi Note 10 and Mi Note 10 Pro (tucana), retrofit
dynamic partitions, for LineageOS. Installed to the recovery partition.

## Read this before flashing

- Keymaster binds the metadata encryption key to the Android version and security patch level.
  The recovery must report the same values as the ROM's `boot.img`. With a lower patch level
  `/data` stays encrypted (keymaster error -38); with a higher one keymaster may upgrade the key,
  after which the ROM can no longer unlock `/data`. Run `patch-check.ps1` before flashing.
- With spoofing modules `getprop` may show a fake patch level; `patch-check.ps1` reads the boot
  image header instead.
- The tucana bootloader does not act on `fastboot reboot recovery`. After flashing, hold
  Power + Volume Up to boot into recovery.

## Installing

```
fastboot flash recovery <OrangeFox .img>
```

Then hold Power + Volume Up. From a running OrangeFox the `.zip` can be installed instead.

## Updating LineageOS from OrangeFox

The LineageOS zip can be installed from OrangeFox (Files, then Install). It does not write the
recovery partition, so OrangeFox stays in place. Keep the LineageOS developer option
"Update recovery" off; with it on, the ROM replaces the recovery at boot.

When the new LineageOS build has a new security patch level:

1. Install the ROM zip with the OrangeFox build that matches the current ROM.
2. Boot the new ROM once.
3. Flash the OrangeFox build that matches the new patch level, with
   `fastboot flash recovery <OrangeFox .img>` or from OrangeFox (Flash image) from a USB stick.
   At this point the older OrangeFox can no longer decrypt `/data`.

Booting the newer OrangeFox while the older ROM is still installed can upgrade the key, after
which that ROM cannot unlock `/data`.

To copy files to the phone: MTP, or `adb push <file> /sdcard/Download/` once `/data` is
decrypted. After Format Data `/sdcard` does not exist until the ROM has booted once; use a USB
stick or `adb push <file> /tmp/` (kept in RAM until reboot).

## USB storage

A USB stick shows up as USB-OTG on the Mount page and as USB Storage in the storage menu of the
Files tab. FAT32, exFAT (kernel driver) and NTFS (`ntfs-3g`) are mounted. The phone has one USB
port: while a stick or hub is attached the phone is the USB host, so MTP and ADB are not
available. Turn MTP off on the Mount page before attaching the stick; with MTP still on, the first
mount attempt can fail.

## Known issue: first touch after boot

The first touch after boot is cut short by the touch controller (ST FTS panel): the kernel
reports a release while the finger is still on the screen. A pattern drawn as the first touch
arrives incomplete and counts as one failed attempt; later touches are normal. Tap an empty area
of the screen once before drawing the pattern. The same happens in the ROM, where it can cost one
digit of the SIM PIN. The cause is in the kernel and device tree (the Goodix and FTS drivers
configure the same reset and interrupt pins differently), not in OrangeFox.

## Building

1. Sync OrangeFox `fox_12.1` (see the OrangeFox wiki) into `<OrangeFox source tree>`.
2. Clone this repository to `<OrangeFox source tree>/device/xiaomi/tucana`.
3. Apply [recovery-patches/](recovery-patches/README.md) to `bootable/recovery`.
4. Build:

```bash
cd <OrangeFox source tree>
source build/envsetup.sh
for v in $(compgen -e | grep -E '^(OF_|FOX_)'); do unset "$v"; done
export TARGET_PRODUCT=twrp_tucana
source device/xiaomi/tucana/vendorsetup.sh
rm -f /tmp/tucana/fox_env.sh
lunch twrp_tucana-eng
touch bootable/recovery/orangefox.mk
mka adbd libminuitwrp mount.ntfs fsck.ntfs mkfs.ntfs libntfs-3g libfuse-lite
P=out/target/product/tucana
cp $P/system/lib64/{libminuitwrp,libntfs-3g,libfuse-lite}.so $P/recovery/root/system/lib64/
cp $P/system/bin/{mount,fsck,mkfs}.ntfs $P/recovery/root/system/bin/
mka recoveryimage
```

Run the commands on separate lines: `source build/envsetup.sh` can return a non-zero status, so
a chain joined with `&&` stops after it. The output is
`out/target/product/tucana/OrangeFox-*-tucana.img` and `.zip`.

Why the extra lines:

- `vendorsetup.sh` exports its values only while `TARGET_PRODUCT` is `twrp_tucana`.
  `envsetup.sh` sources every `device/*/*/vendorsetup.sh` in alphabetical order, so in a source
  tree with other OrangeFox devices another device's values would otherwise be used.
- `lunch` writes the OrangeFox settings to `/tmp/tucana/fox_env.sh`, and the packaging step
  reads them from there. Check that `FOX_BUILD_DEVICE` is `tucana` and that
  `FOX_VIRTUAL_AB_DEVICE`, `FOX_VENDOR_BOOT_RECOVERY` and `FOX_AB_DEVICE` are not `1`. The values
  compiled into the recovery come from `bootable/recovery/orangefox.mk`, which Kati only re-reads
  when a makefile changes, hence the `touch`.
- `libminuitwrp.so` is copied into the ramdisk by a post-install command that does not run
  again in an incremental build. Since the colour change in `recovery-patches/`, the `recovery`
  binary needs the new library (`res_swap_red_blue`); an old copy keeps the recovery from
  starting. `recovery-inspect.ps1` checks this in its Display group. The NTFS tools
  (`TW_INCLUDE_NTFS_3G`: `mount.ntfs`, `fsck.ntfs`, `mkfs.ntfs`, `libntfs-3g.so`,
  `libfuse-lite.so`) reach the ramdisk the same way and are copied by hand too.

### Updating for a new LineageOS build

Take `kernel` and `dtb.img` from the new `boot.img` and `dtbo.img` from the new `dtbo.img`, then
set `PLATFORM_SECURITY_PATCH` (and `PLATFORM_VERSION` for a new Android version) in
`BoardConfig.mk` from the `boot.img` header. `VENDOR_SECURITY_PATCH` comes from
`ro.vendor.build.security_patch` in the ROM's `vendor/build.prop`.

## Tools

The two PowerShell scripts are shared by the Gursu-Bilisim OrangeFox repositories (tucana,
bramble, jackpotlte). They only read files and work in Windows PowerShell 5.1 and PowerShell 7.

### patch-check.ps1

Checks whether a recovery image fits a ROM build before you flash it. For a tucana
`recovery.img` the verdict comes from the image header: Android version and security patch must
match the ROM's `boot.img`. The kernel version is shown for information; a kernel difference
does not block decryption on tucana.

```
powershell -ExecutionPolicy Bypass -File patch-check.ps1 -BootImg <boot.img> -RecoveryImg <OrangeFox .img | .zip>
powershell -ExecutionPolicy Bypass -File patch-check.ps1 -Zip <ota.zip> -RecoveryImg <OrangeFox .img | .zip>
```

Optional parameters: `-GoDumper`, `-MikDir` and `-PayloadTool` point to the payload tools,
`-WorkDir` sets the folder for temporary files (A/B packages only).

### recovery-inspect.ps1

Lists what an OrangeFox image contains, without flashing it. The script reads the device from
the image and runs that device's checks. For tucana: header v2 and DTB, the
`/dev/block/bootdevice` link, the QTI decryption chain (qseecomd and its listener libraries,
keymaster 4.1 and gatekeeper 1.0, VINTF manifest with keystore2), health HAL, display library and
USB. Accepts the `.img` or the OrangeFox `.zip`.

```
powershell -ExecutionPolicy Bypass -File recovery-inspect.ps1 -Img <OrangeFox .img | .zip>
```

### release.sh

Publishes the latest build as a GitHub release: image, zip, both scripts, `TEST-NOTES.md` and
`SHA256SUMS`. It stops if `test-notes.md` is older than the image, if the image's SHA-256 is not
recorded in `test-notes.md`, or if `bootable/recovery` no longer matches
`recovery-patches/bootable_recovery.diff`. `./release.sh r2` adds a suffix for a second release
on the same day; `FOX_TREE=<OrangeFox source tree> ./release.sh` if the build is not three
folders above the device tree.

## Credits and license

This tree started as a fork of [LIECOTI/tucana-orangefox](https://github.com/LIECOTI/tucana-orangefox)
and uses work from TeamWin, LineageOS and OrangeFox. [NOTICE](NOTICE) lists every source and its license.

- Files written for this repository: Apache License 2.0 ([LICENSE](LICENSE)).
- Changes to the OrangeFox/TWRP recovery source: GPL-3.0-or-later, published in
  [recovery-patches/](recovery-patches/).
- Prebuilt Qualcomm and Xiaomi vendor files: not covered by either license.

If you reuse parts of this tree, keep the NOTICE file and credit the sources it lists.
