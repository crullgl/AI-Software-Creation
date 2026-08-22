$dir = "D:\nomad-pc"
$envFile = Join-Path $dir ".env"

Write-Host ""
Write-Host "  ==========================================================="
Write-Host "   Project NOMAD - PC instance credentials"
Write-Host "  ==========================================================="
Write-Host ""
Write-Host "   The PC instance gets its OWN database passwords, freshly"
Write-Host "   generated. The only thing you type is the NAS login, so"
Write-Host "   Docker can mount the ZIM archives read-only."
Write-Host ""

$nas = Read-Host "   NAS IP or hostname (e.g. 10.0.0.50)"
$share = Read-Host "   Share path to NOMAD (e.g. docker/project-nomad)"
$user = Read-Host "   NAS username"
$sec = Read-Host "   NAS password" -AsSecureString
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
          [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

Write-Host ""
Write-Host "   Verifying against the NAS..."
net use "\\$nas\IPC$" /delete /y 2>&1 | Out-Null
$null = (net use "\\$nas\IPC$" $pass /user:$user 2>&1)
if ($LASTEXITCODE -ne 0) {
  Write-Host "   The NAS refused that login. Nothing written." -ForegroundColor Yellow
  Read-Host "   Press Enter to close"
  exit 1
}
Write-Host "   NAS login good."

function NewSecret($n) {
  $b = New-Object byte[] $n
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  return (-join ($b | ForEach-Object { $_.ToString("x2") }))
}

$lines = @(
  "# Project NOMAD PC instance. Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm').",
  "# Local database passwords are unique to this instance and are NOT the",
  "# ones the NAS instance uses. The NAS login is here only so Docker can",
  "# mount the archive share read-only.",
  "APP_KEY=$(NewSecret 24)",
  "DB_ROOT_PASSWORD=$(NewSecret 16)",
  "DB_PASSWORD=$(NewSecret 16)",
  "NAS_USER=$user",
  "NAS_PASSWORD=$pass",
  "NAS_HOST=$nas",
  "NAS_SHARE=$share"
)
Set-Content -Path $envFile -Value $lines -Encoding ascii

# Lock the file down to this user only - it holds the NAS password.
$acl = Get-Acl $envFile
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
          "$env:USERDOMAIN\$env:USERNAME", "FullControl", "Allow")
$acl.SetAccessRule($rule)
Set-Acl -Path $envFile -AclObject $acl

Write-Host ""
Write-Host "   Wrote $envFile and locked it to your account only."
Write-Host "   Claude will bring the stack up from here."
Write-Host ""
Start-Sleep -Seconds 4
