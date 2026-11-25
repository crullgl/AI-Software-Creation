<#
.SYNOPSIS
  One-time setup on the work PC: checks Python and installs the libraries the finder needs.
  Run from this folder:   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#>
param([string] $Python = "python")

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

try { $ver = & $Python --version 2>&1 } catch { $ver = $null }
if (-not $ver -or "$ver" -notmatch "Python 3\.(9|1\d)") {
    Write-Host "Python 3.9 or newer was not found (got: '$ver')." -ForegroundColor Red
    Write-Host "Install it from the Company Portal / Software Center, or python.org."
    Write-Host "Tick 'Add python.exe to PATH' during install, then run this again."
    exit 1
}
Write-Host "Found $ver"

& $Python -m pip install --user -r (Join-Path $here "requirements.txt")
if ($LASTEXITCODE -ne 0) {
    Write-Host "pip install failed. If you are behind a company proxy, ask IT for the pip proxy setting." -ForegroundColor Red
    exit 1
}

& $Python -c "import PIL, numpy, pymupdf; print('Libraries OK')"
if ($LASTEXITCODE -ne 0) { exit 1 }
Write-Host "`nSetup complete. Next: test on a sample folder - see README.md, step 3." -ForegroundColor Green
