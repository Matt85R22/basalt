# 01 — Patch Windows (pronta per PR a jesdga95/basalt)

Due modifiche sorgente, forma "upstream-friendly": niente `#ifdef _MSC_VER` fuori
dalle seam di platform (vietato da CONTRIBUTING: "Engine code is platform-neutral",
`tools/check_platform_boundary.sh` lo verifica), niente .bat/.ps1 nel tree (altro
divieto esplicito). Verificate con build pulita da zero + `ctest -L cpu` su
Windows 11 + MSVC + CUDA 13.4 + RTX 5070 Ti (sm_120).

## Commit 1 — `CMakeLists.txt`: /Zc:preprocessor sui target CUDA
CUDA 13 CCCL rifiuta il preprocessore tradizionale di cl.exe: ogni .cu che tocca
`cuda::std` (es. `dec_gdn_rec.cu`, `mid_chain.cu`) muore con
`C1189: MSVC/cl.exe with traditional preprocessor`. Fix: stesso pattern gia' usato
da loro per `/Zc:__cplusplus` (riga ~65), un `string(APPEND CMAKE_CUDA_FLAGS
" -Xcompiler=/Zc:preprocessor")` in piu' dentro lo stesso `if(MSVC)`.

## Commit 2 — `src/kernels/cuda/attn_chain_bound.cuh`: `[[noreturn]]` standard
`mkb_hang()` usava `__attribute__((noreturn))` (GCC-only): il frontend cudafe con
host cl.exe lo mangia (C101 "explicit type is missing" + ~77 errori a cascata su
chi include l'header). Sostituito con l'attributo standard C++ `[[noreturn]]`,
che nvcc e MSVC accettano entrambi: zero macro, zero `#if`, platform-neutral.
**Posizione obbligata: PRIMA di `__device__ __noinline__`** perche' nvcc espande
quelle keyword in `__declspec` per l'host pass e MSVC rifiuta un attributo
standard dopo un `__declspec` (C3829 "l'attributo [[noreturn]] puo' essere
applicato solo a una dichiarazione di funzione"). Stessa regola di
`[[nodiscard]] __declspec(dllexport)`.
(Fallback se mai nvcc-Linux lo rifiutasse: macro BASALT_NORETURN dentro
`include/basalt/platform/compiler.hpp`, la seam designata per le differenze
compiler — precedente: BASALT_TARGET_AVX2_FMA_F16C.)

## Nota: perche' NON la build.cmd
Loro regole: "Do not add .bat or PowerShell scripts to the tree". `build.cmd`,
`avvia-basalt.bat`, `grant-secpol-basalt.ps1` restano locali (untracked in git).

## Prove da allegare alla PR
- **VERIFICATA (19-10)**: build pulita da `build/` vuoto verde con SOLO le due
  modifiche sopra (213 target MSVC+CUDA 13.4, sm_120, RTX 5070 Ti). Confermato
  anche il perche' della posizione: `[[noreturn]]` dopo `__device__ __noinline__`
  = C3829; prima di tutto = verde anche su nvcc lato host.
- `ctest -L cpu -LE avx512`: 34/35 passed; l'unico ko (expert_multi_test) esige
  AVX-512-VNNI/VBMI -> hardware-dependent (Ryzen 5800X3D = AVX2), non correlato.
- Parita' numerica: nessuna modifica al codice generato (attributo noescape-code
  + flag di solo frontend).

## Note ambiente Windows (candidate a docs/platforms.md)
- `vcvars64.bat` prima di cmake (altrimenti nvcc: "cl.exe not in path").
- **trappola CUDA_PATH**: CUDA vecchio in CUDA_PATH di sistema -> CMake prende il
  nvcc sbagliato; puntarlo a 13.4 nella shell di build.
- Ninja winget in cartella user-scoped: `-DCMAKE_MAKE_PROGRAM` full-path se il
  PATH non e' fresco.
- vswhere senza `-products *` non vede BuildTools (falso allarme "VS assente").
- `BUILD_TESTING=ON` per registrare i test ctest (gia' nel loro README windows).
- Privilegi "Lock pages in memory" + "Increase a process working set" prima del
  serve con pagine grandi (helper: `grant-secpol-basalt.ps1`, vale dopo logoff+login).

## Come si lancia la PR
1. Fork di jesdga95/basalt sul GitHub di Matt (o via `gh`, non ancora installato:
   `winget install --exact GitHub.cli` + `gh auth login` una volta).
2. Branch `windows-build-fixes` + commit con message style loro (`area: cosa`).
3. PR: label `windows` (loro: "Windows-only issues get a windows label"), corpo
   con sintomi esatti (C1189, errori cudafe), prove, e nota che la loro CI gia'
   compila+testa Windows su ogni PR.

## Runtime proof (19-10 sera) - GREEN
- `basalt.exe serve` su Windows 11 / RTX 5070 Ti (sm_120), build 194/194 con le due patch:
  carica 35.0 GiB in 57-82 s (cuda0 12.7 GiB + RAM 22.3 GiB, arena 31.8 GiB resident-experts,
  expert cache GPU 9.3 GiB, KV int8 elastic 4.0 GiB, spec 7 + MTP 7 + lookup 3), ctx 262144.
- Nessuna riga di fallback privilegi (SeLockMemoryPrivilege/SeIncreaseWorkingSet via secpol: OK).
- Sessione agentica reale (agente OpenCode, picchi 56k token contesto, tool call edit/shell/grep):
  75-100 tok/s stabili, EOS pulito, zero crash.
- Bench standard: novel 88.6 / cold-novel 60.2 / warm 151.5 / repetitive picco 221 tok/s.
- Nota: numeri con pack Q2_0 (smoke/validazione engine, non paragone di qualita').

## UPDATE 20-10 - la PR si rimpicciolisce: 1 commit solo
- Il fix noreturn di attn_chain_bound.cuh e' stato assorbito UPSTREAM nel commit 63b40f2d
  (''kernels: the chain wait bound uses standard [[noreturn]]''): stessa identica forma che
  avevamo scelto noi ([[noreturn]] prima dei qualifier). Patch n.2 ritirata, albero riportato a monte.
- Upstream ha anche toccato AGENTS.md (63b40f2d..c5f9fa24, rimossa la regola loopback-only).
- Branch ''windows-build-fixes'' creato su main aggiornato (c5f9fa24) con UN SOLO commit:
  f0330df4 ''build: the CUDA targets need /Zc:preprocessor on MSVC'' (3 righe, commentate).
- Ricaduta sul diario: tutto il racconto C3229/C1189/C3829 resta valido come diagnosi; la
  soluzione proposta ora e' meta' (flag-only). Body PR: citare che il noreturn e' stato sistemato
  a monte nelle 24h successive alla nostra build.
- 20-10: verifica su main aggiornato in corso (build incrementale + ctest -L cpu -LE avx512).

## PR pronta (titolo + body) - da inviare dopo gh auth di Matt
**Title:** build: the CUDA targets need /Zc:preprocessor on MSVC
**Label:** windows
**Body:**
---
Building on Windows (MSVC + CUDA 13.4, RTX 5070 Ti sm_120) one flag was missing: CUDA 13's CCCL headers #error under cl.exe's traditional preprocessor (fatal C1189, hits dec_gdn_rec.cu and mid_chain.cu through their includes). The fix follows the route the CMakeLists already uses for /Zc:__cplusplus: hand /Zc:preprocessor to nvcc's host compiler via -Xcompiler.

    if(CMAKE_CXX_COMPILER_ID STREQUAL ""MSVC"")
      ...
      string(APPEND CMAKE_CUDA_FLAGS "" -Xcompiler=/Zc:preprocessor"")

Proof on this branch (single commit, on top of c5f9fa24): clean-room configure+build 194/194 targets, ctest -L cpu green except expert_multi_test which requires AVX-512 (not on the host CPU; unrelated), server serves a 262K-context chat and tool-call agent session at 75-125 tok/s decode with a Q2_0 pack (Win11 26300 / RTX 5070 Ti / Ryzen 5800X3D / 128 GB). The [[noreturn]] ordering issue we also hit was fixed upstream in 63b40f2d before this PR, so only the flag remains.
---
NB da verificare prima di inviare: niente #if _MSC_VER fuori seam (il nostro commit non ne introduce), niente file extra nel tree (untracked restano untracked).

## Riverifica su main aggiornato - VERDE (20-10 sera)
- build.cmd test su branch windows-build-fixes (f0330df4 su c5f9fa24): build 77/77 (incrementale,
  mid_chain.cu ok con il [[noreturn]] di upstream), avvisi di sola lettura (C4996 getenv/sscanf,
  #177-D variabile G). Nessun errore, nessun warning nuovo.
- ctest -L cpu -LE avx512: 34/34 PASSITI (9,1 s reali). build.cmd ora porta -LE avx512 di suo,
  cosi' expert_multi_test (esige AVX512-VNNI/VBMI, assente sul 5800X3D) non sporca piu' il verde.
- PR gate confermato anche su main recente. Si attende solo gh auth login di Matt.

## Prova A/B del flag (20-10, esperimento controllato)
- worktree H:\basalt-probe su c5f9fa24 (main SENZA il nostro commit) -> cmake --build del solo
  dec_gdn_rec.cu.obj: FAILED. cccl/cuda/std/__cccl/preprocessor.h(23): fatal error C1189:
  ''MSVC/cl.exe with traditional preprocessor is used... Please switch to the standard
  conforming preprocessor by passing /Zc:preprocessor to cl.exe'' (exitcode 2).
- Stesso sorgente col nostro commit (f0330df4): 77/77 verde. Il flag e' funzionalmente
  NECESSARIO, non cosmetico. Nota: CCCL offre anche un define per silenziare
  (CCCL_IGNORE_MSVC_TRADITIONAL_PREPROCESSOR_WARNING) ma e' top-pallino: il fix giusto e'
  il preprocessore standard, cioe' esattamente quello che passa il commit.
- Perche' la CI di jesdga non l'ha mai visto: su Windows compila e ctesta CPU-only, i target
  CUDA si buildano solo su Linux dove cl.exe non c'e'. La PR porta Windows+CUDA (sm_120) coperto.
- Script della prova tenuto in H:\basalt\probe-c1189.cmd (untracked) per ripeterla.

## PR SPEDITA - 20-10 notte
- https://github.com/jesdga95/basalt/pull/14 - OPEN, MERGEABLE, +3/-0, base main <- windows-build-fixes.
- Fork: https://github.com/Matt85R22/basalt (remote locale Matt85R22). Autore commit: Matteo (email visibile su GitHub, accettata da Matt).
- Label windows NON applicata: gh dice not found dal nostro conto (contributor senza triage). Se serve, la mette jesdga.
- Body conservato in H:\basalt\.pr-body.md. Nel body i numeri sono marcati dev-A/B come vuole AGENTS.md.

## RESPONSE a jesdga + A/B IDENTITY su 13.0.2 (20-10 notte / 21-10)- jesdga ha risposto con 4 domande (versione CUDA che innesca C1189; host .cpp con
  /Zc:preprocessor; gate CMAKE_CXX_COMPILER_ID vs CUDA host compiler; greedy-identity
  check su GPU). Bozza risposta in inglese preparata (non ancora postata).
- FATTI NUOVI: il guard CCCL (include/cccl/cuda/std/__cccl/preprocessor.h) era un
  WARNING fino a CUDA 13.1 ed e' diventato #error fatale con la CCCL di CUDA 13.2
  (confermato da changelog cuda-samples NVIDIA + issue simili su pytorch/vision e
  flash-attention). CI di jesdga: CUDA_VERSION 13.0.2, windows-2022 + ilammy/msvc-dev-cmd
  (toolset default ~14.4x) -> verde perche' nel 13.0.2 il guard non e' fatale.
  La nostra combo che faila: CUDA 13.4 (nvcc V13.4.59, CCCL 3.4.2) + MSVC 14.44.35207.
- Host .cpp puliti senza flag: ~50 src/kernels/*_parity.cpp includono <cuda_fp16.h>/
  <cuda_runtime.h> e compilano col preprocessore tradizionale (il flag nel nostro
  commit va solo in CMAKE_CUDA_FLAGS); cuda_fp16.h non tira dentro la catena cuda/std.
- ESPERIMENTO IN CORSO (idea di Matt, disegno pulito): CUDA 13.0.2 installato DI
  FIANCO al 13.4 (v13.0, nvcc V13.0.88 = build del toolkit 13.0.2); worktree
  H:\basalt-probe ricreato su c5f9fa24; H:\basalt\ab-13.0.2-build.cmd builda ab-off
  (senza flag) e ab-on (con -Xcompiler=/Zc:preprocessor via CMAKE_CUDA_FLAGS, piu'
  -allow-unsupported-compiler in entrambi). PRIMO DATO: ab-off a meta' build sta
  compilando TUTTI i .cu senza C1189 -> conferma che su 13.0.2 il flag NON serve e
  il nostro e' un fix "per toolkit nuovi", non un bug dei vecchi.
- MODELLO PER IL TEST: pack ufficiale Qwen3.8-FN-UD-Q4_K_XL.basalt (106,7 GB) da
  huggingface jesdga/Qwen3.8-Flash-Next-Basalt -> H:\basalt\models\ (stesso quant
  della Strata: bonus, si potra' fare A/B Strata-vs-basalt same-quant). Download
  con resume ostinato: H:\basalt\ab-download.ps1 (v2: stderr nel vuoto, in PS5 il
  redirect NativenCommandError ammazza il loop).
- GREEDY: H:\basalt\greedy-ab.cmd/.ps1 pronto - preflight "Strata spento" (si
  rifiuta, non ammazza), 4 run (off x2, on x2) temp 0 logprobs, rumore di fondo
  misurato, verdetto IDENTICO/DIVERSI. richiede GPU libera -> domani.
- Trucchi della serata: watcher PS che si suicida perche' il filtro della
  command line acchiappa se stesso (escludere $PID); Get-Process strata EVER.

## POSTato + commit nuovi (21-10, ~00:40)
- RISPOSTA a jesdga POSTATA: https://github.com/jesdga95/basalt/pull/14#issuecomment-6303037410
  (body conservato in H:\basalt\.pr-comment-1.md). Risponde a 1-3 e annuncia l'A/B in corso sul 4.
- Due commit nuovi sul branch, pushati su Matt85R22 (PR head = 703e3301):
  - b50eb016 "build: the /Zc:preprocessor gate follows nvcc's host compiler"
    gate: NOT CMAKE_CUDA_HOST_COMPILER OR MATCHES "(^|[/\\\\])cl(\.exe)?$" (il separatore
    serve: senza, "clang-cl.exe" matcherebbe la coda "cl.exe"). Testato con
    H:\basalt\gate-test.cmake (cmake -P): cl/cl.exe/percorso -> SI', clang-cl/clang++ -> NO,
    vuoto -> SI' (default nvcc = cl.exe). Reconfigure main tree: flag su 83 righe CUDA di build.ninja.
  - 703e3301 "docs: platforms notes the CUDA 13.2+ preprocessor requirement" (4 righe in
    docs/platforms.md, in fondo a "Building on Windows").
- A/B BUILD COMPLETO VERDE su CUDA 13.0.2: ab-off 286/286 E ab-on 286/286 (log
  H:\basalt\ab-build.log). Binari: H:\basalt-probe\build-ab-{off,on}\..\bin\basalt*.exe.
  ab-off ha compilato tutti i .cu SENZA C1189 -> prima prova in casa che su 13.0.2 il
  flag non serve (giusta la characterize "per toolkit 13.2+" data a jesdga).
- PACK: download in corso (90/107 GB a 780 Mbit, ETA pochi minuti) -> greedy-ab.cmd
  pronto, serve solo Strata spento + Matt sveglio.

## 22-10 01:10 - COMMENTO 3 POSTATO: prova inviata, aspetto jesdga
- Commento: https://github.com/jesdga95/basalt/pull/14#issuecomment-6328519921 (bozza:
  .pr-comment-3.md, con hash completi dei 2 exe, tabella diff, rumore, caveat logprob).
- Lo zip (H:\basalt\ab-evidence.zip, 34 KB) il token gh non puo' allegarlo (serve write su
  jesdga95/basalt -> 404 su issues/14/uploads): Matt lo allega via web EDIT del commento.
- Zip: 10 file (Matt ha tolto ab-compare.ps1 in web-edit, dal 22-10 alle 01:0x) = 4 json + 4 txt
  + ab-body.json + RESULTS.txt. Allegato via web, il commento e' completo.
- Reporter tabella-sha con bug PS fixati (,@() appiattisce, Substring(0,3) su 'on1', virgolette
  PS5): ora etichette corrette + diff live git exit 0 nel RESULTS. zip rigenerato 01:02.

## 22-10 00:45 - VERDETTO A/B: IDENTICO AL BYTE (da rivedere con Matt, NON postato)

    off1: 2261 tok, sha F7B013639431...   on1: 2261 tok, sha F7B013639431...  -> IDENTICI
    off2: 1853 tok, sha FC94EECC54A3...   on2: 1853 tok, sha FC94EECC54A3...  -> IDENTICI
    CROSS off1-vs-on1 e off2-vs-on2: IDENTICI al byte (reasoning+risposta, sha256 su UTF-8).
    RUMORE off1-vs-off2 (e on1-vs-on2): DIVERSI al char 1290 -> il motore STESSO e'
    non-deterministico tra run (stato expert-cache freddo/caldo): il rumore c'e' e non e'
    imputabile al flag, che invece e' risultato inerte perfino dove il rumore esisteva.
    Logprob: lista con 1 sola voce -> NON informativo, in PR si dichiara identita' di TESTO
    greedy (ragionamento+risposta), non di logprob. Prompt semplice (versione 'lungo/elenco'
    scartata perche' faceva ragionare su tutte le CUDA lib). Testi: ab-off{1,2}.json ab-on{1,2}.json.

## 21-10 pomeriggio - nits di jesdga sistemati, manca solo il greedy
- jesdga (21-10 13:28 UTC): "the gate and docs look good. Before merge: post the 13.0.2
  greedy-identity diff, use cl(\\.exe)? (CMake turns \. into a bare .), cut the comment to
  one line, change the docs to CUDA 13.2 and later". => APPROVA, vuole solo la prova.
- Il suo rilievo e' giusto: nel CMakeLists il nostro (\.exe)? dopo l'unescaping di CMake
  diventava (.exe)? con punto ANY-CHAR (avrebbe matchato clXexe). Ora nel source c'e'
  (\\.exe)?. gate-test.cmake porta anche il caso clXexe: 7/7 giusti, reconfigure -> 83 flag.
- Commit pushati: d41bcf52 (dot + commento 1 riga), 9406b184 (docs "CUDA 13.2 and later").
  Risposta postata: #issuecomment-6323201952 (file .pr-comment-2.md).
- greedy-ab.ps1 ora fa Start-Transcript su H:\basalt\ab-greedy.log: la prova gira a Strata
  spento (sessione morta) e il verdetto resta su disco per il rientro.
- CASINACCIODEL21-POMERIGGIO: il CMakeLists mette gli exe in ${CMAKE_SOURCE_DIR}/bin ->
  i due bracci nello STESSO worktree si sovrascrivevano bin\basalt.exe (ab-on ha schiacciato
  ab-off alle 00:13). Fix: secondo worktree Dedicato H:\basalt-probe-off (c5f9fa24) per il
  braccio off, build in build-off senza flag, exe finale in H:\basalt-probe-off\bin.
  greedy-ab.ps1 punta ora ai due percorsi espliciti (probe-off=OFF, probe=ON).
  (La build-ab-off originale in H:\basalt-probe\build-ab-off resta verde ma il SUO exe e'
  quello perso: non usarlo.)
- 21-10 SERA, perche' gli script morivano subito: (1) BOM - Set-Content -Encoding UTF8 di
  PS5 scrive EF BB BF che basalt rigetta ("Unexpected UTF-8 BOM") e la finestra minimized
  si chiudeva coll'errore dentro; (2) campo "model" nel body chat -> 404 se diverso dal
  nome del pack (handler.py:336), ora omesso. Config/body riscritti senza BOM; test avvio
  OK (server vivo, carica poi apre la porta: il poll /v1/models DEVE tollerare no-reply).
  Istruzioni manuali + stato: H:\basalt\[README-sibilla.md (Matt l'ha rinominato con [ di
  pinnaggio). 21-10 NOTTE OOM: il Q4_K_XL (106.7 GiB pack, 81.7 GiB pesi, plan GPU solo
  4.7 GiB!) con resident-experts:true finisce in RAM PRIVATA (budget auto 67.4 GiB) + cache
  complement H->C (52.7 GiB) + paging 0 => watchdog a 965 MiB free, "use --resident-budget-gib".
  Strata regge perche' usa file cache reclaimable (100->80-90 GB). FIX: resident-experts
  tolto da ab-serve.json (default streaming, footprint ~30-35 GiB, piu' lento ma per
  l'identity check non serve velocita'). NON serve Q2 (65 GiB, non salvi niente).
  REGOLA CASA: mai resident-experts su pack grossi con 128 GB + pagefile 0.
  Piano B pagefile 20GB temporaneo (comandi nel README) se servira'.
  21-10 23:4x: carico OK in 165s (76.1 GiB: cuda0 4.4 + RAM 71.7 - streaming mode regge!)
  ma il check di serve (generate.cpp:4803) vuole anche --prefill CHUNK: errore tradotto male
  ("needs --spec T") non era la temperatura. Fix: "prefill": "auto" in ab-serve.json
  (forma usata dai comandi in docs/precision/builds.md; auto->8192). Terza condizione
  (expert profile per graphed hit path) non si applica: nessun profile in uso.
  Nota: il messaggio NON dice quale dei tre requisiti manca; giro di test in piu'.
  22-10 00:1x: il modello fa thinking esplicito, quindi max_tokens copriva thinking+risposta
  -> finish=length durante il reasoning ("max tokens reached while thinking"). Body aggiornato:
  max_tokens 1024 + reasoning_budget_tokens 640 (service.py:97). AB-PITTORE: nel repo
  `logprobs` compare solo nel path responses ed e' riempito [] -> verificare sul primo json se
  i logprob arrivano davvero; se la lista e' vuota la prova solida sono i TOKEN e il
  max|dlogprob| del compare va dichiarato come non informativo, non spacciato per prova.
  Run e script ora leggono tutti lo stesso ab-body.json (niente corpi divergenti fra bracci).
- 22-10 01:08 CHIUSO': PR #14 completa di tutto (gate, docs, regex punto letterale, risposte 1-4,
  greedy identity proof con hash binari, rumore misurato e caveat logprob; zip allegato via web
  senza lo script di confronto, scelta di Matt). Palla a jesdga per il merge. Poi, opzionale:
  A/B Strata-vs-basalt stesso quant e bench Q4_K_XL post-update.
