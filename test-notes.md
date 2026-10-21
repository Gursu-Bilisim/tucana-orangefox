## Pre-release test notes

Tested by the maintainer before publishing. Update this file for every release; `release.sh`
stops until the SHA-256 of the image to be published is recorded here.

| Item | Value |
|---|---|
| Device | Mi Note 10 and Mi Note 10 Pro, tucana |
| ROM | lineage-23.2-20261019-NIGHTLY-tucana (Android 16) |
| Security patch (system / vendor) | 2026-10-01 / 2022-04-01 |
| Kernel (from the ROM boot.img) | 4.14.357-openela-perf-ge03e5ba22586, built 19 Oct 2026 |
| Lock screen | pattern |
| Image SHA-256 | 29e4fd6165eb4c33c5234ec41815ce5ee2073bc2afa70726b1123f9139f39f91 |

Tests with this image:

| Test | Result | Notes |
|---|---|---|
| Decrypt /data | OK | after a tap on the screen, as below |
| Decrypt /data, no lock screen | OK | decrypted at boot without a prompt |
| Clock | OK | before: 22 Aug 1973 (RTC `since_epoch` 114827618). After the pattern the recovery reads the offset from `/data/vendor/time/ats_2` and sets the correct date and time (log: `Fixup_Time: Date and time corrected`). The local time follows the time zone set in OrangeFox |
| `recovery-inspect.ps1` | OK | all groups OK (PowerShell 7) |
| `patch-check.ps1` against the ROM boot.img | OK | RESULT: match (PowerShell 7) |

This image differs from the previous build of this tree (v2026.10.21, SHA-256
c33c7c30c14928a89443319198ce4f5f7bb1a85592f0c3a473ab87f94a4ed59b) only by
`TARGET_RECOVERY_QCOM_RTC_FIX := true` in `BoardConfig.mk`. The tests below were made with that
build:

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

- The first touch after boot is cut short by the touch controller (FTS panel); see README. This
  build still shows it on both phones, with the kernel of the 20261019 LineageOS build.
- On the lock screen, before the pattern, the clock still shows 1973: the time offset is stored
  on `/data` and can only be read after decryption. Everything after the pattern (backup folder
  names, file dates, logs) uses the correct date.

Not tested: Data backup and restore with user data, PIN and password lock screens, ADB sideload, fastbootd, Magisk.
