# Copy map pins from the NAS Nomad instance to the desktop one.
# The NAS is only ever READ (a single HTTP GET). Nothing is written to it.

$log = Join-Path $PSScriptRoot "copy_markers.log"
Set-Content -Path $log -Value "" -Encoding ascii
function L($m) { Add-Content -Path $log -Value $m -Encoding ascii; Write-Host $m }

# Reads NAS_HOST from .env so this works on any machine.
$nasHost = ((Get-Content ".env" -ErrorAction SilentlyContinue |
             Where-Object { $_ -match "^NAS_HOST=" }) -replace "^NAS_HOST=", "").Trim()
if (-not $nasHost) { $nasHost = Read-Host "   NAS IP or hostname" }
$src = "http://${nasHost}:8080/api/maps/markers"
$dst = "http://localhost:8080/api/maps/markers"

L "reading pins from the NAS (read-only)"
try { $markers = Invoke-RestMethod -Uri $src -TimeoutSec 30 }
catch { L ("  could not read the NAS: " + $_.Exception.Message); exit 1 }
L ("  found " + $markers.Count + " pins")

L "checking what the desktop already has"
$existing = @()
try { $existing = Invoke-RestMethod -Uri $dst -TimeoutSec 20 } catch { }
$have = @{}
foreach ($e in $existing) { $have[("" + $e.name + "|" + $e.latitude)] = $true }
L ("  desktop currently has " + $existing.Count)

$added = 0; $skipped = 0; $failed = 0
foreach ($m in $markers) {
  $key = ("" + $m.name + "|" + $m.latitude)
  if ($have.ContainsKey($key)) { L ("  = already there: " + $m.name); $skipped++; continue }

  $body = @{
    name        = $m.name
    latitude    = $m.latitude
    longitude   = $m.longitude
    color       = $m.color
    marker_type = $m.marker_type
  }
  if ($m.notes)       { $body.notes = $m.notes }
  if ($m.route_id)    { $body.route_id = $m.route_id }
  if ($m.route_order) { $body.route_order = $m.route_order }

  try {
    Invoke-RestMethod -Uri $dst -Method Post -Body ($body | ConvertTo-Json) `
      -ContentType "application/json" -TimeoutSec 25 | Out-Null
    L ("  + " + $m.name)
    $added++
  } catch {
    L ("  ! " + $m.name + " -> " + ($_.Exception.Message -replace "\s+"," "))
    $failed++
  }
}

L ""
L ("added " + $added + ", already present " + $skipped + ", failed " + $failed)
$after = @()
try { $after = Invoke-RestMethod -Uri $dst -TimeoutSec 20 } catch { }
L ("desktop now has " + $after.Count + " pins")
L "MARKERS-DONE"
