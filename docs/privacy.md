---
title: Informativa sulla privacy — FinancialManager
---

# Informativa sulla privacy

_Ultimo aggiornamento: 22 ottobre 2026_

FinancialManager è un'app personale per la gestione delle finanze. Questa pagina descrive quali dati tratta e come.

## Dati raccolti

- **Dati dell'account**: indirizzo email, nome e, se accedi con Google, l'identificativo del tuo account Google. Servono solo per autenticarti.
- **Dati finanziari che inserisci**: portafogli, transazioni, categorie, modelli, buoni pasto e immagini associate.
- **Dati tecnici**: log del server (per esempio indirizzo IP e orario delle richieste), usati solo per sicurezza e diagnostica.

## Come vengono usati

I dati servono esclusivamente a far funzionare l'app. Non vengono venduti, non vengono usati per pubblicità e non vengono condivisi con terzi, salvo quando usi tu stesso l'Analisi AI con un fornitore cloud, descritta qui sotto. L'Analisi AI sul dispositivo non coinvolge nessun fornitore.

## Dove sono conservati

I dati sono conservati sul server che ospita il backend dell'app. Il proprietario dell'istanza ne esegue periodicamente un **backup cifrato** sul proprio Google Drive. L'app accede a Google Drive solo con l'autorizzazione `drive.file`, quindi vede e gestisce esclusivamente i file di backup che ha creato lei, mai altri file presenti su Drive.

## Analisi AI (facoltativa)

L'Analisi AI è disattivata finché non la configuri tu. Se non ti interessa, puoi anche nasconderla del tutto da **Account → Preferenze → Funzioni AI**: spegnendola non viene cancellato nulla. Per usarla scegli un fornitore di modelli linguistici (per esempio Anthropic, OpenAI, Google o un servizio compatibile con OpenAI) e inserisci una tua chiave API. Prima della prima analisi l'app ti chiede un consenso esplicito, che puoi revocare in qualsiasi momento da **Account → Assistente AI → Privacy e consenso**.

**Cosa viene inviato al fornitore che hai scelto**, solo quando avvii un'analisi o fai una domanda:

- un riepilogo dei movimenti del periodo e dei portafogli che selezioni: totali, andamento mensile, ripartizione per categoria e per voce, trasferimenti tra portafogli, possibili spese ricorrenti;
- nome, tipo, scopo e saldo dei portafogli inclusi;
- solo se lo attivi, l'elenco dei singoli movimenti (al massimo 500); i titoli dei movimenti possono essere sostituiti da pseudonimi ("Voce 1", "Voce 2"…);
- solo se lo attivi, il contesto personale che hai scritto (per esempio obiettivi o composizione del nucleo familiare);
- le istruzioni e le domande che scrivi.

Prima dell'invio l'app ti mostra esattamente il testo che verrà inviato.

**Cosa non viene mai inviato**: email, nome e cognome, nome utente, identificativi del tuo account, immagini e allegati.

**La chiave API** è conservata sul server solo in forma cifrata (AES-256-GCM) e non viene mai mostrata di nuovo né inclusa negli export: l'app ne vede solo le ultime cifre.

**Il fornitore** tratta i dati secondo le sue condizioni e la sua informativa, legate al tuo account presso di lui: controlla per quanto tempo conserva le richieste e se le usa per addestrare i modelli. FinancialManager non ha alcun accordo con i fornitori e non riceve nulla da loro.

**Cosa resta nell'app**: ogni analisi viene salvata nella cronologia con il testo inviato, il report, le domande e le risposte, così puoi rileggerla. Puoi eliminare una singola analisi o tutta la cronologia in qualsiasi momento, e tutto viene eliminato insieme all'account. L'export dei dati include il contesto personale, mai le chiavi API.

## Analisi AI sul dispositivo (facoltativa, Android)

In alternativa a un fornitore cloud puoi far girare il modello AI **direttamente sul tuo telefono**. La scegli da **Account → Assistente AI → Fornitore e chiave API → Sul dispositivo**, e prima della prima analisi l'app ti chiede di accettare un'informativa dedicata, che puoi revocare dalla stessa schermata.

**Dove vengono elaborati i dati.** Il server prepara lo stesso riepilogo descritto sopra (con le stesse scelte su movimenti, pseudonimi e contesto personale) e lo passa all'app, che lo dà al modello installato sul telefono. Il testo viene scritto sul telefono, senza connessione al modello: **nessun fornitore AI esterno riceve i tuoi dati** e non serve nessuna chiave API.

**Cosa resta sul server.** Come per le analisi cloud, ogni analisi viene salvata nella cronologia con il testo dato al modello, il report, le domande e le risposte, così la ritrovi su ogni dispositivo. Vengono salvate anche alcune informazioni tecniche sull'esecuzione: il nome del modello e la sua quantizzazione, il motore (LiteRT-LM o llama.cpp), se ha usato GPU o CPU, la dimensione del contesto, i token e la durata. Nel tuo profilo AI resta anche il nome del modello attivo sul telefono. Eliminazione e cancellazione dell'account funzionano come per le analisi cloud.

**Il download dei modelli.** I modelli (da 2 a 4 GB circa) si scaricano da **Hugging Face** (huggingface.co), con link fissati a una versione precisa e verificati con un'impronta SHA-256. Hugging Face, e la rete di distribuzione che usa, vedono il tuo indirizzo IP e il file richiesto, come per qualsiasi download; non ricevono nessun dato finanziario. Puoi anche importare un modello da un file o da un indirizzo https a tua scelta: in quel caso il download va al sito che indichi.

**Il token Hugging Face** serve solo per i modelli riservati, se un giorno li userai. Resta cifrato nell'archivio sicuro del telefono (Android Keystore), non arriva mai al server dell'app e viene inviato soltanto a huggingface.co.

**Cosa resta sul telefono.** I modelli scaricati, le impostazioni di esecuzione e le velocità misurate sono salvati nella memoria privata dell'app, esclusi dal backup di Android, e restano sul telefono anche se cambi account. Se il telefono è offline quando finisce un'analisi, il report viene conservato sul telefono, legato al tuo account, finché il server non lo riceve: viene inviato al successivo accesso, quando riapri l'app o prima dell'analisi seguente, ed è eliminato comunque dopo 7 giorni. Per cancellare i modelli usa **Modelli sul dispositivo → Elimina**, oppure disinstalla l'app.

**Il modello può sbagliare.** I modelli che girano su un telefono sono piccoli e possono confondere i numeri: controllali prima di prendere decisioni. Ogni modello è distribuito con la sua licenza, che l'app ti mostra prima del download.

## Servizi di Google

L'accesso con Google e il backup su Google Drive usano le API di Google. L'uso e il trasferimento delle informazioni ricevute dalle API di Google rispettano le [Norme sui dati utente dei servizi API di Google](https://developers.google.com/terms/api-services-user-data-policy), inclusi i requisiti di uso limitato.

## Conservazione ed eliminazione

Puoi eliminare il tuo account dall'app: dopo un periodo di grazia di 30 giorni i dati personali vengono rimossi. I backup che contengono quei dati vengono eliminati automaticamente quando superano il periodo di conservazione.

Puoi revocare in qualsiasi momento l'accesso dell'app al tuo account Google da [myaccount.google.com/permissions](https://myaccount.google.com/permissions).

## Contatti

Per domande su questa informativa apri una [issue su GitHub](https://github.com/Dokjolly0/FinancialManager/issues).
