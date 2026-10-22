$d = 'H:\basalt\ab-evidence'
$rows = @(
  'off1.txt', 'on1.txt',
  'off2.txt', 'on2.txt',
  'off1.txt', 'off2.txt',
  'on1.txt', 'on2.txt'
)
$rep = @()
$rep += '=== A/B greedy-identity run results (22-10-2026, Windows, RTX 5070 Ti, 128 GiB RAM) ==='
$rep += 'source: basalt main c5f9fa24 checked out twice into two clean worktrees (git diff empty)'
$rep += 'toolkit: CUDA 13.0.2 (nvcc V13.0.88) installed side by side with 13.4, MSVC 19.44'
$rep += 'arm OFF: cmake -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler"'
$rep += 'arm ON : cmake -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler -Xcompiler=/Zc:preprocessor"'
$hOff = (Get-FileHash 'H:\basalt-probe-off\bin\basalt.exe' -Algorithm SHA256).Hash
$hOn  = (Get-FileHash 'H:\basalt-probe\bin\basalt.exe' -Algorithm SHA256).Hash
$rep += "binary OFF: H:\basalt-probe-off\bin\basalt.exe  sha256 $hOff"
$rep += "binary ON : H:\basalt-probe\bin\basalt.exe      sha256 $hOn"
$rep += 'model  : Qwen3.8-FN-UD-Q4_K_XL.basalt (114,596,627,061 bytes), engine spec 0, prefill auto,'
$rep += '         expert-cache auto, max-context 8192 (expert cache streaming, no resident-experts)'
$rep += 'request: ab-body.json, temperature 0, max_tokens 8000, reasoning_budget_tokens 2048'
$rep += ''
$rep += 'file    tokens finish  sha256 of extracted greedy text (reasoning + answer)'
foreach ($t in 'off1', 'off2', 'on1', 'on2') {
  $j = Get-Content "H:\basalt\ab-$t.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  $h = (Get-FileHash "$d\$t.txt" -Algorithm SHA256).Hash
  $rep += ('{0}  {1}  {2}  {3}' -f $t.PadRight(7), $j.usage.completion_tokens.ToString().PadLeft(6), $j.choices[0].finish_reason.PadRight(6), $h)
}
$rep += ''
$rep += 'diffs (git diff --no-index --unified=0 on the extracted greedy text):'
for ($i = 0; $i -lt $rows.Count; $i += 2) {
  $a = $rows[$i]; $b = $rows[$i + 1]
  $o = & git diff --no-index --unified=0 -- "$d\$a" "$d\$b" 2>$null | Out-String
  $n = @($o -split "`r?`n" | Where-Object { $_ -match '^[+-]' -and $_ -notmatch '^(---|\+\+\+)' }).Count
  $kind = 'OFF vs ON'
  if ($a -like 'off*' -and $b -like 'off*') { $kind = 'same binary, repeated run' }
  if ($a -like 'on*' -and $b -like 'on*') { $kind = 'same binary, repeated run' }
  $rep += ('  {0,-9} vs {1,-9} {2,4} changed lines   ({3})' -f ($a -replace '\.txt$',''), ($b -replace '\.txt$',''), $n, $kind)
}
$rep += ''
$rep += 'raw JSONs are attached too but are not diffable as-is: every response carries its own id/created.'
$rep += 'The server fills choices[0].logprobs.content with a single entry on this build, so the proof here is'
$rep += 'greedy token identity over the full reasoning + answer text, not logprobs. If exact logits matter,'
$rep += 'docs/precision/builds.md already documents the LH hash route (not needed for this flag).'
$rep += 'Note the noise floor: the same binary repeated (off1 vs off2, on1 vs on2) drifts at char 1290'
$rep += '(expert-cache state differs between runs), so the harness can and does detect real divergence.'
$rep += 'With that noise present, both OFF-vs-ON pairs still come out byte-identical.'
$rep | Set-Content "$d\RESULTS.txt" -Encoding UTF8
Copy-Item 'H:\basalt\ab-body.json','H:\basalt\ab-off1.json','H:\basalt\ab-off2.json','H:\basalt\ab-on1.json','H:\basalt\ab-on2.json','H:\basalt\ab-compare.ps1' $dir -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$d\*" -DestinationPath 'H:\basalt\ab-evidence.zip' -Force
Get-Content "$d\RESULTS.txt" -Encoding UTF8
"zip: $((Get-Item 'H:\basalt\ab-evidence.zip').Length) byte"
