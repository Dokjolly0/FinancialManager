---
title: Analisi AI sul dispositivo — risultati del prototipo
---

# Analisi AI sul dispositivo: risultati del prototipo (Fase 0)

_Misure del 21 ottobre 2026 su un Samsung Galaxy S26 Ultra._

Questo documento chiude la Fase 0 del piano "Analisi AI sul dispositivo". La
Fase 0 serviva a misurare i motori e i modelli candidati sul telefono di
riferimento prima di scrivere il codice di prodotto (Fasi 4–6). Le scelte qui
sotto valgono come specifica per quelle fasi.

L'app di misura è usa e getta e sta fuori dal repository
(`FinancialManager-ai-spike`, repository git locale). I JSON completi delle
due sessioni sono in `results/round1-s26ultra.json` e
`results/round2-s26ultra.json` di quel progetto.

## In breve

- **Motore principale: LiteRT-LM sulla GPU, sempre con attivazioni float32.**
  Con il float16 predefinito la GPU dell'S26 scrive cifre sbagliate
  ("8200.00" diventa "82000.00") nei prompt da qualche migliaio di token in
  su. Con float32 nessun importo sbagliato in nessun report. Un check-up
  standard con Gemma 4 E2B richiede 6 s di attesa e 38 s in tutto.
- **Secondo motore: llama.cpp solo su CPU**, per chi vuole un GGUF qualsiasi.
  Numeri corretti, ma un check-up richiede 2–3 minuti. La GPU di llama.cpp
  (Vulkan) chiude l'app su Adreno: va esclusa.
- **Un solo pacchetto Flutter per entrambi i motori: `flutter_edge_ai`**
  (prima `flutter_gemma`) con i connettori `flutter_edge_ai_litertlm` e
  `flutter_edge_ai_llama`. `llama_flutter_android` è scartato.
- **Lo stimatore di token del backend sottostima di 1,56–1,75 volte.** Il
  budget del profilo compatto va calcolato con un `token_factor` per
  modello.
- **Release:** R8 rompe l'inizializzazione (metodi chiamati solo via JNI):
  servono regole `-keep`.

## Dispositivo e versioni

| | |
|---|---|
| Telefono | Samsung SM-S948B (Galaxy S26 Ultra), 12 GB, Android 17 (SDK 37) |
| SoC | Qualcomm SM8850 |
| RAM vista da Android | 11,6 GB (`totalMem`); `largeMemoryClass` 512 MB |
| `flutter_edge_ai` | 2.5.0 |
| `flutter_edge_ai_litertlm` | 1.16.0 |
| `flutter_edge_ai_llama` | 0.0.2 (llamadart 0.15.0) |
| minSdk | 30 (richiesto da LiteRT-LM) |
| ABI | solo `arm64-v8a` |

## Metodo

Prompt reali, generati dal vero `prompt.Build` del backend su dati finti con
seed fisso: 382 movimenti in 12 mesi e tre anomalie nascoste (palestra
addebitata due volte, un acquisto MediaWorld da 1.899,00, Netflix passato da
13,99 a 17,99).

| Prompt | Contenuto | Token stimati | Token reali (Gemma 4) |
|---|---|---|---|
| `copy_amounts` (solo giro 2) | ricopiare 20 importi | — | 335 |
| `checkup_compact` | check-up, profilo compatto, 30 movimenti | 1.876 | 3.009 |
| `checkup_standard` | check-up, profilo standard, 40 movimenti | 2.426 | 3.856 |
| `anomalies_long` | anomalie, profilo standard, 320 movimenti | 7.891 | 12.536 |

Per ogni combinazione l'app misura:
- caricamento;
- tempo al primo token, che contiene la lettura del prompt;
- velocità di lettura (token di input / tempo al primo token) e di
  scrittura;
- memoria (RSS del processo e memoria libera del sistema);
- stato termico e batteria.

Su ogni risposta esegue controlli automatici: titoli richiesti, importi
presenti nella risposta ma assenti dai dati, menzione delle anomalie.

Output massimo 1.024 token, temperatura 0,2, `topK` 40. Il telefono era in
carica, su Wi-Fi, con l'app in primo piano. Prima di ogni prova l'app
aspettava fino a 3 minuti che lo stato termico scendesse a "leggero".

## Giro 1: tutti i candidati (4 h 25 min)

| Modello · motore · backend | Contesto | Lettura (t/s) | Scrittura (t/s) | Check-up standard: attesa / totale | Importi sbagliati | Memoria | Esito |
|---|---|---|---|---|---|---|---|
| Gemma 4 E2B · LiteRT · GPU (f16) | 16k | 920–1.377 | 29–35 | 4 s / 37 s | 3–5 per report | RSS 1,1 GB | **cifre sbagliate** |
| Gemma 4 E2B · LiteRT · CPU | 16k | 104 | 12 | 37 s / 2 min | 0 | 6,5 GB, 0,8 GB liberi | chiusa al 2° prompt |
| Gemma 4 E4B · LiteRT · GPU (f16) | 16k | 576–618 | 12–16 | 7 s / 46 s | 5 per report | RSS 1,3 GB, 0,6 GB liberi | **cifre sbagliate** |
| Gemma 4 E4B · LiteRT · CPU | 16k | — | — | — | — | — | chiusa al 1° prompt |
| Qwen3 4B 2507 · LiteRT · GPU | 16k | — | — | — | — | — | errore "Failed to start streaming (code: 13)" |
| Qwen3.5 4B · LiteRT · GPU | 16k | — | — | — | — | — | caricamento 74 s, poi chiusa |
| Qwen3 4B 2507 · GGUF Q4_K_M · CPU | 16k | 17–20 | 4,6–5,4 | 3,5 min / 6,6 min | 0 | 5,3–5,7 GB | lento; chiusa sul prompt lungo |
| Qwen3 4B 2507 · GGUF Q4_K_M · GPU (Vulkan) | 16k | — | — | — | — | — | chiusa al 1° prompt |
| Qwen3 4B 2507 · GGUF Q4_0 · CPU | 16k | 20 | 4,8–5,4 | 3,4 min / 6 min | 0–1 | 6,4 GB | prompt lungo oltre 15 min |
| Qwen3 4B 2507 · GGUF Q8_0 · CPU | 16k | — | — | — | — | — | chiusa al 1° prompt |
| Qwen3.5 4B · GGUF Q4_K_M · CPU | 16k | 43–53 (31 a 12k) | 9,7–10,8 | 72 s / 2,3 min | 0 | 4,5–6,5 GB | ok |
| Gemma 4 E2B · GGUF Q4_K_M · CPU | 16k | 47–51 (21 a 12k) | 12,3–12,7 | 75 s / 2,6 min | 0 | 4,1 GB | ok |
| Gemma 4 E2B · GGUF Q4_K_M · GPU (Vulkan) | 16k | — | — | — | — | — | chiusa al 1° prompt |

Note:
- **Prompt lungo su llama.cpp CPU:** 7 minuti di attesa con Qwen3.5 e 10
  minuti con Gemma 4 E2B.
- **Qwen3 4B 2507 in GGUF** è 2,5 volte più lento di Qwen3.5 4B a pari
  quantizzazione. La causa non è stata indagata: il modello è escluso.
- **Stop:** funziona su entrambi i motori, in 30 ms con LiteRT e 190 ms con
  llama.cpp. Dopo lo Stop il modello risponde a una nuova richiesta in
  0,2–0,6 s.
- **Calore:** in 3 esecuzioni di fila il rallentamento è al massimo del 12%.
  Lo stato termico massimo è stato 2 ("moderato") e la batteria è arrivata a
  42 °C in carica.

## Giro 2: perché la GPU sbaglia le cifre (28 min)

Solo Gemma 4 LiteRT, in varianti di caricamento. Il prompt `copy_amounts`
chiede di ricopiare 20 importi.

| Variante | `copy_amounts` | Importi sbagliati: standard / compatto / lungo | Lettura standard (t/s) | Lettura lungo (t/s) | Scrittura (t/s) | Standard: attesa / totale |
|---|---|---|---|---|---|---|
| E2B GPU (f16, predefinita) | 20/20 | 4 / 4 / 1 | 957 | 1.259 | 31–35 | 4,0 s / 25 s |
| E2B GPU, scelta deterministica (`topK` 1) | 20/20 | 6 / 6 / 1 | 1.456 | 1.314 | 29–35 | 2,6 s / 21 s |
| E2B GPU senza MTP | 20/20 | 4 / 4 / 1 | 1.457 | 1.154 | 28–35 | 2,6 s / 24 s |
| **E2B GPU float32** | 20/20 | **0 / 0 / 0** | 629 | 375 | 27–33 | 6,1 s / 38 s |
| E2B GPU float32 senza MTP | 20/20 | 0 / 0 / 0 | 625 | 359 | 28–32 | 6,2 s / 38 s |
| E2B CPU, contesto 8k | 20/20 | 0 / 0 / — | 198 | non entra | 23 | 19 s / 63 s |
| E2B CPU, contesto 4k | 20/20 | — / 0 / — | 280 (compatto) | non entra | 26 | 11 s / 47 s (compatto) |
| **E4B GPU float32** | 20/20 | **0 / 0 / 0** | 358 | 212 | 11,5–14,4 | 11 s / 63 s |

Conclusioni:
- **Il difetto viene dal float16 sulla GPU.** Non viene dal
  campionamento: con la scelta deterministica sbaglia lo stesso. Non viene
  nemmeno dalla decodifica speculativa (MTP): l'output è identico con e senza.
  Su prompt corti (335 token) il float16 copia giusto; l'errore compare dai
  ~3.000 token in su. Si tratta del problema noto LiteRT-LM#2814 / #3012, che
  `flutter_edge_ai` documenta su `activationDataType`.
- **Il float32 costa il 35–55% della velocità di lettura e quasi nulla in
  scrittura.** Resta 3–10 volte più veloce di llama.cpp su CPU.
- **Su CPU il contesto è ciò che conta per LiteRT.** A 16k servivano 6,5 GB
  e Android chiudeva l'app; a 8k servono 5,2 GB e a 4k 3,1 GB, senza
  chiusure. A 8k la CPU di LiteRT è anche 2 volte più veloce che a 16k sotto
  pressione di memoria, e 4 volte più veloce di llama.cpp in lettura.
- **Con il float32 un modello GPU che non si riesce a creare ripiega sulla
  CPU senza errore.** Dopo il caricamento bisogna controllare
  `activeBackend`.
- **Memoria della GPU:** non compare nell'RSS del processo (1,0–1,3 GB), ma
  riduce la memoria libera del sistema. Con E4B la memoria libera è scesa a
  0,8 GB su 11,6. Per la stima "ci sta / al limite" va usata la memoria
  disponibile, non l'RSS.
- Nel giro 2 nessuna chiusura dell'app.

## Qualità delle risposte

- **Con i numeri giusti, tutti i modelli ammessi rispettano i titoli
  richiesti, in ordine, e non inventano importi**, nemmeno nei profili
  compatti.
- **L'italiano migliore è quello di Qwen3.5 4B.** Gemma 4 E4B viene subito
  dopo; Gemma 4 E2B è corretto ma più generico.
- **Anomalie:** l'acquisto MediaWorld e l'aumento di Netflix vengono trovati
  in circa metà dei report. **Il doppio addebito della palestra non l'ha
  trovato nessun modello.** I modelli da 2–4B non confrontano bene righe
  lontane tra loro. Se servirà, la soluzione è nel backend: i candidati
  duplicati si calcolano in modo deterministico e si mettono nel blocco dati.
  Non fa parte di questo lavoro.

## Pacchetti e build

- **`flutter_edge_ai` 2.5.0 + `flutter_edge_ai_litertlm` 1.16.0 +
  `flutter_edge_ai_llama` 0.0.2**, inizializzati con
  `LiteRtLmEngine(backendFallback: false)` e `LlamaEngineProvider()`. Un'API
  unica gestisce entrambi i motori:
  - `installModel(...).fromFile(path)`: registra il file senza copiarlo;
  - `getActiveModel(maxTokens:, preferredBackend:, activationDataType:)`;
  - sessione con `sizeInTokens` (conteggio esatto dei token su entrambi i
    motori, 2–75 ms);
  - `getResponseAsync()` in streaming e `stopGeneration()`.
- **`backendFallback: false` è obbligatorio:** con il ripiego predefinito
  una GPU che non funziona passa in silenzio alla CPU.
- **llama.cpp emette il testo a blocchi**, cioè pochi eventi di stream per
  molti token. I token generati vanno contati con `sizeInTokens`, non dagli
  eventi. `SessionMetrics.tokensPerSecond` di llama.cpp è inaffidabile (a
  volte NaN), quindi le velocità si misurano nell'app.
- **llamadart** richiede nel `pubspec.yaml` dell'app:
  ```yaml
  hooks:
    user_defines:
      llamadart:
        llamadart_native_runtimes: [llama_cpp]
  ```
- **Dimensione:** l'APK di release arm64 pesa 105 MB con R8 e 116 MB senza.
  Le librerie native occupano circa 107 MB non compresse: `libggml-vulkan.so`
  26 MB, `libLiteRtLm.so` 24,6 MB, più le varianti CPU di llama.cpp fino ad
  armv9.2. Vulkan va escluso dal pacchetto, visto che sulla GPU di
  llama.cpp l'app si chiude.
- **Nessun conflitto di `libc++_shared.so`** tra i due motori.
- **Manifest:** il plugin LiteRT unisce già le voci `uses-native-library`
  (`libOpenCL.so`, `libvndksupport.so`, `libcdsprpc.so`); non serve
  aggiungerle.
- **R8:** in release `FlutterEdgeAi.initialize` fallisce con
  `NoSuchMethodError` su
  `io.flutter.plugins.sharedpreferences.SharedPreferencesApiRegistrar.getAll`.
  Il metodo viene chiamato solo via JNI e R8 lo elimina. Servono regole
  `-keep` per le classi dei plugin chiamate via JNI. La release va provata
  sul telefono, perché le build di debug non mostrano il problema.
- **NPU:** non testata. Non esistono file `.litertlm` compilati per l'SM8850.

## Download da Hugging Face

- **Revisioni:** i repository `litert-community` di Gemma 4 e Qwen e quelli
  `unsloth` non sono riservati e hanno licenza Apache-2.0. Non serve un
  token.
- **Redirect:** `resolve/<revisione>` risponde 302 verso
  `us.aws.cdn.hf.co`. La prima risposta porta `X-Linked-ETag`, che è lo
  sha256 del file, e `X-Linked-Size`. L'`ETag` del CDN è invece l'hash xet,
  non lo sha256.
- **Ripresa:** per riprendere bisogna seguire i redirect a mano, così
  l'intestazione `Range` arriva al CDN. La ripresa risponde 206 (verificato
  con un download interrotto e ripreso).
- **Velocità misurata:** 64–73 Mbit/s in Wi-Fi. La verifica sha256 in un
  isolate, nella build di release, va a 135–160 MB/s: 18 s per 2,6 GB.

## Decisioni per le Fasi 4–6

### Catalogo iniziale

| id | Modello | Motore · backend | File | Revisione | sha256 | Byte | Ruolo |
|---|---|---|---|---|---|---|---|
| `gemma4-e2b-litert` | Gemma 4 E2B | LiteRT · GPU f32 | `gemma-4-E2B-it.litertlm` (`litert-community/gemma-4-E2B-it-litert-lm`) | `41c5569623a7c189d6eec3e5225260c58cedbce7` | `181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c` | 2.588.147.712 | **consigliato** |
| `gemma4-e4b-litert` | Gemma 4 E4B | LiteRT · GPU f32 | `gemma-4-E4B-it.litertlm` (`litert-community/gemma-4-E4B-it-litert-lm`) | `e6a3892a8c22cf87ff99583996149cf3cb32452b` | `0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0` | 3.659.530.240 | qualità |
| `qwen35-4b-q4km-gguf` | Qwen3.5 4B Q4_K_M | llama.cpp · CPU | `Qwen3.5-4B-Q4_K_M.gguf` (`unsloth/Qwen3.5-4B-GGUF`) | `e87f176479d0855a907a41277aca2f8ee7a09523` | `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4` | 2.740.937.888 | italiano migliore, lento |
| `gemma4-e2b-q4km-gguf` | Gemma 4 E2B Q4_K_M | llama.cpp · CPU | `gemma-4-E2B-it-Q4_K_M.gguf` (`unsloth/gemma-4-E2B-it-GGUF`) | `0314792d7f1f7e229411f620751375812bb9faf2` | `740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8` | 3.106.738.272 | GGUF più leggero in memoria |

Esclusi:
- Qwen3 4B 2507 e Qwen3.5 4B in formato LiteRT, che non partono con questa
  versione;
- Qwen3 4B 2507 in GGUF, per la velocità;
- le quantizzazioni Q8_0, per la memoria.

L'import da file resta il modo per provare altri GGUF.

### Impostazioni di default per modello

| id | Backend | Attivazioni | Contesto default / max | Output max | `token_factor` | Lettura / scrittura indicative (t/s) |
|---|---|---|---|---|---|---|
| `gemma4-e2b-litert` | GPU, ripiego CPU | float32 | 16k / 16k (8k su CPU) | 1.024 | 1,59 | 630–860 (375 a 12k) / 30; CPU 200–250 / 23 |
| `gemma4-e4b-litert` | GPU | float32 | 16k / 16k | 1.024 | 1,59 | 360 (210 a 12k) / 14 |
| `qwen35-4b-q4km-gguf` | CPU | — | 8k / 16k | 1.024 | 1,57 | 45–53 (31 a 12k) / 10 |
| `gemma4-e2b-q4km-gguf` | CPU | — | 8k / 16k | 1.024 | 1,59 | 47–51 (21 a 12k) / 12 |

- **Su GPU il float16 non va mai usato:** `activationDataType` non si
  espone nelle impostazioni. Dopo ogni caricamento si controlla che
  `activeBackend` sia quello richiesto; se non lo è, l'esecuzione viene
  segnalata come avvenuta su CPU.
- **Su CPU con LiteRT il contesto massimo è 8k** (a 16k l'app viene chiusa
  per memoria).
- **La GPU di llama.cpp non viene offerta.**
- **MTP:** si lascia al default del modello.
- **Temperatura:** 0,2.

### Token e budget compatto

- **Correzione della stima:** il backend stima 3,5 caratteri per token, ma
  sull'italiano dei prompt reali i tokenizer contano in media 2,1–2,3
  caratteri per token. Il fattore va da 1,56 (Qwen3.5) a 1,75 (Qwen3);
  1,59 per Gemma 4. Il catalogo porta un `token_factor` per modello e
  l'anteprima usa il conteggio esatto del motore (`sizeInTokens`), quando il
  modello è caricato.
- **Budget compatto di default:** `budget_tokens = (contesto − output − 256)
  / token_factor`, come da piano. Il profilo compatto è il default sui
  motori CPU: un check-up compatto ha circa 3.000 token reali, cioè 60 s di
  lettura con llama.cpp. Sulla GPU in float32 anche il prompt lungo (12.500
  token) parte in 33 s, quindi lì il default resta il profilo standard.
- **Tempo stimato nell'anteprima:** usa le velocità della tabella sopra
  finché non esiste una misura locale. La velocità di lettura cala con la
  lunghezza del prompt: a 12k è circa il 60% di quella a 3k.

### Modifiche al piano

- **Fase 5:**
  - un solo pacchetto (`flutter_edge_ai` con i due connettori) al posto di
    `flutter_gemma` + un pacchetto llama.cpp separato;
  - `activationDataType: float32` fisso su GPU;
  - controllo di `activeBackend` dopo il caricamento;
  - niente Vulkan;
  - regole R8 `-keep` per le classi chiamate via JNI;
  - `minSdk 30`.
- **Fase 4:** il downloader segue i redirect a mano per mantenere `Range`, e
  usa `X-Linked-ETag` come conferma dello sha256 del catalogo.
- **Fase 6:**
  - backend "GPU" e "CPU" solo per LiteRT;
  - thread e layer su GPU non si espongono, perché il connettore llama non
    li rende configurabili;
  - avviso RAM basato sulla memoria disponibile.
