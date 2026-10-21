## Pre-release test notes

Tested by the maintainer before publishing. Update this file for every release; `release.sh`
stops until the SHA-256 of the image to be published is recorded here.

| Item | Value |
|---|---|
| Device | <Mi Note 10 / Mi Note 10 Pro>, tucana |
| ROM | <lineage-23.2-YYYYMMDD-NIGHTLY-tucana> (Android <16>) |
| Security patch (system / vendor) | <YYYY-MM-DD> / <YYYY-MM-DD> |
| Kernel (from the ROM boot.img) | <version> |
| Lock screen | <pattern / PIN / password> |
| Image SHA-256 | <sha256 of the OrangeFox .img> |

Tests with this image:

| Test | Result | Notes |
|---|---|---|
| Decrypt /data, first attempt after boot | <OK / failed> | <with or without a tap on the screen first> |
| Decrypt /data, pattern starting at a corner dot | <OK / failed> | |
| ADB | <OK> | |
| MTP | <OK> | <also after decrypt> |
| Battery indicator | <OK> | |
| Status bar, accent colour, bottom menu, lock-screen swipe | <OK> | |
| Zip install from OrangeFox | <OK / not tested> | |
| Backup and restore | <OK / not tested> | |
| `recovery-inspect.ps1` | <OK> | <all groups OK> |
| `patch-check.ps1` against the ROM boot.img | <OK> | <RESULT: match> |

Known issue: the first touch after boot may be cut short by the touch controller (FTS panel);
see README. <Record here whether this build still shows it.>

Not tested: <list>
