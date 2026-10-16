# OrangeFox / TWRP source changes

The recovery images in this repository's releases are built from OrangeFox Recovery
`fox_12.1` with the changes in `bootable_recovery.diff` applied to `bootable/recovery`.
TWRP and OrangeFox are licensed under the GNU General Public License, version 3 or later,
and so are these changes (see `COPYING`).

Base revision: OrangeFox `bootable/recovery`, branch `fox_12.1`, commit
`cbcc4f713dbef98d76d6d2cfd019b1ebfd9418e9` (20 September 2026). Details in `BASE_REVISION`.

## What the patch changes

- `partitionmanager.cpp`: when the ROM's fstab is copied to `/etc/additional.fstab`,
  `/dev/block/bootdevice/by-name/` paths are rewritten to `/dev/block/by-name/`, so that
  `/data` is resolved to its block device and FBE is detected.
- `partitionmanager.cpp`: before metadata decryption, the `persist` partition (ext4) is mounted
  read-only at `/mnt/vendor/persist` and the `modem` partition (vfat) read-only at
  `/vendor/firmware_mnt`, so that the QTI keymaster and its listeners find their files.
- Theme (`gui/theme/portrait_hdpi/themes/navbar.xml`): gesture navigation is off by default
  and the screen height no longer adds 96 px for a hidden navigation bar, which kept the
  bottom menu inside the screen and the lock-screen swipe usable on tucana.

## Applying

```bash
cd <OrangeFox source tree>/bootable/recovery
git checkout cbcc4f713dbef98d76d6d2cfd019b1ebfd9418e9
git apply <this repository>/recovery-patches/bootable_recovery.diff
```

`navbar.xml` uses CRLF line endings upstream; the diff keeps them, so apply it without
converting line endings.
