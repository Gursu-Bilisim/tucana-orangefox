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
| Image SHA-256 | c33c7c30c14928a89443319198ce4f5f7bb1a85592f0c3a473ab87f94a4ed59b |

Tests with this image:

| Test | Result | Notes |
|---|---|---|
| Decrypt /data, first attempt after boot | failed without a tap, OK with a tap first | both phones; see the known issue below |
| Decrypt /data, pattern starting at a corner dot | same as other patterns | the first pattern after boot fails wherever it starts; after a tap the pattern is accepted |
| ADB | OK | |
| MTP | OK | both directions with Windows Explorer. Total Commander closes when copying from the phone; it does the same with the phone running Android, so this is a client issue |
| Battery indicator | OK | |
| Status bar, accent colour, bottom menu, lock-screen swipe | OK | the swipe, the navigation buttons and the install console sit 60 px higher than in r2, clear of the curved bottom edge |
| USB-OTG storage | OK | FAT32, exFAT and NTFS sticks mounted with MTP turned off; with MTP on, the first mount attempt failed. Shown as USB Storage in the Files storage menu |
| Format Data | OK | Mi Note 10; no `/mnt` warning any more |
| Zip install from OrangeFox | not tested yet | |
| Backup and restore | OK for Boot | Boot backed up to an NTFS stick and restored; the partition and the backup file have the same SHA-256. The first boot after the restore stopped in fastboot, the next boot was normal. Data backup not tested (no user data on the test phones) |
| `recovery-inspect.ps1` | OK | all groups OK (PowerShell 7) |
| `patch-check.ps1` against the ROM boot.img | OK | RESULT: match (PowerShell 7) |

Known issues:

- The first touch after boot is cut short by the touch controller (FTS panel); see README. This
  build still shows it on both phones, with the kernel of the 20261019 LineageOS build.
- The recovery clock starts in 1973 (21 Aug 1973 on the test phones), so backup folders and
  file dates carry that date. Backups themselves are not affected.

Not tested: Data backup and restore with user data, adopted storage, OTA (incremental) packages.
