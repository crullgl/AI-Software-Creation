# Give Nomad's OWN app-managed Kiwix access to the NAS archives.
#
# The app creates nomad_kiwix_server bound to the local folder
# $PSScriptRoot\storage\zim, so it only ever sees what it downloaded itself.
# This re-creates that container with one extra mount - the NAS share,
# READ-ONLY at /data/nas - and registers every archive in the library XML
# that Kiwix already monitors.
#
# Re-run this after the app reinstalls or updates the Information Library,
# because that rewrites kiwix-library.xml and drops the NAS entries.

$log = (Join-Path $PSScriptRoot "attach_nas.log")
Set-Content -Path $log -Value "" -Encoding ascii
function L($m) { Add-Content -Path $log -Value $m -Encoding ascii; Write-Host $m }
$env:Path = "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin;" + $env:Path

$vol = (& docker volume ls --format "{{.Name}}" | Where-Object { $_ -match "nomad-zim" } | Select-Object -First 1)
if (-not $vol) { L "NAS volume not found - is the compose stack up?"; exit 1 }
L ("using NAS volume: " + $vol)

L "stopping the app's kiwix"
(& docker rm -f nomad_kiwix_server 2>&1) | ForEach-Object { L ("  " + $_) }

L "recreating it with the NAS mounted read-only at /data/nas"
$id = (& docker run -d `
  --name nomad_kiwix_server `
  --restart unless-stopped `
  --network project-nomad_default `
  --label "com.docker.compose.project=project-nomad-managed" `
  --label "io.project-nomad.managed=true" `
  -p 8090:8080 `
  -v "$PSScriptRoot\storage\zim:/data" `
  -v "${vol}:/data/nas:ro" `
  --entrypoint /usr/bin/dumb-init `
  ghcr.io/kiwix/kiwix-serve:3.8.1 `
  -- /usr/local/bin/start.sh --library /data/kiwix-library.xml --monitorLibrary --address=all 2>&1 | Out-String).Trim()
L ("  container: " + $id.Substring(0, [Math]::Min(12, $id.Length)))
Start-Sleep -Seconds 8

L ("NAS archives visible to it: " + ((& docker exec nomad_kiwix_server sh -c "ls /data/nas | wc -l" 2>&1) | Out-String).Trim())

# NOTE: -u 0 is required. The kiwix image runs as uid 1001, but the library
# XML is created by the Nomad app as root, so an unprivileged kiwix-manage
# fails with "Cannot write the library". kiwix-serve only READS it, so a
# root-owned library is fine.
L "registering all NAS archives in the library Kiwix monitors (several minutes over SMB)"
(& docker exec -u 0 nomad_kiwix_server sh -c "kiwix-manage /data/kiwix-library.xml add /data/nas/*.zim" 2>&1) |
  Select-Object -Last 5 | ForEach-Object { L ("  " + $_) }

$books = (& docker exec nomad_kiwix_server sh -c "grep -c '<book ' /data/kiwix-library.xml" 2>&1 | Out-String).Trim()
L ("books now in the library: " + $books)
L "ATTACH-DONE"

