# tucana-orangefox
OrangeFox R12 with retrofit for tucana 

## Tools

### patch-check.ps1

Checks whether a recovery image can decrypt `/data` on a given ROM build, before you flash anything.
Keymaster binds the metadata encryption key to the OS version and security patch level, so the
recovery must report exactly the same values as the ROM's `boot.img`. A recovery with a **lower**
patch level fails with keymaster error -38. A recovery with a **higher** one may upgrade the key,
after which the ROM can no longer unlock `/data`.

The script reads the OTA metadata and the boot image header, compares them with a recovery image
and warns when the two files appear to belong to different devices.

Requirements: Windows PowerShell 5.1 or newer. For A/B packages (`payload.bin`) it also needs
[payload-dumper-go](https://github.com/ssut/payload-dumper-go) or the `payload_dumper` bundled with
Multi Image Kitchen.

```
powershell -ExecutionPolicy Bypass -File patch-check.ps1 -Zip <ota.zip> -RecoveryImg <recovery.img>
powershell -ExecutionPolicy Bypass -File patch-check.ps1 -BootImg <boot.img> -RecoveryImg <recovery.img>
```

Optional parameters: `-GoDumper`, `-MikDir` and `-PayloadTool` point to the payload tools,
`-WorkDir` sets the folder for temporary files (A/B packages only; asked interactively if omitted).

Example output:

```
OTA device     : tucana
OTA metadata   : security patch 2026-09-01
Boot header    : Android 16.0.0, patch 2026-09 (header v2)
Recovery header: Android 16.0.0, patch 2026-09
RESULT: match, no rebuild needed
```

### recovery-inspect.ps1

Lists what a tucana recovery image contains for FBE v2 + metadata encryption (wrappedkey_v0)
on Android 16 ROMs: the qseecomd and QTI keymaster/gatekeeper chain, its libraries, the VINTF
manifest, the `/dev/block/bootdevice` link and the configfs USB setup. Accepts a `recovery.img`
or an OrangeFox zip. Useful before flashing a build you did not make yourself.

```
powershell -ExecutionPolicy Bypass -File recovery-inspect.ps1 -Img <recovery.img | OrangeFox zip>
```

### release.sh

Publishes the latest build as a GitHub release with SHA-256 checksums. Run it from the device tree
after committing and pushing. `./release.sh r2` adds a suffix for a second release on the same day.
It looks for the build three folders above the device tree; if your layout differs, run it as
`FOX_TREE=<OrangeFox source tree> ./release.sh`.

## Credits and license

This tree started as a fork of [LIECOTI/tucana-orangefox](https://github.com/LIECOTI/tucana-orangefox)
and uses work from TeamWin, LineageOS and OrangeFox. [NOTICE](NOTICE) lists every source and its license.

- Files written for this repository: Apache License 2.0 ([LICENSE](LICENSE)).
- Changes to the OrangeFox/TWRP recovery source: GPL-3.0-or-later, published in
  [recovery-patches/](recovery-patches/).
- Prebuilt Qualcomm and Xiaomi vendor files: not covered by either license.

If you reuse parts of this tree, keep the NOTICE file and credit the sources it lists.
