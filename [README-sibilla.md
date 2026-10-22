# README-sibilla — greedy A/B per PR #14 (21-10 sera)

Scopo: dimostrare a jesdga che `/Zc:preprocessor` NON cambia l'output greedy.
Stesso sorgente (`c5f9fa24`), due binari, cambia solo la flag di compilazione CUDA.

- OFF: `H:\basalt-probe-off\bin\basalt.exe`  (senza flag = come CI di jesdga)
- ON : `H:\basalt-probe\bin\basalt.exe`      (con `-Xcompiler=/Zc:preprocessor`)
- Pack: `H:\basalt\models\Qwen3.8-FN-UD-Q4_K_XL.basalt`
- Config server: `H:\basalt\ab-serve.json` (porta 12342) — **senza BOM, non riscriverla da PS5!**
- Body richiesta: `H:\basalt\ab-body.json` (temp 0, max_tokens 96, logprobs) — **senza campo `model`** (l'API fa 404 se il nome non e' quello del pack; ometterlo e' legale)

## Comandi (Strata SPENTO!)

Finestra 1 — server (per il braccio ON cambia `probe-off` -> `probe`):

```powershell
H:\basalt-probe-off\bin\basalt.exe serve --config H:\basalt\ab-serve.json --python H:\Strata\.venv\Scripts\python.exe

H:\basalt-probe\bin\basalt.exe serve --config H:\basalt\ab-serve.json --python H:\Strata\.venv\Scripts\python.exe
```

Aspetta nella finestra che finisca il caricamento (pochi minuti; il warning "free VRAM + RAM"
che vedi AD ORA e' perche' Strata e' acceso e tiene la RAM: sparisce con Strata giu').

Finestra 2 — client, a caricamento avvenuto:

```powershell
# deve rispondere "status":{"value":"loaded"}
curl.exe -s http://127.0.0.1:12342/v1/models

# 4 generazioni greedy, cambiando solo -o: off1, off2 (server OFF), poi on1, on2 (server ON)
curl.exe -s http://127.0.0.1:12342/v1/chat/completions -H "Content-Type: application/json" --data-binary "@H:\basalt\ab-body.json" -o H:\basalt\ab-off1.json
curl.exe -s http://127.0.0.1:12342/v1/chat/completions -H "Content-Type: application/json" --data-binary "@H:\basalt\ab-body.json" -o H:\basalt\ab-off2.json

curl.exe -s http://127.0.0.1:12342/v1/chat/completions -H "Content-Type: application/json" --data-binary "@H:\basalt\ab-body.json" -o H:\basalt\ab-on1.json
curl.exe -s http://127.0.0.1:12342/v1/chat/completions -H "Content-Type: application/json" --data-binary "@H:\basalt\ab-body.json" -o H:\basalt\ab-on2.json
```

Danza completa: OFF -> off1, off2 -> Ctrl+C server -> ON -> on1, on2 -> Ctrl+C, poi:

```powershell
cd H:\basalt; .\ab-compare.ps1   # non serve GPU, va pure a Strata acceso
```

## Errore "needs --spec T ... and --prefill CHUNK"

Non e' la temperatura: e' il check dei prerequisiti di `basalt serve` (generate.cpp:4803), e
la T della frase e' quella di `--spec T`. Il messaggio elenca tre requisiti e non dice quale
manca; nel nostro caso era il secondo, perche' `prefill_chunk` parte da 0 e chi llama il
server tramite python non lo passa. Fix in ab-serve.json: `"prefill": "auto"` nella sezione
engine, che e' esattamente la forma usata dai comandi ufficiali in `docs/precision/builds.md`
(auto viene portato a 8192, pari al nostro max-context). Le altre due condizioni sono a posto:
con `"spec": 0` la speculazione e' spenta e la terza scatta solo se esiste gia' un expert
profile, che qui non c'e'.

## Parametri dei token: il thinking si mangiava tutto `max_tokens`

Il modello risponde con thinking esplicito, quindi `max_tokens` copre thinking + risposta: a 96
token finiva in `finish=length` durante il reasoning e usciva il warning
`max tokens reached while thinking` senza risposta. Il body ora ha `max_tokens: 8000` e
`reasoning_budget_tokens: 2048` (`service.py:97`: a quota budget il thinking viene chiuso e il
modello risponde; 0 = nessun tetto, default 0). Perche' 8000 e non 6144+2048: il tetto e' uno
solo e copre entrambi, e 6k di risposta + 2k di reasoning = 8192 sforerebbero il contesto con
il prompt (~100 token) gia' dentro. 8000 totali = risposta fino a ~5.9k anche a thinking pieno.
Parametri correlati, tutti a posto cosi': nessun tetto lato server oltre a `max-context` (8192)
e nessun `--temperature` di server da allineare, perche' il body chiede `temperature: 0`.

**DA CONTROLLARE DOPO LA PRIMA RUN**: se i `logprobs.content` coprono anche i token di reasoning
o solo la risposta. Il grep su `serve/` trova `logprobs` riempito solo nel path responses, e
nemmeno li' (`logprobs: []`): se il campo arriva vuoto o cortissimo allora il confronto
numerico solido sono i **token generati**, e il `max|dlogprob|` del compare va letto come
rumore su una lista quasi vuota, non come prova. Dichiararlo nel commento in PR, zero numeri
gonfiati.

## RAM: perche' il Q4_K_XL andava in OOM (21-10 notte)

`resident-experts: true` (flag che avevo messo io "per velocita'") fa copiare a basalt gli
experti in RAM PRIVATA e bloccata (budget auto 67.4 GiB) + prima copia gli esperti dal pack
nel cache blob su C: ("cache complement" 52.7 GiB, ~2 min) -> con paging file a zero, le ~60
GiB private + sporco in writeback non sono reclaimable e il watchdog ammazza il load a 965
MiB liberi. Strata invece tiene gli esperti nel file cache di sistema (reclaimable): ecco
perche' parte a 100 GB e scende a 80-90. FIX: flag rimosso da ab-serve.json (default =
streaming degli esperti, same mode del bench Q2_0) -> footprint ~30-35 GiB, margine enorme,
un filo piu' lento a generare ma per l'identity check la velocita' non conta.

Piano B (se servisse, RICHIEDE REBOOT): pagefile temporaneo 20 GB:
```powershell
# da ADMIN - attiva pagefile fisso 20 GB su C:
(Get-CimInstance Win32_ComputerSystem).SetAutomaticManagedPagefile($false)
New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name='C:\pagefile.sys'; InitialSize=20480; MaximumSize=20480 }
shutdown /r /t 0
# per tornare al pagefile ZERO (decisione di casa):
Remove-CimInstance (Get-CimInstance Win32_PageFileSetting)   # da ADMIN, poi reboot
```

## Verdetto atteso

- righe RUMORE (off1-vs-off2, on1-vs-on2): rumore di fondo del sistema
- righe CROSS (off-vs-on): `token diversi 0` e `max|dlogprob|` <= rumore -> **greedy token-identico**, e il commento numero 3 va in PR (file `.pr-comment-3.md` da creare, `gh pr comment 14 --repo jesdga95/basalt --body-file`)

## I due bug che hanno fatto perdere tempo (risolti)

1. **BOM**: `Set-Content -Encoding UTF8` di PS5 mette una firma invisibile a inizio file che
   basalt rigetta (`Unexpected UTF-8 BOM`) -> il server moriva in 2 secondi e la finestra
   minimized si portava via l'errore. Config e body ora sono senza BOM.
2. **Campo `model` nel body**: l'API fa 404 se il nome non coincide col pack -> ora omesso.

## Alternativa script (oramai ripuliti, se non vuoi toccare niente a mano)

```powershell
cd H:\basalt
.\ab-run-off.ps1    # Strata SPENTO -> ab-off1.json ab-off2.json (log: ab-run-off.log)
.\ab-run-on.ps1     # Strata SPENTO -> ab-on1.json  ab-on2.json  (log: ab-run-on.log)
.\ab-compare.ps1    # verdetto, senza vincoli
```
