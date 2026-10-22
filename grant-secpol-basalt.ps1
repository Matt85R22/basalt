# grant-secpol-basalt.ps1 — concede all'utente corrente i due privilegi che basalt chiede su Windows
#   (docs/platforms.md: "Large pages need 'Lock pages in memory'; locking the resident
#    expert copy needs 'Increase a process working set'").
# Gia' APPLICATO il 19-10-2026 (vedi 00-Secpol-leggimi-Sibilla.md). Relanciare solo se si
# vuole ri-applicare dopo un reset delle policy. Serve elevazione: parte da se stessa
# con Start-Process -Verb RunAs se non e' admin. Log: secpol-grant.log nella stessa cartella.
$ErrorActionPreference = 'Stop'
$log = Join-Path $PSScriptRoot 'secpol-grant.log'

$amAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $amAdmin) {
    Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    if (Test-Path $log) { Get-Content $log }
    exit
}

try {
    $sid = whoami /user | Out-String | ForEach-Object { if ($_ -match '(S-1-5-21-\d+-\d+-\d+-\d+)') { $Matches[1] } }
    $cfg = Join-Path $env:TEMP 'secpol-basalt.cfg'   # appoggio temporaneo di secedit, non uno script
    secedit /export /cfg $cfg
    $lines = Get-Content $cfg
    $out = foreach ($l in $lines) {
        if ($l -match '^SeLockMemoryPrivilege\s*=\s*(.*)$') {
            $v = $Matches[1].Trim().Trim(',').Trim()
            if ($v -and $v -like "*$sid*") { $l } elseif ($v) { "SeLockMemoryPrivilege = $v,*$sid" } else { "SeLockMemoryPrivilege = *$sid" }
        } elseif ($l -match '^SeIncreaseWorkingSetPrivilege\s*=\s*(.*)$') {
            $v = $Matches[1].Trim().Trim(',').Trim()
            if ($v -and $v -like "*$sid*") { $l } elseif ($v) { "SeIncreaseWorkingSetPrivilege = $v,*$sid" } else { "SeIncreaseWorkingSetPrivilege = *$sid" }
        } else { $l }
    }
    if (-not ($out | Where-Object { $_ -match '^SeLockMemoryPrivilege' }))         { $out += "SeLockMemoryPrivilege = *$sid" }
    if (-not ($out | Where-Object { $_ -match '^SeIncreaseWorkingSetPrivilege' })) { $out += "SeIncreaseWorkingSetPrivilege = *$sid" }
    Set-Content -Path ($cfg + '.new') -Value $out -Encoding Unicode
    secedit /configure /db (Join-Path $env:TEMP 'secpol-basalt.sdb') /cfg ($cfg + '.new') /overwrite /quiet
    "apply exit=$LASTEXITCODE (1 = avvertimento innocuo se le righe risultano scritte)" | Add-Content $log
    $chk = Join-Path $env:TEMP 'secpol-basalt.check'
    secedit /export /cfg $chk | Out-Null
    '=== verifica ===' | Add-Content $log
    Select-String -Path $chk -Pattern 'SeLockMemory|SeIncreaseWorkingSet' | ForEach-Object { $_.Line.Trim() | Add-Content $log }
    'OK-FINITO (vale dalla prossima sessione: logoff+login)' | Add-Content $log
} catch {
    "ERRORE: $($_.Exception.Message)" | Add-Content $log
}
