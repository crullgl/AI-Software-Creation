$log = (Join-Path $PSScriptRoot "benchmark.log")
Set-Content -Path $log -Value "" -Encoding ascii
function L($m) { Add-Content -Path $log -Value $m -Encoding ascii; Write-Host $m }
$env:Path = "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin;" + $env:Path

# Top fits for 6 GB VRAM, straight out of Project Nomad's own catalogue.
$models = @(
  "gemma4:e2b-it-qat",
  "qwen3:4b-q8_0",
  "llama3.1:8b-text-q4_K_M"
)

$prompt = "Explain in about 150 words how a lithium iron phosphate battery differs from a standard lithium ion battery, and why that matters for off-grid solar storage."

foreach ($m in $models) {
  L ""
  L ("=== " + $m + " ===")
  L "  pulling..."
  (& docker exec nomadpc_ollama ollama pull $m 2>&1) | Select-Object -Last 2 | ForEach-Object { L ("    " + $_) }

  $body = @{ model = $m; prompt = $prompt; stream = $false } | ConvertTo-Json
  try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post `
          -Body $body -ContentType "application/json" -TimeoutSec 600
    $sw.Stop()
    $tokPerSec = if ($r.eval_duration -gt 0) { $r.eval_count / ($r.eval_duration / 1e9) } else { 0 }
    $firstTok  = $r.prompt_eval_duration / 1e9
    L ("  tokens generated : " + $r.eval_count)
    L ("  TOKENS/SEC       : " + [math]::Round($tokPerSec,1))
    L ("  time to first    : " + [math]::Round($firstTok,2) + "s")
    L ("  total wall clock : " + [math]::Round($sw.Elapsed.TotalSeconds,1) + "s")
  } catch { L ("  GENERATION FAILED: " + $_.Exception.Message) }

  # Is it fully on the GPU, or spilling into system RAM?
  $ps = (& docker exec nomadpc_ollama ollama ps 2>&1 | Out-String)
  ($ps -split "`n") | Where-Object { $_ -match $m.Split(":")[0] } |
    ForEach-Object { L ("  placement        : " + ($_ -replace '\s+',' ').Trim()) }
  (& docker exec nomadpc_ollama ollama stop $m 2>&1) | Out-Null
}
L ""
L "BENCH-DONE"

