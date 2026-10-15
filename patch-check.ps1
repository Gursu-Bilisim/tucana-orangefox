# patch-check.ps1
# Reads the security patch level of an OTA package and, optionally, compares it
# with a recovery image. Works in Windows PowerShell 5.1+.
#
# Supported inputs:
#   - A-only OTA zip with boot.img at its root (tucana, most retrofit devices)
#   - A/B OTA zip with payload.bin (needs payload-dumper-go)
#   - A bare payload.bin
#   - A boot.img you extracted yourself (e.g. with Multi Image Kitchen) via -BootImg
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File patch-check.ps1 -Zip <ota.zip> [-RecoveryImg <recovery.img>]
#   powershell -ExecutionPolicy Bypass -File patch-check.ps1 -BootImg <boot.img> [-RecoveryImg <recovery.img>]
# Optional: -PayloadTool <exe>  -GoDumper <payload-dumper-go.exe, default E:\Mobil\Payload-Dumper-Go>
#           -MikDir <Multi Image Kitchen folder, default E:\Mobil\MIK>
#           -WorkDir <folder for temporary files>. Only used for A/B (payload.bin) zips;
#           if omitted there, the script shows the space needed and asks.
# Supported payload tools: payload-dumper-go (fast, extracts only boot)
#                          payload_dumper by vm03 (bundled with MIK, extracts all, stopped after boot)

param(
  [string]$Zip,
  [string]$BootImg,
  [string]$RecoveryImg,
  [string]$PayloadTool,
  [string]$GoDumper = 'E:\Mobil\Payload-Dumper-Go\payload-dumper-go.exe',
  [string]$MikDir = 'E:\Mobil\MIK',
  [string]$WorkDir = $env:TEMP
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

$workDirGiven = $PSBoundParameters.ContainsKey('WorkDir')

if (-not $Zip -and -not $BootImg) { throw 'Give -Zip <ota.zip | payload.bin> or -BootImg <boot.img>' }

function Read-Head([IO.Stream]$s, [int]$n) {
  $buf = New-Object byte[] $n
  $read = 0
  while ($read -lt $n) {
    $k = $s.Read($buf, $read, $n - $read)
    if ($k -le 0) { break }
    $read += $k
  }
  return ,$buf
}

function Read-OsVersion([byte[]]$h) {
  $magic = [Text.Encoding]::ASCII.GetString($h, 0, 8)
  if ($magic -ne 'ANDROID!') { throw "Not an Android boot image (magic: $magic)" }
  $hv  = [BitConverter]::ToUInt32($h, 40)
  $off = if ($hv -ge 3) { 16 } else { 44 }
  $v   = [BitConverter]::ToUInt32($h, $off)
  $lvl = $v -band 0x7FF
  $y   = ($lvl -shr 4) + 2000
  $m   = $lvl -band 0xF
  $a   = ($v -shr 25) -band 0x7F
  $b   = ($v -shr 18) -band 0x7F
  $c   = ($v -shr 11) -band 0x7F
  [pscustomobject]@{
    HeaderVersion = $hv
    OsVersion     = "$a.$b.$c"
    PatchLevel    = ('{0:D4}-{1:D2}' -f $y, $m)
  }
}

function Read-ImgFile([string]$path) {
  $fs = [IO.File]::OpenRead($path)
  try { return Read-OsVersion (Read-Head $fs 64) } finally { $fs.Close() }
}

function Find-PayloadTool {
  if ($PayloadTool) {
    if (Test-Path $PayloadTool) { return (Resolve-Path $PayloadTool).Path }
    throw "PayloadTool not found: $PayloadTool"
  }
  if ($GoDumper -and (Test-Path $GoDumper)) { return (Resolve-Path $GoDumper).Path }
  foreach ($name in 'payload-dumper-go.exe', 'payload_dumper.exe') {
    $local = Join-Path $PSScriptRoot $name
    if (Test-Path $local) { return $local }
  }
  $cmd = Get-Command 'payload-dumper-go' -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  if ($MikDir -and (Test-Path $MikDir)) {
    $all = Get-ChildItem $MikDir -Recurse -Include 'payload-dumper*.exe', 'payload_dumper*.exe' -ErrorAction SilentlyContinue
    $go = $all | Where-Object { $_.Name -like 'payload-dumper-go*' } | Select-Object -First 1
    if ($go) { return $go.FullName }
    $any = $all | Select-Object -First 1
    if ($any) { return $any.FullName }
  }
  return $null
}

function Select-WorkDir([long]$needBytes) {
  $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
  $tempDrive = (Split-Path -Qualifier $env:TEMP).TrimEnd(':')
  $tempFree = ($drives | Where-Object { $_.Name -eq $tempDrive } | Select-Object -First 1).Free
  Write-Host ('This is an A/B package: payload.bin needs about {0:N1} GB of temporary space.' -f ($needBytes / 1GB))
  foreach ($d in $drives) { Write-Host ('  {0}: {1:N1} GB free' -f $d.Name, ($d.Free / 1GB)) }
  $default = $env:TEMP
  if (-not $tempFree -or $tempFree -lt $needBytes) {
    $best = $drives | Sort-Object Free -Descending | Select-Object -First 1
    $default = Join-Path $best.Root 'tmp'
    Write-Host "Not enough space on ${tempDrive}:, suggesting $default"
  }
  $ans = Read-Host "Temporary folder (Enter = $default)"
  if ([string]::IsNullOrWhiteSpace($ans)) { $ans = $default }
  return $ans.Trim('"')
}

function Get-PayloadFile([string]$zipPath, [string]$tmp) {
  Write-Host 'Extracting payload.bin from the zip (this can take a while)...'
  $pl = Join-Path $tmp 'payload.bin'
  $zf = [IO.Compression.ZipFile]::OpenRead($zipPath)
  try { [IO.Compression.ZipFileExtensions]::ExtractToFile($zf.GetEntry('payload.bin'), $pl) }
  finally { $zf.Dispose() }
  return $pl
}

function Invoke-GoDumper([string]$tool, [string]$inputPath, [string]$zipPath, [string]$out, [string]$tmp) {
  & $tool -p boot -o $out $inputPath | Out-Host
  $img = Get-ChildItem $out -Recurse -Filter 'boot.img' -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $img -and $zipPath) {
    $pl = Get-PayloadFile $zipPath $tmp
    & $tool -p boot -o $out $pl | Out-Host
    $img = Get-ChildItem $out -Recurse -Filter 'boot.img' -ErrorAction SilentlyContinue | Select-Object -First 1
  }
  return $img
}

function Invoke-Vm03Dumper([string]$tool, [string]$payloadPath, [string]$out) {
  Write-Host 'This tool extracts every partition in order; it will be stopped as soon as boot.img is complete.'
  $argList = @('--out', ('"' + $out + '"'), ('"' + $payloadPath + '"'))
  $p = Start-Process -FilePath $tool -ArgumentList $argList -WorkingDirectory (Split-Path $out) -NoNewWindow -PassThru
  $boot = Join-Path $out 'boot.img'
  while (-not $p.HasExited) {
    if (Test-Path $boot) {
      $bootTime = (Get-Item $boot).LastWriteTime
      $next = Get-ChildItem $out -Filter '*.img' -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -ne 'boot.img' -and $_.CreationTime -ge $bootTime }
      if ($next) {
        Write-Host 'boot.img complete, stopping the payload tool.'
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        break
      }
    }
    Start-Sleep -Milliseconds 500
  }
  $p.WaitForExit()
  if (Test-Path $boot) { return Get-Item $boot }
  return $null
}

function Get-BootFromPayload([string]$inputPath, [string]$zipPath) {
  $tool = Find-PayloadTool
  if (-not $tool) {
    throw "payload.bin found but no payload tool was found. Use -PayloadTool or -MikDir, or extract boot.img with Multi Image Kitchen and pass it with -BootImg."
  }
  Write-Host "Using payload tool: $tool"
  $tmp = Join-Path $WorkDir ('patchcheck_' + [guid]::NewGuid().ToString('N'))
  $out = Join-Path $tmp 'out'
  New-Item -ItemType Directory -Path $out -Force | Out-Null
  $oldTmp = $env:TMP; $oldTemp = $env:TEMP
  $env:TMP = $tmp; $env:TEMP = $tmp
  try {
    if ((Split-Path $tool -Leaf) -like 'payload-dumper-go*') {
      $img = Invoke-GoDumper $tool $inputPath $zipPath $out $tmp
    }
    else {
      $pl = if ($zipPath) { Get-PayloadFile $zipPath $tmp } else { $inputPath }
      $img = Invoke-Vm03Dumper $tool $pl $out
    }
    if (-not $img) { throw 'payload tool ran but no boot.img was produced. Extract it with Multi Image Kitchen and use -BootImg.' }
    return Read-ImgFile $img.FullName
  }
  finally {
    $env:TMP = $oldTmp; $env:TEMP = $oldTemp
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$metaPatch = $null
$metaDevice = $null
$boot = $null

if ($BootImg) {
  $boot = Read-ImgFile (Resolve-Path $BootImg).Path
}
else {
  $zipFull = (Resolve-Path $Zip).Path
  if ([IO.Path]::GetFileName($zipFull) -ieq 'payload.bin') {
    $boot = Get-BootFromPayload $zipFull $null
  }
  else {
    $zf = [IO.Compression.ZipFile]::OpenRead($zipFull)
    $hasPayload = $false
    try {
      $meta = $zf.GetEntry('META-INF/com/android/metadata')
      if ($meta) {
        $sr = New-Object IO.StreamReader($meta.Open())
        $text = $sr.ReadToEnd()
        $sr.Close()
        $line = ($text -split "`r?`n") | Where-Object { $_ -like 'post-security-patch-level=*' } | Select-Object -First 1
        if ($line) { $metaPatch = $line.Split('=')[1].Trim() }
        $dline = ($text -split "`r?`n") | Where-Object { $_ -like 'pre-device=*' } | Select-Object -First 1
        if ($dline) { $metaDevice = $dline.Split('=')[1].Split(',')[0].Trim() }
      }
      $bootEntry = $zf.GetEntry('boot.img')
      if ($bootEntry) {
        $s = $bootEntry.Open()
        try { $boot = Read-OsVersion (Read-Head $s 64) } finally { $s.Close() }
      }
      elseif ($zf.GetEntry('payload.bin')) {
        $hasPayload = $true
        $payloadSize = $zf.GetEntry('payload.bin').Length
      }
      else { throw 'Neither boot.img nor payload.bin found in the zip' }
    }
    finally { $zf.Dispose() }
    if ($hasPayload) {
      if (-not $workDirGiven) { $WorkDir = Select-WorkDir ([long]($payloadSize * 1.05) + 200MB) }
      $boot = Get-BootFromPayload $zipFull $zipFull
    }
  }
}

if ($metaDevice) { Write-Host "OTA device     : $metaDevice" }
if ($metaPatch) { Write-Host "OTA metadata   : security patch $metaPatch" }
Write-Host "Boot header    : Android $($boot.OsVersion), patch $($boot.PatchLevel) (header v$($boot.HeaderVersion))"

if ($RecoveryImg) {
  $rec = Read-ImgFile (Resolve-Path $RecoveryImg).Path
  Write-Host "Recovery header: Android $($rec.OsVersion), patch $($rec.PatchLevel)"
  $recName = Split-Path $RecoveryImg -Leaf
  $deviceMismatch = $metaDevice -and ($recName -notmatch [regex]::Escape($metaDevice))
  $patchMatch = ($rec.OsVersion -eq $boot.OsVersion -and $rec.PatchLevel -eq $boot.PatchLevel)
  $target = if ($metaPatch) { $metaPatch } else { "$($boot.PatchLevel)-01 (check the exact day)" }
  if ($deviceMismatch) {
    Write-Host "WARNING: the recovery file name does not mention '$metaDevice'." -ForegroundColor Red
    if ($patchMatch) {
      Write-Host "RESULT: patch levels match, but the files appear to belong to different devices. Do not flash this recovery for $metaDevice." -ForegroundColor Red
    }
    else {
      Write-Host "RESULT: patch levels differ and the files appear to belong to different devices. A $metaDevice recovery needs PLATFORM_SECURITY_PATCH := $target" -ForegroundColor Red
    }
  }
  elseif ($patchMatch) {
    Write-Host 'RESULT: match, no rebuild needed' -ForegroundColor Green
  }
  else {
    Write-Host "RESULT: mismatch, rebuild with PLATFORM_SECURITY_PATCH := $target" -ForegroundColor Yellow
  }
}
