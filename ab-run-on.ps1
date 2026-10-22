# ab-run-on.ps1 - braccio ON (con /Zc:preprocessor). Usa e getta, path scolpiti.
# 21-10, Sibilla. Richiede: Strata SPENTO. Produce ab-on1.json ab-on2.json + log.
$ErrorActionPreference = 'Stop'
Start-Transcript -Path 'H:\basalt\ab-run-on.log' -Force | Out-Null
$exe   = 'H:\basalt-probe\bin\basalt.exe'       # << BRACCIO ON, scolpito
$cfg   = 'H:\basalt\ab-serve.json'
$py    = 'H:\Strata\.venv\Scripts\python.exe'
$model = 'H:\basalt\models\Qwen3.8-FN-UD-Q4_K_XL.basalt'
$port  = 12342; $base = "http://127.0.0.1:$port"

if (Get-Process strata -ErrorAction SilentlyContinue) { "ERRORE: Strata ancora acceso, spegnilo prima."; exit 1 }
if (-not (Test-Path $exe))   { "ERRORE: manca $exe"; exit 1 }
if (-not (Test-Path $model)) { "ERRORE: manca il pack $model"; exit 1 }
if (-not (Test-Path $cfg)) { "ERRORE: manca $cfg - e' gia' stato scritto senza BOM, ricontrolla"; exit 1 }
if (-not (Test-Path 'H:\basalt\ab-body.json')) { "ERRORE: manca H:\basalt\ab-body.json"; exit 1 }

foreach ($n in 1, 2) {
  "=== run on$n  $(Get-Date -Format HH:mm:ss) ==="
  $p = Start-Process -FilePath $exe -ArgumentList @('serve','--config',$cfg,'--python',$py) -PassThru -WindowStyle Minimized
  $deadline = (Get-Date).AddMinutes(40); $ready = $false
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 15
    try {
      $m = Invoke-RestMethod -Uri "$base/v1/models" -TimeoutSec 5
      if ("$($m.data.status.value)" -match 'loaded') { $ready = $true; break }
      "  stato: $($m.data.status.value)"
    } catch {
      if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) { "  ERRORE: server morto, vedi sotto la sua finestra"; exit 1 }
    }
  }
  if (-not $ready) { "TIMEOUT carico modello"; taskkill /T /F /PID $p.Id 2>$null | Out-Null; exit 1 }
  "  modello loaded, generazione..."
  $resp = Invoke-RestMethod -Uri "$base/v1/chat/completions" -Method Post -ContentType 'application/json' -Body (Get-Content 'H:\basalt\ab-body.json' -Raw) -TimeoutSec 1800
  $out = "H:\basalt\ab-on$n.json"
  $resp | Set-Content $out -Encoding UTF8
  "  salvato $out ($(@($resp.choices[0].logprobs.content).Count) token con logprob)"
  taskkill /T /F /PID $p.Id 2>$null | Out-Null
  $t = 0; while (@(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue).Count -gt 0 -and $t -lt 60) { Start-Sleep -Seconds 3; $t += 3 }
}
"run on1+on2 complete. Poi: .\ab-compare.ps1 (pure a Strata acceso)"
Stop-Transcript | Out-Null
