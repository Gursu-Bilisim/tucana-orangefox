# OrangeFox / TWRP source changes

The recovery images in this repository's releases are built from OrangeFox Recovery
`fox_12.1` with the changes in `bootable_recovery.diff` applied to `bootable/recovery`.
TWRP and OrangeFox are licensed under the GNU General Public License, version 3 or later,
and so are these changes (see `COPYING`).

Base revision: see `BASE_REVISION`.

## What the patch changes

- `partitionmanager.cpp`: when the ROM's fstab is copied to `/etc/additional.fstab`,
  `/dev/block/bootdevice/by-name/` paths are rewritten to `/dev/block/by-name/`, so that
  `/data` is resolved to its block device and FBE is detected.
- `partitionmanager.cpp`: `/mnt/vendor/persist` and `/vendor/firmware_mnt` are mounted
  before decryption.
- Theme (`gui/theme/portrait_hdpi/themes/navbar.xml`): gesture navigation is off by default
  and the screen height no longer adds 96 px for a hidden navigation bar, which kept the
  bottom menu inside the screen and the lock-screen swipe usable on tucana.

## Applying

```bash
cd <OrangeFox source tree>/bootable/recovery
git checkout <base revision>
git apply <this repository>/recovery-patches/bootable_recovery.diff
```
