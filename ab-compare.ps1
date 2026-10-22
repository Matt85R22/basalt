# ab-compare.ps1 - v2, basata sui TESTI (i logprob arrivano con 1 sola voce: non informativo).
# Confronta reasoning_content + content dei 4 run: hash esatti e primo carattere divergente.
$ErrorActionPreference = 'Stop'
function Get-Testo($tag) {
  $f = "H:\basalt\ab-$tag.json"
  if (-not (Test-Path $f)) { return $null }
  $j = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
  $m = $j.choices[0].message
  $t = "$($m.reasoning_content)`n===RISPOSTA===`n$($m.content)"
  $sha = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($t))) -Algorithm SHA256).Hash
  return @{ tag = $f; txt = $t; sha = $sha; tok = $j.usage.completion_tokens; fin = $j.choices[0].finish_reason; n = $t.Length }
}
function Confronta($a, $b, $label) {
  if (-not $a -or -not $b) { Write-Host ("{0}: file mancante" -f $label); return $null }
  if ($a.sha -eq $b.sha) { Write-Host ("{0}: IDENTICI al byte (sha {1}...)" -f $label, $a.sha.Substring(0, 12)); return $true }
  $lim = [Math]::Min($a.n, $b.n); $i = 0
  while ($i -lt $lim -and $a.txt[$i] -eq $b.txt[$i]) { $i++ }
  $intorno = if ($i -gt 60) { $a.txt.Substring($i - 55, 55) } else { $a.txt.Substring(0, [Math]::Min(55, $i)) }
  Write-Host ("{0}: DIVERSI al char $i di $($a.n)/$($b.n)  ...{1} | A=... B=..." -f $label, ($intorno -replace "`r|`n", ' '))
  if ($i -eq $lim) { Write-Host ("{0}: uno e' prefisso esatto dell'altro (fineEOS/length diversa)" -f $label) }
  return $false
}
foreach ($t in 'off1', 'off2', 'on1', 'on2') {
  $x = Get-Testo $t
  if ($x) { "{0}: {1} token, finish={2}, {3} char, sha {4}..." -f $t, $x.tok, $x.fin, $x.n, $x.sha.Substring(0, 12) }
  else    { "${t}: MANCANTE" }
}
''
$o1 = Get-Testo 'off1'; $o2 = Get-Testo 'off2'; $n1 = Get-Testo 'on1'; $n2 = Get-Testo 'on2'
$r1 = Confronta $o1 $o2 'RUMORE off1-vs-off2'
$r2 = Confronta $n1 $n2 'RUMORE on1 -vs-on2 '
$c1 = Confronta $o1 $n1 'CROSS  off1-vs-on1 '
$c2 = Confronta $o2 $n2 'CROSS  off2-vs-on2 '
''
if ($c1 -and $c2) { 'VERDETTO: i due bracci producono testo IDENTICO al byte.' }
elseif (($c1 -eq $false -and $r1 -eq $false) -or ($c2 -eq $false -and $r2 -eq $false)) {
  "VERDETTO: i bracci divergono MA divergono anche le ripetizioni dello STESSO braccio:"
  "  la differenza non e imputabile al flag, e non-determinismo del motore (da dichiarare in PR)."
}
else { "VERDETTO: i bracci divergono mentre le ripetizioni interne sono identiche -> il flag CAMBIA l'output." }
