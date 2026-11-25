<#
.SYNOPSIS
  Runs the fax duplicate finder and prints a plain-text summary.
  Power Automate Desktop calls this script and emails what it prints.
  You can also run it on its own or from Windows Task Scheduler.

.EXAMPLE
  # Report only (safe - changes nothing)
  .\run_fax_dedupe.ps1 -FaxFolder "\\server\share\Faxes" -ReportFolder "C:\FaxDedupe\Reports"

.EXAMPLE
  # Move extra copies into a review folder (still nothing is deleted)
  .\run_fax_dedupe.ps1 -FaxFolder "\\server\share\Faxes" -ReportFolder "C:\FaxDedupe\Reports" `
                       -Mode Move -ReviewFolder "\\server\share\Fax_Duplicates_Review"
#>
param(
    [Parameter(Mandatory = $true)] [string] $FaxFolder,
    [Parameter(Mandatory = $true)] [string] $ReportFolder,
    [ValidateSet("Report", "Move")] [string] $Mode = "Report",
    [string] $ReviewFolder = "",
    [double] $Threshold = 0.10,
    [string] $Python = "python"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$finder    = Join-Path $scriptDir "find_fax_duplicates.py"

if (-not (Test-Path $FaxFolder))  { throw "Fax folder not found: $FaxFolder" }
if (-not (Test-Path $finder))     { throw "find_fax_duplicates.py not found next to this script: $finder" }
New-Item -ItemType Directory -Force -Path $ReportFolder | Out-Null

$stamp  = Get-Date -Format "yyyy-MM-dd_HHmm"
$report = Join-Path $ReportFolder "fax_duplicates_$stamp.csv"
$log    = Join-Path $ReportFolder "fax_duplicates_$stamp.log"

$pyArgs = @($finder, $FaxFolder, "--report", $report, "--threshold", $Threshold)
if ($Mode -eq "Move") {
    if (-not $ReviewFolder) { throw "-ReviewFolder is required when -Mode Move" }
    $fullFax    = (Resolve-Path $FaxFolder).Path.TrimEnd('\') + '\'
    $fullReview = [System.IO.Path]::GetFullPath($ReviewFolder).TrimEnd('\') + '\'
    if ($fullReview.StartsWith($fullFax, [StringComparison]::OrdinalIgnoreCase)) {
        throw "ReviewFolder must be OUTSIDE the fax folder, or the next run will scan it."
    }
    $pyArgs += @("--move-duplicates", $ReviewFolder)
}

# Run the finder and keep its console output in a log file
# (Windows PowerShell 5.1 treats Python's stderr notes as errors under "Stop", so relax it here)
$ErrorActionPreference = "Continue"
& $Python @pyArgs 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log | Out-Null
$exit = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($exit -ne 0) { throw "Duplicate finder failed (exit $exit). See $log" }

# ---- Build the summary ----
$rows   = @(Import-Csv $report)
$dupes  = @($rows | Where-Object { $_.suggested_action -eq "duplicate" })
$groups = @($rows | Select-Object -ExpandProperty group -Unique)
$exact  = @($dupes | Where-Object { $_.match_type -eq "exact" }).Count
$visual = @($dupes | Where-Object { $_.match_type -eq "visual" }).Count
$errCsv = [System.IO.Path]::ChangeExtension($report, ".errors.csv")
$errors = if (Test-Path $errCsv) { @(Import-Csv $errCsv).Count } else { 0 }
$mb     = [math]::Round((($dupes | Measure-Object -Property size_bytes -Sum).Sum) / 1MB, 1)

$lines = @(
    "Fax duplicate scan - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    "Folder scanned : $FaxFolder"
    "Mode           : $Mode"
    ""
    "Duplicate groups      : $($groups.Count)"
    "Extra copies found    : $($dupes.Count)  (exact: $exact, visual: $visual)"
    "Space used by copies  : $mb MB"
    "Unreadable files      : $errors"
    ""
    "Report: $report"
)
if ($Mode -eq "Move" -and $dupes.Count -gt 0) {
    $lines += "Extra copies were MOVED to: $ReviewFolder (nothing deleted)"
} elseif ($dupes.Count -gt 0) {
    $lines += "Nothing was moved. Review the report, then run in Move mode."
}
if ($errors -gt 0) { $lines += "Unreadable files list: $errCsv" }

$summary = $lines -join "`r`n"
Set-Content -Path (Join-Path $ReportFolder "fax_duplicates_$stamp.summary.txt") -Value $summary
# Fixed-name copy of the newest report, so Power Automate can always attach the same path
Copy-Item $report (Join-Path $ReportFolder "fax_duplicates_LATEST.csv") -Force
Write-Output $summary
