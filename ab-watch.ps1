# ab-watch.ps1 - appena CUDA 13.0.2 e' installato, lancia la doppia build A/B. 20-10, Sibilla.
$ErrorActionPreference = 'Continue'
Start-Transcript -Path 'H:\basalt\ab-watch.log' -Force | Out-Null
$nvcc = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0\bin\nvcc.exe'
$elapsed = 0
while ($elapsed -lt 7200) {
  if (Test-Path $nvcc) { Start-Sleep -Seconds 20; break }
  $inst = @(Get-Process | Where-Object { $_.Name -like 'cuda_13.0*' -or $_.Name -like 'NVIDIA Installer*' }).Count
  if ($inst -eq 0 -and $elapsed -gt 300) { "INSTALLER morto e nvcc 13.0 mancante: installazione fallita o UAC negato"; break }
  Start-Sleep -Seconds 30; $elapsed += 30
}
if (Test-Path $nvcc) {
  "nvcc 13.0 presente dopo $elapsed s -> A/B build via"
  cmd /c 'H:\basalt\ab-13.0.2-build.cmd > H:\basalt\ab-build.log 2>&1'
  "ab-build exitcode: $LASTEXITCODE"
  Get-Content 'H:\basalt\ab-build.log' -Tail 20
}
Stop-Transcript | Out-Null
