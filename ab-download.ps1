# ab-download.ps1 - scarica il pack Q4_K_XL .basalt con resume ostinato. 20-10, Sibilla.
$ErrorActionPreference = 'Continue'
$dst = 'H:\basalt\models\Qwen3.8-FN-UD-Q4_K_XL.basalt'
$url = 'https://huggingface.co/jesdga/Qwen3.8-Flash-Next-Basalt/resolve/main/Qwen3.8-FN-UD-Q4_K_XL.basalt'
Start-Transcript -Path 'H:\basalt\ab-download.log' -Force | Out-Null
try {
  $h = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30
  $exp = [long](@($h.Headers['Content-Length'])[0])
  "attesi: $exp bytes ($([math]::Round($exp/1GB,1)) GB)"
} catch { "HEAD fallita, niente check finale: $($_.Exception.Message)"; $exp = 0 }
for ($i = 0; $i -lt 60; $i++) {
  $have = if (Test-Path $dst) { (Get-Item $dst).Length } else { 0 }
  if ($exp -gt 0 -and $have -ge $exp) { break }
  "tentativo $($i+1): da $([math]::Round($have/1GB,2)) GB  $(Get-Date -Format HH:mm:ss)"
  # stderr nel vuoto: in PS5 il stderr nativo redirectato a file diventa un
  # NativeCommandError che ammazza il loop. Watchdog a 200 KB/s x 120 s, cosi
  # un ponte wifi che balbetta col temporale non ammazza la corsa.
  $code = Start-Process curl.exe -ArgumentList @('-L','--fail','-C','-','--retry','8','--retry-delay','10','--speed-limit','204800','--speed-time','120','--no-progress-meter','-o',$dst,$url) -Wait -PassThru -WindowStyle Hidden
  "curl exit: $($code.ExitCode)"
  Start-Sleep -Seconds 10
}
$have = if (Test-Path $dst) { (Get-Item $dst).Length } else { 0 }
if ($exp -gt 0 -and $have -ge $exp) { "DOWNLOAD COMPLETO: $have / $exp" }
elseif ($exp -eq 0) { "fine retry, dimensione finale: $have (verify manuale)" }
else { "INCOMPLETO: $have / $exp dopo 30 tentativi" }
Stop-Transcript | Out-Null
