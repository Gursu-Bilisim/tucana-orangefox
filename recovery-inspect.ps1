# recovery-inspect.ps1
# Lists what a tucana recovery image contains for FBE v2 + metadata encryption
# (wrappedkey_v0) decryption on Android 16 ROMs, without flashing it.
# Works in Windows PowerShell 5.1+ and PowerShell 7 (Windows, Linux).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File recovery-inspect.ps1 -Img <recovery.img>
#   powershell -ExecutionPolicy Bypass -File recovery-inspect.ps1 -Img <zip containing recovery.img>
#
# Each check prints OK or MISSING. A recovery that decrypts /data on LineageOS 23
# needs every item in the "Decryption" group, and its header must match the ROM's
# boot.img (see patch-check.ps1).

param(
  [Parameter(Mandatory = $true)][string]$Img
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ImageBytes([string]$path) {
  $full = (Resolve-Path $path).Path
  if ([IO.Path]::GetExtension($full) -ieq '.zip') {
    $zf = [IO.Compression.ZipFile]::OpenRead($full)
    try {
      $e = $zf.GetEntry('recovery.img')
      if (-not $e) { throw 'recovery.img not found in the zip' }
      $ms = New-Object IO.MemoryStream
      $s = $e.Open(); $s.CopyTo($ms); $s.Close()
      return ,$ms.ToArray()
    } finally { $zf.Dispose() }
  }
  return ,[IO.File]::ReadAllBytes($full)
}

function Read-Header([byte[]]$d) {
  if ([Text.Encoding]::ASCII.GetString($d, 0, 8) -ne 'ANDROID!') { throw 'Not an Android boot/recovery image' }
  $hv = [BitConverter]::ToUInt32($d, 40)
  if ($hv -ge 3) {
    $page = 4096
    $kSize = [BitConverter]::ToUInt32($d, 8)
    $rSize = [BitConverter]::ToUInt32($d, 12)
    $osv = [BitConverter]::ToUInt32($d, 16)
    $cmd = [Text.Encoding]::ASCII.GetString($d, 44, 1536).TrimEnd([char]0)
  } else {
    $kSize = [BitConverter]::ToUInt32($d, 8)
    $rSize = [BitConverter]::ToUInt32($d, 16)
    $page = [BitConverter]::ToUInt32($d, 36)
    $osv = [BitConverter]::ToUInt32($d, 44)
    $cmd = [Text.Encoding]::ASCII.GetString($d, 64, 512).TrimEnd([char]0)
  }
  $lvl = $osv -band 0x7FF
  $kPages = [math]::Ceiling($kSize / $page)
  [pscustomobject]@{
    HeaderVersion = $hv
    OsVersion     = '{0}.{1}.{2}' -f (($osv -shr 25) -band 0x7F), (($osv -shr 18) -band 0x7F), (($osv -shr 11) -band 0x7F)
    PatchLevel    = '{0:D4}-{1:D2}' -f (($lvl -shr 4) + 2000), ($lvl -band 0xF)
    Cmdline       = $cmd
    RamdiskOffset = [int]($page + $kPages * $page)
    RamdiskSize   = [int]$rSize
  }
}

function Read-Ramdisk([byte[]]$d, $h) {
  $raw = New-Object byte[] $h.RamdiskSize
  [Array]::Copy($d, $h.RamdiskOffset, $raw, 0, $h.RamdiskSize)
  if ($raw[0] -eq 0x1F -and $raw[1] -eq 0x8B) {
    $in = New-Object IO.MemoryStream(, $raw)
    $gz = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
    $out = New-Object IO.MemoryStream
    $gz.CopyTo($out); $gz.Close()
    $raw = $out.ToArray()
  }
  $magic = [Text.Encoding]::ASCII.GetString($raw, 0, 6)
  if ($magic -ne '070701' -and $magic -ne '070702') {
    throw "Unsupported ramdisk compression (first bytes: $(($raw[0..3] | ForEach-Object { $_.ToString('x2') }) -join ' ')). Unpack it with magiskboot instead."
  }
  $files = @{}
  $p = 0
  while ($p -lt $raw.Length) {
    $hdr = [Text.Encoding]::ASCII.GetString($raw, $p, 110)
    $mode  = [Convert]::ToInt32($hdr.Substring(14, 8), 16)
    $fsize = [Convert]::ToInt32($hdr.Substring(54, 8), 16)
    $nsize = [Convert]::ToInt32($hdr.Substring(94, 8), 16)
    $p += 110
    $name = [Text.Encoding]::ASCII.GetString($raw, $p, $nsize - 1)
    $p = ($p + $nsize + 3) -band -bnot 3
    if ($name -eq 'TRAILER!!!') { break }
    if (($mode -band 0xF000) -eq 0x8000) {
      $files[$name.TrimStart('/')] = @($p, $fsize)
    }
    $p = ($p + $fsize + 3) -band -bnot 3
  }
  return @{ Data = $raw; Files = $files }
}

function Get-Text($rd, [string]$name) {
  $f = $rd.Files[$name]
  if (-not $f) { return $null }
  return [Text.Encoding]::ASCII.GetString($rd.Data, $f[0], $f[1])
}

function Find-File($rd, [string[]]$names) {
  foreach ($n in $names) { if ($rd.Files.ContainsKey($n)) { return $n } }
  return $null
}

$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$group, [string]$check, [bool]$ok, [string]$detail) {
  $results.Add([pscustomobject]@{ Group = $group; Check = $check; Result = $(if ($ok) { 'OK' } else { 'MISSING' }); Detail = $detail })
}

$bytes = Get-ImageBytes $Img
$h = Read-Header $bytes
$rd = Read-Ramdisk $bytes $h

Write-Host "Image          : $(Split-Path $Img -Leaf)"
Write-Host "Header         : v$($h.HeaderVersion), Android $($h.OsVersion), patch $($h.PatchLevel)"
$props = Get-Text $rd 'prop.default'
if ($props) {
  $vp = ([regex]::Match($props, '(?m)^ro\.vendor\.build\.security_patch=(.*)$')).Groups[1].Value
  Write-Host "Vendor patch   : $(if ($vp) { $vp } else { '(empty)' })"
}
Write-Host ''

# Boot parameters
Add-Result 'Boot' 'androidboot.bootdevice on cmdline' ($h.Cmdline -match 'androidboot\.bootdevice=') ''

# Decryption chain
$rcText = ($rd.Files.Keys | Where-Object { $_ -like '*.rc' } | ForEach-Object { Get-Text $rd $_ }) -join "`n"
Add-Result 'Decryption' '/dev/block/bootdevice link created by init' ($rcText -match '(?m)symlink\s+\S+\s+/dev/block/bootdevice\s*$') ''
Add-Result 'Decryption' 'qcom decrypt init (twrp-common)' ($rd.Files.ContainsKey('init.recovery.qcom_decrypt.rc')) 'init.recovery.qcom_decrypt.rc'
$n = Find-File $rd @('system/bin/prepdecrypt.sh', 'vendor/bin/prepdecrypt.sh')
Add-Result 'Decryption' 'prepdecrypt script' ([bool]$n) $n
$n = Find-File $rd @('system/bin/qseecomd', 'vendor/bin/qseecomd')
Add-Result 'Decryption' 'qseecomd' ([bool]$n) $n
$n = Find-File $rd @('vendor/lib64/libQSEEComAPI.so', 'system/lib64/libQSEEComAPI.so')
Add-Result 'Decryption' 'QSEECom library' ([bool]$n) $n
$missing = @('librpmb.so', 'libssd.so', 'libGPreqcancel.so', 'libdrmfs.so') | Where-Object { -not $rd.Files.ContainsKey("vendor/lib64/$_") }
Add-Result 'Decryption' 'qseecomd listener libraries' ($missing.Count -eq 0) $(if ($missing) { 'missing: ' + ($missing -join ', ') } else { 'rpmb, ssd, GPreqcancel, drmfs' })
$n = Find-File $rd @('system/bin/android.hardware.keymaster@4.1-service-qti', 'vendor/bin/hw/android.hardware.keymaster@4.1-service-qti')
Add-Result 'Decryption' 'QTI keymaster 4.1 service' ([bool]$n) $n
$n = Find-File $rd @('system/bin/android.hardware.gatekeeper@1.0-service-qti', 'vendor/bin/hw/android.hardware.gatekeeper@1.0-service-qti')
Add-Result 'Decryption' 'QTI gatekeeper 1.0 service' ([bool]$n) $n
$man = Get-Text $rd 'vendor/etc/vintf/manifest.xml'
$manVer = if ($man) { ([regex]::Match($man, 'manifest\s+version="([^"]+)"')).Groups[1].Value } else { '' }
Add-Result 'Decryption' 'VINTF manifest readable by recovery' ([bool]$man -and $manVer -and [double]$manVer -le 4) $(if ($man) { "manifest version $manVer" } else { 'vendor/etc/vintf/manifest.xml not found' })
Add-Result 'Decryption' 'manifest declares keymaster' ([bool]$man -and $man -match 'android\.hardware\.keymaster') ''
Add-Result 'Decryption' 'manifest declares keystore2 (AIDL)' ([bool]$man -and $man -match 'android\.system\.keystore2') ''
$recBin = $rd.Files['system/bin/recovery']
$rewrite = $false
if ($recBin) { $rewrite = [Text.Encoding]::ASCII.GetString($rd.Data, $recBin[0], $recBin[1]).Contains('Rewrote bootdevice paths') }
Add-Result 'Decryption' 'bootdevice paths rewritten in ROM fstab' $rewrite 'recovery binary'

# USB
$usb = Get-Text $rd 'init.recovery.usb.rc'
Add-Result 'USB' 'configfs USB gadget' ([bool]$usb -and $usb -match '/config/usb_gadget') $(if ($usb -and $usb -match '/sys/class/android_usb') { 'legacy android_usb rules present' } else { '' })
Add-Result 'USB' 'MTP function linked in mtp,adb mode' ([bool]$usb -and $usb -match 'functions/mtp\.gs0\s+\S+/configs/b\.1/f') ''

$results | Format-Table -AutoSize Group, Check, Result, Detail | Out-String -Width 200 | Write-Host
$miss = @($results | Where-Object { $_.Group -eq 'Decryption' -and $_.Result -ne 'OK' }).Count
if ($miss -eq 0) {
  Write-Host 'RESULT: all decryption components present. Check the header against the ROM with patch-check.ps1.' -ForegroundColor Green
} else {
  Write-Host "RESULT: $miss decryption component(s) missing; this image is not expected to decrypt /data on Android 16 ROMs." -ForegroundColor Yellow
}
