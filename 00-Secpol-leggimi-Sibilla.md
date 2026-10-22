# 00 — SecPolleggimi, Sibilla 🐍⚡

> promemoria per Basalt su Windows — cosa abbiamo concesso ai privilegi e perché.
> (nome scelto da Matt, 19-10-2026 — «così lo apro se mi scordo».)

## A cosa serve
`docs/platforms.md` di Basalt pretende due privilegi Windows per andare veloce:

| privilegio | nome interno | a cosa serve in basalt |
|---|---|---|
| **Blocco pagine in memoria** | `SeLockMemoryPrivilege` | pagine grandi per l'arena expert + memoria pinned; senza, ricade su pagine 4 KiB (e lo dice all'avvio) |
| **Aumenta set di lavoro di un processo** | `SeIncreaseWorkingSetPrivilege` | bloccare in RAM la copia residente degli expert |

## STATO: GIÀ APPLICATO il 19-10-2026 dall'agente di Matt (via `secedit`; lo script ri-lanciabile
è **`grant-secpol-basalt.ps1` in questa stessa cartella** — parte da solo elevato e scrive
`secpol-grant.log` qui accanto):

```text
SeLockMemoryPrivilege        = Matt
SeIncreaseWorkingSetPrivilege = Matt, *S-1-5-32-545   (il Guests di serie, non l'abbiamo messo noi)
```

**IMPORTANTE: vale dalla prossima RIPETUTA SESSIONE** (logoff+login o riavvio): i privilegi
vengono innestati nel token al logon. Finché non rillogate, basalt stamperà il fallback
4 KiB e fa schifo ugualmente ma piano.

## Verifica
1. Dopo logoff/login, in un PowerShell nuovo:
   `whoami /priv | Select-String 'SeLockMemory|SeIncreaseWorkingSet'`
   → devono apparire tutti e due con stato `Enabled` (o `Disabled`, che basta: il processo
   se li abilita da solo quando servono).
2. All'avvio di `basalt serve` NON dovreste più vedere la nota sul fallback 4 KiB / cap
   pinned. Se c'è ancora, rilloggate di nuovo.

## Rifarlo / tornare indietro (GUI, se un giorno serve)
1. `secpol.msc` → Criteri locali → Assegnazione diritti utente
   (su Windows Home secpol non c'è: usare `secedit` come abbiamo fatto noi, o il trucco LSA);
2. **"Blocco pagine in memoria"** e **"Aumenta set di lavoro di un processo"** → aggiungi/rimuovi utente;
3. logoff + login.

Riga rapida per ri-applicare da PowerShell **elevato** (metodo usato noi):

```powershell
secedit /export /cfg $env:TEMP\sp.cfg
# modificare le righe SeLockMemoryPrivilege / SeIncreaseWorkingSetPrivilege aggiungendo ,*$SID
secedit /configure /db $env:TEMP\sp.sdb /cfg $env:TEMP\sp.cfg /overwrite /quiet
# (al termine: apply exit=1 con le righe scritte = avvertimento innocuo, guardare la verifica)
```

## Contesto: i due NON sono le uniche cose "strane" di Basalt su Windows
Ricordati pure (dal suo `docs/platforms.md`):
- peer/multi-GPU bloccati all'avvio (una GPU sola);
- pinned memory cappato dal driver WDDM (~RAM/2−8 GiB se l'arena non registra tutta);
- TDR: se kernel lunghi vengono resetzati, alzare `TdrDelay` in
  `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`;
- qualità mai misurata da loro su Windows (noi la misuriamo, ovvio).
