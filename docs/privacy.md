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

I dati servono esclusivamente a far funzionare l'app. Non vengono venduti, non vengono usati per pubblicità e non vengono condivisi con terzi, salvo il servizio di posta che consegna le email dell'account (descritto qui sotto) e quando usi tu stesso l'Analisi AI con un fornitore cloud. L'Analisi AI sul dispositivo non coinvolge nessun fornitore.

## Dove sono conservati

I dati sono conservati sul server che ospita il backend dell'app. Tra l'app e il server viaggiano solo su connessioni cifrate (HTTPS): l'app non accetta collegamenti in chiaro. Il proprietario dell'istanza ne esegue periodicamente un **backup cifrato** sul proprio Google Drive. L'app accede a Google Drive solo con l'autorizzazione `drive.file`, quindi vede e gestisce esclusivamente i file di backup che ha creato lei, mai altri file presenti su Drive.

## Dashboard web

FinancialManager si usa anche dal browser, su `financialmanager.alexviolatto.dev`, con gli stessi dati dell'app.

- **Sessione**: per restare collegato, il browser conserva un token di sessione (il token di rinnovo) nella propria memoria locale (`localStorage`); il token di accesso, di breve durata, resta solo nella memoria della pagina. Il token di rinnovo resta lì finché non esci dall'account (o non cancelli i dati del sito) ed è leggibile solo dalla dashboard: le regole di sicurezza della pagina impediscono di caricare script da altri siti, tranne quello di accesso di Google. Da Account → Sicurezza puoi vedere e chiudere le sessioni aperte, browser compresi. Su un computer condiviso esci sempre al termine. Oltre al token, il browser ricorda solo se hai ridotto la barra laterale.
- **Accesso con Google**: il pulsante "Continua con Google" è fornito da Google e carica uno script di Google, solo nella pagina di accesso e in Account → Account collegati; quando lo usi, Google tratta i dati dell'accesso secondo le proprie regole, come nell'app.
- **Caratteri e altre risorse**: i caratteri e tutti i file della pagina sono serviti dalla dashboard stessa; la pagina non contatta servizi di font o CDN di terzi. Le uniche richieste esterne sono lo script di accesso di Google (sopra) e le immagini delle categorie scelte da una ricerca esterna, che arrivano dal sito che le ospita.
- **Nessun cookie di profilazione** e nessuno strumento di statistiche o pubblicità.
- **Analisi AI**: nel browser sono disponibili solo le analisi e le domande di "Chiedi all'assistente" con un fornitore cloud e la tua chiave API, descritte qui sotto; l'analisi sul dispositivo esiste solo nell'app Android.
- I file che scarichi (export dei dati, report delle analisi) finiscono nella cartella download del tuo computer: da quel momento sono sotto il tuo controllo.

## Analisi AI (facoltativa)

L'Analisi AI è disattivata finché non la configuri tu. Se non ti interessa, puoi anche nasconderla del tutto da **Account → Preferenze → Funzioni AI**: spegnendola non viene cancellato nulla. Per usarla scegli un fornitore di modelli linguistici (per esempio Anthropic, OpenAI, Google o un servizio compatibile con OpenAI) e inserisci una tua chiave API. Prima della prima analisi l'app ti chiede un consenso esplicito, che puoi revocare in qualsiasi momento da **Account → Assistente AI → Privacy e consenso**.

**Cosa viene inviato al fornitore che hai scelto**, solo quando avvii un'analisi o fai una domanda:

- un riepilogo dei movimenti del periodo e dei portafogli che selezioni: totali, andamento mensile, ripartizione per categoria e per voce, trasferimenti tra portafogli, possibili spese ricorrenti, annuali o occasionali (individuate dal titolo e dai mesi in cui compaiono);
- nome, tipo, scopo e saldo dei portafogli inclusi;
- solo se lo attivi, l'elenco dei singoli movimenti (al massimo 500); i titoli dei movimenti possono essere sostituiti da pseudonimi ("Voce 1", "Voce 2"…);
- solo se lo attivi, il contesto personale che hai scritto (per esempio obiettivi o composizione del nucleo familiare);
- le istruzioni e le domande che scrivi.

**Chiedi all'assistente** (le domande libere, come "quando ho pagato l'assicurazione?") invia gli stessi dati di un'analisi, ma sempre con l'elenco dei movimenti di tutta la cronologia (al massimo 2000, i più recenti) e con i titoli veri, perché le risposte si basano proprio sui singoli movimenti. Se non entrano tutti, a ogni domanda si aggiungono i movimenti più vecchi che contengono le sue parole nel titolo o nella categoria, e restano salvati con la domanda nella cronologia. Con un fornitore cloud il modello può anche chiedere di cercare o sommare altri movimenti del tuo account (solo dei portafogli e del periodo della chat): ogni ricerca, con i dati che ha ricevuto, è salvata con la risposta e visibile in "Ricerche fatte". Per questo il consenso è stato aggiornato: se l'avevi già accettato, l'app te lo chiede di nuovo.

Prima dell'invio l'app ti mostra esattamente il testo che verrà inviato.

**Cosa non viene mai inviato**: email, nome e cognome, nome utente, identificativi del tuo account, immagini e allegati.

**La chiave API** è conservata sul server solo in forma cifrata (AES-256-GCM) e non viene mai mostrata di nuovo né inclusa negli export: l'app ne vede solo le ultime cifre.

**Il fornitore** tratta i dati secondo le sue condizioni e la sua informativa, legate al tuo account presso di lui: controlla per quanto tempo conserva le richieste e se le usa per addestrare i modelli. FinancialManager non ha alcun accordo con i fornitori e non riceve nulla da loro.

**Cosa resta nell'app**: ogni analisi viene salvata nella cronologia con il testo inviato, il report, le domande e le risposte, così puoi rileggerla. Puoi eliminare una singola analisi o tutta la cronologia in qualsiasi momento, e tutto viene eliminato insieme all'account. L'export dei dati in JSON include il contesto personale e tutta la cronologia delle analisi (dati inviati, report, domande e risposte), mai le chiavi API; le risposte non ancora inviate dal telefono non sono sul server e quindi non sono nell'export.

## Analisi AI sul dispositivo (facoltativa, Android)

In alternativa a un fornitore cloud puoi far girare il modello AI **direttamente sul tuo telefono**. La scegli da **Account → Assistente AI → Fornitore e chiave API → Sul dispositivo**, e prima della prima analisi l'app ti chiede di accettare un'informativa dedicata, che puoi revocare dalla stessa schermata.

**Dove vengono elaborati i dati.** Il server prepara lo stesso riepilogo descritto sopra (con le stesse scelte su movimenti, pseudonimi e contesto personale) e lo passa all'app, che lo dà al modello installato sul telefono. Il testo viene scritto sul telefono, senza connessione al modello: **nessun fornitore AI esterno riceve i tuoi dati** e non serve nessuna chiave API.

**Cosa resta sul server.** Come per le analisi cloud, ogni analisi viene salvata nella cronologia con il testo dato al modello, il report, le domande e le risposte, così la ritrovi su ogni dispositivo. Vengono salvate anche alcune informazioni tecniche sull'esecuzione: il nome del modello e la sua quantizzazione, il motore (LiteRT-LM o llama.cpp), se ha usato GPU o CPU, la dimensione del contesto, i token e la durata. Nel tuo profilo AI resta anche il nome del modello attivo sul telefono. Eliminazione e cancellazione dell'account funzionano come per le analisi cloud.

**Il download dei modelli.** I modelli (da 2 a 4 GB circa) si scaricano da **Hugging Face** (huggingface.co), con link fissati a una versione precisa e verificati con un'impronta SHA-256. Hugging Face, e la rete di distribuzione che usa, vedono il tuo indirizzo IP e il file richiesto, come per qualsiasi download; non ricevono nessun dato finanziario. Puoi anche importare un modello da un file o da un indirizzo https a tua scelta: in quel caso il download va al sito che indichi.

**Il token Hugging Face** serve solo per i modelli riservati, se un giorno li userai. Resta cifrato nell'archivio sicuro del telefono (Android Keystore), non arriva mai al server dell'app e viene inviato soltanto a huggingface.co.

**Cosa resta sul telefono.** I modelli scaricati, le impostazioni di esecuzione e le velocità misurate sono salvati nella memoria privata dell'app, esclusi dal backup di Android, e restano sul telefono anche se cambi account. Se il telefono è offline quando finisce un'analisi, il report (o la risposta a una domanda) viene conservato sul telefono, legato al tuo account, finché il server non lo riceve: viene inviato in automatico al successivo accesso con il tuo account, quando riapri l'app o prima dell'analisi seguente. Non scade e resta anche se esci dall'account; se il server lo rifiuta (per esempio perché nel frattempo hai eliminato l'analisi) resta comunque sul telefono. **Chiunque usi l'app su quel telefono può leggerlo** in **Cronologia → Risposte non inviate**; solo tu puoi reinviarlo o eliminarlo. Se condividi il telefono, eliminali quando non ti servono più. Per cancellare i modelli usa **Modelli sul dispositivo → Elimina**, oppure disinstalla l'app.

**Notifiche.** Download e analisi sul telefono possono continuare con l'app chiusa: in quel caso una notifica mostra l'avanzamento e un'altra avvisa quando hanno finito. Le notifiche riportano solo il titolo dell'analisi o il nome del modello, mai il contenuto del report. Il permesso per le notifiche è facoltativo: se lo neghi tutto funziona lo stesso, senza avvisi.

**Il modello può sbagliare.** I modelli che girano su un telefono sono piccoli e possono confondere i numeri: controllali prima di prendere decisioni. Ogni modello è distribuito con la sua licenza, che l'app ti mostra prima del download.

## Email

L'app ti scrive solo per due motivi: confermare il tuo indirizzo email e reimpostare la password quando lo chiedi tu. Nessuna newsletter, nessuna email pubblicitaria.

- Le email partono dal servizio di posta scelto dal proprietario dell'istanza (per esempio Gmail o Infomaniak), che riceve il tuo indirizzo e il testo del messaggio solo per consegnarlo.
- Ogni email contiene un link personale che si può usare una volta sola e scade (30 minuti per la password, 24 ore per la conferma). Sul server viene salvata solo un'impronta del link, mai il link stesso, e i log non ne contengono il testo.
- Se ricevi un'email che non hai chiesto, ignorala: senza il link non cambia nulla.
- Il link apre la pagina su `financialmanager.alexviolatto.dev` o, se l'app è installata sul telefono, l'app stessa.

## Servizi di Google

L'accesso con Google e il backup su Google Drive usano le API di Google. L'uso e il trasferimento delle informazioni ricevute dalle API di Google rispettano le [Norme sui dati utente dei servizi API di Google](https://developers.google.com/terms/api-services-user-data-policy), inclusi i requisiti di uso limitato.

## Conservazione ed eliminazione

Puoi eliminare il tuo account dall'app: dopo un periodo di grazia di 30 giorni i dati personali vengono rimossi. I backup che contengono quei dati vengono eliminati automaticamente quando superano il periodo di conservazione.

Puoi revocare in qualsiasi momento l'accesso dell'app al tuo account Google da [myaccount.google.com/permissions](https://myaccount.google.com/permissions).

## Contatti

Per domande su questa informativa apri una [issue su GitHub](https://github.com/Dokjolly0/FinancialManager/issues).
