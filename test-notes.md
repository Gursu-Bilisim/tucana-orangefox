## Pre-release test notes

Tested by the maintainer before publishing. Update this file for every release; `release.sh`
stops until the SHA-256 of the image to be published is recorded here.

| Item | Value |
|---|---|
| Device | Mi Note 10 and Mi Note 10 Pro, tucana |
| ROM | lineage-23.2-20261019-NIGHTLY-tucana (Android 16) |
| Security patch (system / vendor) | 2026-10-01 / 2022-04-01 |
| Kernel (from the ROM boot.img) | 4.14.357-openela-perf-ge03e5ba22586, built 19 Oct 2026 |
| Lock screen | pattern; PIN, password and none in the tests marked so |
| Image SHA-256 | 8a2549d31a2834e4151a1f0b7accbde479e5d43c9ea48ec5670658ea7be00fca |

Tests with this image:

| Test | Result | Notes |
|---|---|---|
| Decrypt /data, PIN | OK | after a tap on the screen |
| Show-password icon on the decrypt page | OK | reacts to touches about half a fingertip above and below the icon (new 144x144 px touch area); before, only touches on the 64x46 px image itself |
| `recovery-inspect.ps1` | OK | all groups OK (PowerShell 7) |
| `patch-check.ps1` against the ROM boot.img | OK | RESULT: match (PowerShell 7) |

Earlier builds of this tree and how they differ from this image:

- v2026.10.21-r2 (SHA-256 29e4fd6165eb4c33c5234ec41815ce5ee2073bc2afa70726b1123f9139f39f91): only the
  show-password touch area is missing.
- v2026.10.21 (SHA-256 c33c7c30c14928a89443319198ce4f5f7bb1a85592f0c3a473ab87f94a4ed59b): in addition,
  `TARGET_RECOVERY_QCOM_RTC_FIX` is missing.

Tests with v2026.10.21-r2 and with a test build whose ramdisk is identical to it:

| Test | Result | Notes |
|---|---|---|
| Decrypt /data, no lock screen | OK | decrypted at boot without a prompt |
| Decrypt /data, PIN and password | OK | lock screen changed in the ROM to a PIN, then to a password; both decrypted in OrangeFox |
| Clock | OK | before: 22 Aug 1973 (RTC `since_epoch` 114827618). After the pattern the recovery reads the offset from `/data/vendor/time/ats_2` and sets the correct date and time (log: `Fixup_Time: Date and time corrected`). The local time follows the time zone set in OrangeFox |
| ADB sideload | OK | `adb sideload` of the OrangeFox zip; the adb client printed `failed to read command` at 47 %, which is how it reports the phone closing the connection after reading what it needs. OrangeFox rebooted into the recovery and showed its welcome screen; the recovery partition then had the same SHA-256 as that build |
| fastbootd | failed | see the known issues below |

Tests with v2026.10.21:

| Test | Result | Notes |
|---|---|---|
| Decrypt /data, first attempt after boot | failed without a tap, OK with a tap first | both phones; see the known issue below |
| Decrypt /data, pattern starting at a corner dot | same as other patterns | the first pattern after boot fails wherever it starts; after a tap the pattern is accepted |
| ADB | OK | |
| MTP | OK | both directions with Windows Explorer. Total Commander closes when copying from the phone; it does the same with the phone running Android, so this is a client issue |
| Battery indicator | OK | |
| Status bar, accent colour, bottom menu, lock-screen swipe | OK | the swipe, the navigation buttons and the install console sit 60 px higher than in the 3 October 2026 release, clear of the curved bottom edge |
| USB-OTG storage | OK | FAT32, exFAT and NTFS sticks mounted with MTP turned off; with MTP on, the first mount attempt failed. Shown as USB Storage in the Files storage menu |
| Format Data | OK | Mi Note 10; no `/mnt` warning any more |
| Zip install from OrangeFox | OK | LineageOS 20261019 zip installed with an earlier build of this tree (recovery kept). With that build: its OrangeFox zip installed, OrangeFox rebooted into the new recovery and showed its first-start welcome screen after the pattern; the recovery partition then had the same SHA-256 as that build |
| Backup and restore | OK for Boot | Boot backed up to an NTFS stick and restored; the partition and the backup file have the same SHA-256. The first boot after the restore stopped in fastboot, the next boot was normal. Data backup not tested (no user data on the test phones) |
| `recovery-inspect.ps1` | OK | all groups OK (PowerShell 7) |
| `patch-check.ps1` against the ROM boot.img | OK | RESULT: match (PowerShell 7) |

Known issues:

- fastbootd does not come up on USB. OrangeFox switches to fastboot mode and starts `fastbootd`,
  but `fastbootd` never opens its USB function, so the computer does not see the phone
  (`fastboot devices` is empty, nothing appears in the Windows Device Manager). The bootloader's
  fastboot is not affected.
- The first touch after boot is cut short by the touch controller (FTS panel); see README. This
  build still shows it on both phones, with the kernel of the 20261019 LineageOS build.
- On the lock screen, before the pattern, the clock still shows 1973: the time offset is stored
  on `/data` and can only be read after decryption. Everything after the pattern (backup folder
  names, file dates, logs) uses the correct date.

Not tested: Data backup and restore with user data, Magisk.
