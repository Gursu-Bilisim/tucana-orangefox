# OrangeFox / TWRP source changes

The recovery images in this repository's releases are built from OrangeFox Recovery `fox_12.1`
with two patches applied outside `device/xiaomi/tucana`. Base revisions are listed in
`BASE_REVISION`.

The same source tree also builds
[Gursu-Bilisim/bramble-orangefox](https://github.com/Gursu-Bilisim/bramble-orangefox),
[Gursu-Bilisim/jackpotlte-orangefox](https://github.com/Gursu-Bilisim/jackpotlte-orangefox) and
[Gursu-Bilisim/gts7xlwifi-orangefox](https://github.com/Gursu-Bilisim/gts7xlwifi-orangefox), so the
patches contain the changes made for those devices as well.

## bootable_recovery.diff

Applies to OrangeFox `bootable/recovery`, branch `fox_12.1`, commit
`cbcc4f713dbef98d76d6d2cfd019b1ebfd9418e9` (20 September 2026). TWRP and OrangeFox are licensed
under the GNU General Public License, version 3 or later, and so are these changes (see
`COPYING`).

Made for tucana:

- `partitionmanager.cpp`: when the ROM's fstab is copied to `/etc/additional.fstab`,
  `/dev/block/bootdevice/by-name/` paths are rewritten to `/dev/block/by-name/`, so that
  `/data` is resolved to its block device and FBE is detected.
- `partitionmanager.cpp`: before metadata decryption, the `persist` partition (ext4) is mounted
  read-only at `/mnt/vendor/persist` and the `modem` partition (vfat) read-only at
  `/vendor/firmware_mnt`, so that the QTI keymaster and its listeners find their files. `persist`
  is only mounted when `/proc/mounts` has nothing at `/mnt/vendor/persist` yet (on gts7xlwifi
  `init.recovery.qcom.rc` mounts it there, and a second mount printed `ERROR: 1` in red). On A/B
  devices the modem partition name gets the slot suffix, and nothing is mounted when
  `/vendor/firmware_mnt/image` already exists. tucana is not A/B, so the partition name stays
  `modem`.
- `orangefox.mk`, `data.cpp`, `gui/pages.cpp`: new build variable `OF_SCREEN_BOTTOM_INSET`
  (pixels, default 0). The theme variables `screen_original_h` and `screen_h` become
  `OF_SCREEN_H` minus the inset, so the lock-screen swipe, the navigation buttons and the bottom
  menu move up by that amount. The theme is still scaled to the full `OF_SCREEN_H` (new constant
  `screen_full_h`), so nothing is stretched. With the default of 0 nothing changes (tucana's
  screen curves at the bottom edge).
- Theme (`pages/templates/templates.xml`, `resources/vars.xml`): the "show password" eye icon on
  the decrypt page only reacted to touches on its 64x46 px image. An invisible 144x144 px button
  centred on the icon (`pass_show_touch_x`, `pass_show_touch_y`) now does the same (touches 2 to
  50 px below the icon were missed on both test phones).
- Theme (`gui/theme/portrait_hdpi/themes/navbar.xml`): gesture navigation is off by default
  and the screen height no longer adds 96 px for a hidden navigation bar, which kept the
  bottom menu inside the screen and the lock-screen swipe usable on tucana.

Made for the other devices and active here too:

- `gui/patternpassword.cpp`, `gui/objects.hpp`: `GUIPatternPassword::IsInRegion`. A dot accepts
  touches within three dot radii of its centre, which reaches past the pattern's placement box
  for the corner dots. A touch that started there was outside the box, so the page ignored the
  whole gesture. The pattern now also claims touches that hit a dot (made for bramble).
- `minuitwrp/graphics.cpp`: `gr_blit()` clamps the drawn area to the size of the source surface
  (made for gts7xlwifi, where `TW_ROTATION := 270` made the console overlay read past the end of
  an image buffer and crash). Without rotation only pixels read from outside the image are lost.

Made for the other devices, without effect here:

- `minuitwrp/resources.cpp`, `minuitwrp/include/minuitwrp/minui.h`, `gui/nanosvg.cpp`,
  `gui/resources.cpp`: on devices built with `TARGET_RECOVERY_PIXEL_FORMAT := ABGR_8888`
  (`res_swap_red_blue()` returns 1), SVG output, tints and shapes swap red and blue (made for
  jackpotlte). tucana uses `RGBX_8888`, where the function returns 0 and the colours do not
  change; the `recovery` binary still needs the new `libminuitwrp.so`.
- `minuitwrp/graphics.cpp`, `minuitwrp/truetype.cpp`: the rotated copies of images and text are
  allocated with two spare, zeroed rows (made for gts7xlwifi). Only used with `TW_ROTATION`.

## system_vold.diff

Applies to TeamWin `android_system_vold`, branch `android-12.1`, commit
`a164ba05c5fef288059774a776b2e6e1119957cf`, checked out at `system/vold`. vold is licensed under
the Apache License 2.0, and so are these changes.

- `FsCrypt.cpp`: no recursive `restorecon` over `system_ce`, `vendor_ce` and `misc_ce` after the
  CE key is installed. The recovery's Android 12 `libselinux` does not know the per-user MLS level
  that Android 14 and later give to `misc_ce/<user>/checkin` and `sdksandbox`, and relabelled them
  to `s0`. On the next boot `vold_prepare_subdirs` could not relabel `checkin` (`relabelfrom`
  denied): LineageOS 23.2 left the user's credential-encrypted storage unprepared, and apps could
  no longer create their folders under `Android/data`. LineageOS 24 deletes and recreates the
  directory. Android labels these paths itself when the user is unlocked.
- `Decrypt.cpp`: the gatekeeper is looked up as the `mdfpp` instance first, then as `default`
  (made for gts7xlwifi, whose ROM verifies the lock screen credential in the QSEE MDFPP
  gatekeeper). tucana has no `mdfpp` instance and keeps the old behaviour (`tryGetService` does
  not wait).

## Applying

```bash
cd <OrangeFox source tree>/bootable/recovery
git checkout cbcc4f713dbef98d76d6d2cfd019b1ebfd9418e9
git apply <this repository>/recovery-patches/bootable_recovery.diff

cd <OrangeFox source tree>/system/vold
git checkout a164ba05c5fef288059774a776b2e6e1119957cf
git apply <this repository>/recovery-patches/system_vold.diff
```

`navbar.xml` uses CRLF line endings upstream; the diff keeps them, so apply it without
converting line endings.
