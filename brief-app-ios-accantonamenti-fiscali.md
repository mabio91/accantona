# Accantona - Brief di Progetto App iOS

## Nome

Nome definitivo: **Accantona**

Sottotitolo consigliato: **Fatture, tasse e contributi senza Excel**

Alternative secondarie, solo se servono per marketing o App Store:

- Accantona - Cassa tasse
- Accantona - Fatture e tasse
- Accantona - Cassa fiscale

Il nome deve comunicare una promessa semplice: quando incassi, sai subito quanto mettere da parte.

## Obiettivo

Creare un'app iOS personale per gestire fatture, incassi, accantonamenti fiscali, versamenti F24 e previsioni di cassa fiscale per un libero professionista in regime forfettario.

L'app deve sostituire un file Excel complesso e poco leggibile, mantenendo pero la stessa utilita pratica: sapere quanto accantonare per ogni incasso, se il conto dedicato alle tasse e sufficiente per saldo e acconti, e quanto manca alle prossime scadenze.

Accantona non deve sembrare un gestionale grigio o una copia mobile di un foglio di calcolo. Deve essere un'app personale, chiara, bella da aprire e capace di trasformare numeri fiscali ansiogeni in decisioni semplici.

## Posizionamento

Accantona e una cassa fiscale personale per freelance e professionisti in regime forfettario.

Non e un software di fatturazione completo, non sostituisce il commercialista e non deve diventare un ERP. Il suo valore e aiutare l'utente a capire:

- cosa e davvero spendibile;
- cosa va messo da parte;
- cosa e gia coperto;
- cosa rischia di non essere coperto;
- quali incassi futuri servono per restare tranquilli.

## Personalita del prodotto

Accantona deve essere:

- preciso, perche tratta soldi e scadenze;
- rassicurante, perche riduce ansia fiscale;
- elegante, perche deve invitare all'uso frequente;
- concreto, perche ogni schermata deve portare a una decisione;
- non paternalistico, perche l'utente deve sentirsi in controllo.

Microcopy consigliato:

- "Da accantonare"
- "Gia coperto"
- "Margine disponibile"
- "Rischio novembre"
- "Incassi necessari"
- "Dato stimato"
- "Dato da F24"
- "Dato da dichiarazione"

Evitare frasi generiche tipo "gestisci le tue finanze" o "ottimizza il tuo business".

## Contesto fiscale attuale

Profilo di riferimento iniziale:

- Regime fiscale: forfettario.
- Imposta sostitutiva: 15% dal periodo d'imposta 2025.
- Aliquota precedente: 5% nei primi anni di attivita.
- Coefficiente di redditivita usato nello storico: 78%.
- Attivita storica rilevata da dichiarazioni: codice 702209.
- Previdenza: INPS Gestione Separata liberi professionisti.
- Aliquota INPS usata per stima 2025/2026: 26,07%.
- Accantonamento teorico corrente: `incasso * 78% * (15% + 26,07%) = incasso * 32,0346%`.
- Accantonamento prudenziale consigliato: `33,0346%` dell'incasso, includendo 1% extra di margine.

Nota: aliquote e regole devono essere configurabili dall'utente, non hardcoded.

## Problema da risolvere

Nel file Excel attuale esistono diversi limiti:

- formule fiscali sparse e difficili da verificare;
- percentuali scritte manualmente dentro le formule;
- storico, previsioni e versamenti reali mescolati nello stesso foglio;
- difficolta nel capire se un accantonamento e stato fatto davvero;
- difficolta nel simulare saldo, primo acconto e secondo acconto;
- rischio di confondere anno fattura, anno incasso e anno d'imposta;
- assenza di notifiche e controlli automatici.

L'app deve separare chiaramente:

- fatture emesse;
- fatture incassate;
- accantonamenti dovuti;
- accantonamenti effettivamente versati sul conto tasse;
- pagamenti F24 effettivi;
- stime future.

## Principi di prodotto

1. L'app deve rispondere prima di tutto a una domanda: "Quanti soldi posso considerare davvero disponibili?"
2. Ogni incasso deve generare automaticamente una quota da accantonare.
3. Ogni scadenza fiscale deve mostrare copertura, deficit o avanzo previsto.
4. I calcoli fiscali devono essere trasparenti e modificabili.
5. L'utente deve poter distinguere dati certi da stime.
6. L'app deve poter ricevere dati storici tramite migrazione una tantum o CSV standard, ma non deve provare a interpretare qualunque Excel personalizzato.

## Direzione visuale

Accantona deve essere graficamente accattivante, ma non decorativa. La UI deve sembrare una cassa personale moderna: numeri grandi quando servono, gerarchie chiare, superfici pulite, movimento leggero e colori usati per comunicare stato.

### Liquid Glass iOS 26

Accantona deve adottare la direzione visuale **Liquid Glass di iOS 26+** dove aggiunge valore: superfici principali, controlli flottanti, azioni rapide, badge di stato e pannelli decisionali.

Obiettivo: usare Liquid Glass per dare profondita e qualita percepita senza compromettere leggibilita, precisione contabile o accessibilita.

Linee guida:

- usare API native iOS 26+ come `glassEffect`, `GlassEffectContainer` e button style glass;
- usare `GlassEffectContainer` quando piu elementi glass convivono nella stessa area;
- applicare `glassEffect` dopo layout e modifier visuali;
- usare effetti interattivi solo su elementi davvero tappabili;
- mantenere forme coerenti tra card, chip, pulsanti e pannelli;
- prevedere fallback per iOS precedenti con materiali SwiftUI, per esempio `.ultraThinMaterial`;
- evitare blur custom e layer sovrapposti difficili da mantenere.

Elementi candidati a Liquid Glass:

- header dashboard con saldo/margine;
- card prossima scadenza;
- barra azioni rapide;
- pill di stato: coperto, margine basso, deficit, stimato, certo;
- pannello simulatore;
- conferma "fattura incassata";
- bottom sheet per accantonamento.

Elementi da mantenere piu sobri:

- liste lunghe di fatture;
- tabelle di F24;
- schermate parametri fiscali;
- contenuti con molti numeri piccoli.

Esempio tecnico:

```swift
if #available(iOS 26, *) {
    DeadlineCard(...)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
} else {
    DeadlineCard(...)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
}
```

La UI non deve diventare una demo di effetti: Liquid Glass deve servire a rendere Accantona piu piacevole e leggibile, non piu rumorosa.

### Mood

- App finanziaria personale premium.
- Calma, ordinata, con dettagli visivi curati.
- Non corporate, non bancaria fredda, non foglio Excel.
- Deve dare la sensazione di una cabina di controllo personale.

### Palette consigliata

Palette principale:

- Fondo principale: avorio molto chiaro o grigio caldo, non bianco puro.
- Testo primario: carbone caldo.
- Accento positivo: verde salvia/menta scuro.
- Accento attenzione: giallo ambra sobrio.
- Accento rischio: rosso corallo controllato.
- Accento informativo: blu petrolio o azzurro profondo.

Evitare:

- palette tutta blu aziendale;
- verde fluorescente da fintech aggressiva;
- gradienti viola/blu generici;
- dashboard piena di card tutte uguali;
- tabelle dense come primo impatto.

### Linguaggio grafico

- Usare card solo per oggetti ripetuti o blocchi decisionali: prossima scadenza, fattura, movimento, scenario.
- La dashboard deve avere una testata forte con il numero piu importante: "Disponibile davvero" o "Margine tasse".
- Usare grafici semplici: barre di copertura, timeline scadenze, anelli di progresso solo se leggibili.
- Usare icone SF Symbols o Lucide-style coerenti: ricevuta, calendario, salvadanaio, freccia verso conto, documento, alert.
- Arrotondamenti moderati, non giocattolosi.
- Animazioni leggere quando una fattura viene marcata come incassata e genera l'accantonamento.

### Componenti visuali distintivi

#### Indicatore di copertura

Un elemento centrale della dashboard:

```text
Prossima scadenza: 30 giugno 2026
Da pagare stimato: 7.399 euro
Saldo conto tasse: 7.534 euro
Margine: +135 euro
Stato: Coperto con margine basso
```

Visualmente puo essere una barra orizzontale:

- parte piena = saldo disponibile;
- marker = importo richiesto;
- colore = stato;
- testo sotto = margine o deficit.

#### Disponibile davvero

Numero importante:

```text
Incasso fattura: 3.333,34 euro
Da accantonare: 1.101,15 euro
Disponibile davvero: 2.232,19 euro
```

Questo concetto deve essere una firma dell'app.

#### Timeline fiscale

Vista semestrale con:

- giugno: saldo + primo acconto;
- novembre: secondo acconto;
- eventuali bolli;
- incassi futuri previsti;
- copertura prevista a ogni data.

### Dark mode

Prevedere dark mode, ma non come semplice inversione colori. In dark mode:

- fondo carbone morbido;
- card leggermente piu chiare;
- accenti piu saturi ma non neon;
- grafici e soglie molto leggibili.

## Funzioni principali

### 1. Dashboard

Schermata iniziale con:

- saldo conto tasse;
- accantonamento dovuto non ancora trasferito;
- prossima scadenza fiscale;
- importo stimato da pagare;
- copertura prevista;
- eventuale deficit;
- incassi attesi prima della scadenza;
- totale fatture incassate nell'anno;
- totale tasse/contributi stimati dell'anno.

Layout consigliato:

1. Header con saluto breve e stato fiscale sintetico.
2. Blocco grande "Disponibile davvero" oppure "Margine conto tasse".
3. Card prossima scadenza con barra di copertura.
4. Righe rapide: da accantonare, gia accantonato, F24 pagati, incassi attesi.
5. Mini timeline giugno/novembre.
6. Azioni rapide: nuova fattura, segna incasso, registra F24, aggiorna saldo.

Stati possibili:

- Coperto: saldo conto tasse sufficiente.
- Coperto con margine basso: saldo sufficiente ma margine sotto soglia configurabile.
- Da recuperare: saldo insufficiente rispetto alla prossima scadenza.
- Dipende da incassi futuri: copertura possibile solo se certe fatture vengono incassate prima della scadenza.

Dettaglio visuale:

- Lo stato deve essere immediatamente visibile senza leggere tutti i numeri.
- Il colore non deve essere l'unico indicatore: usare anche testo e icona.
- Se il margine e basso, evitare messaggi allarmistici: "Coperto, ma con poco margine".

### 2. Fatture

Ogni fattura deve avere:

- numero fattura;
- cliente;
- contratto/progetto;
- descrizione;
- data emissione;
- data prevista incasso;
- data effettiva incasso;
- importo imponibile/incassato;
- bollo eventuale;
- stato: bozza, emessa, incassata, annullata;
- anno competenza gestionale;
- anno fiscale di incasso;
- note;
- allegato PDF opzionale.

Quando una fattura viene marcata come incassata, l'app deve calcolare:

- quota teorica da accantonare;
- quota prudenziale da accantonare;
- quota gia accantonata;
- quota mancante;
- netto disponibile dopo accantonamento.

Vista elenco:

- sezioni per stato: da incassare, incassate, archiviate;
- filtro per cliente, anno, stato accantonamento;
- chip visivi: "accantonata", "parziale", "da accantonare";
- importo fattura e quota da accantonare sempre visibili.

Dettaglio fattura:

- importo fattura grande in alto;
- stato pagamento;
- box "quando incassi";
- box "cosa accantonare";
- box "impatto sulla prossima scadenza";
- allegato PDF, se presente.

Interazione chiave:

Quando l'utente tocca "Segna come incassata", l'app deve proporre subito:

```text
Incassati 3.333,34 euro
Accantona 1.101,15 euro
Disponibile davvero 2.232,19 euro
```

Azioni:

- "Segna accantonato"
- "Accantono piu tardi"
- "Accantono solo una parte"

### 3. Accantonamenti

L'app deve tenere un registro separato degli accantonamenti.

Campi:

- fattura collegata, se presente;
- data incasso;
- importo incassato;
- percentuale applicata;
- importo da accantonare;
- importo effettivamente accantonato;
- data trasferimento su conto tasse;
- stato: da accantonare, accantonato parzialmente, accantonato, saltato, recuperato;
- note.

Funzioni utili:

- recupero accantonamenti saltati;
- piano di recupero automatico;
- simulazione: "se salto questi accantonamenti, resto coperto?";
- ordinamento per priorita in base alle scadenze.

Vista consigliata:

- lista cronologica degli accantonamenti;
- filtro "mancanti";
- filtro "saltati";
- totale da recuperare;
- suggerimento: "Con i prossimi X euro di incassi, torni coperto".

Questa schermata deve servire soprattutto a recuperare disciplina quando uno o piu accantonamenti sono stati saltati.

### 4. Conto tasse

L'app non deve collegarsi per forza alla banca nella MVP. Basta un saldo manuale.

Campi:

- saldo conto tasse manuale;
- data aggiornamento saldo;
- movimenti manuali: accantonamento, F24, rettifica, interessi, altro;
- saldo atteso dopo movimenti futuri.

Funzioni:

- confronto saldo manuale vs saldo teorico;
- avviso se saldo manuale e inferiore al saldo teorico;
- storico dei movimenti;
- esportazione CSV.

Vista consigliata:

- saldo manuale grande;
- data ultimo aggiornamento;
- saldo teorico atteso;
- differenza tra saldo manuale e saldo teorico;
- pulsante "Aggiorna saldo";
- movimenti recenti.

La schermata deve distinguere bene:

- soldi effettivamente presenti sul conto;
- soldi che teoricamente avrebbero dovuto essere accantonati;
- soldi gia destinati a prossime scadenze.

### 5. Versamenti F24

Ogni F24 deve registrare:

- data pagamento;
- anno imposta;
- tipo: saldo, primo acconto, secondo acconto, bollo, altro;
- sezione: Erario, INPS, altri enti;
- codice tributo/causale;
- importo a debito;
- importo a credito compensato;
- importo netto pagato;
- documento allegato PDF;
- note.

Codici/causali ricorrenti da supportare:

- 1790: imposta sostitutiva regime forfettario, saldo.
- 1791: imposta sostitutiva regime forfettario, primo acconto.
- 1792: imposta sostitutiva regime forfettario, secondo acconto o credito/saldo secondo contesto F24.
- 7005/PXX: INPS Gestione Separata professionisti.

Nota: l'app deve permettere inserimento libero perche codici e causali possono variare.

### 6. Dichiarazioni redditi

Archivio annuale con dati principali:

- anno dichiarazione;
- periodo d'imposta;
- ricavi/compensi quadro LM;
- coefficiente redditivita;
- reddito lordo;
- contributi dedotti;
- reddito netto imponibile;
- imposta sostitutiva dovuta;
- acconti versati;
- saldo o credito;
- contributi INPS dovuti;
- acconti INPS;
- saldo INPS;
- PDF allegato.

Questi dati servono a tarare il modello e verificare se le stime annuali erano corrette.

### 7. Parametri fiscali

Schermata impostazioni con versioni per anno.

Campi:

- anno di validita;
- aliquota imposta sostitutiva;
- coefficiente redditivita;
- aliquota INPS;
- aliquota prudenziale extra;
- regola acconti imposta;
- regola acconti INPS;
- soglia margine minimo consigliato.

Esempio iniziale:

```text
Anno: 2025
Imposta sostitutiva: 15%
Coefficiente redditivita: 78%
INPS Gestione Separata: 26,07%
Margine prudenziale: 1%
Accantonamento applicato: 33,0346%
```

### 8. Scadenze

Calendario scadenze con:

- saldo e primo acconto: normalmente fine giugno;
- eventuale pagamento differito con maggiorazione;
- secondo acconto: normalmente fine novembre;
- imposta di bollo trimestrale, se gestita;
- reminder personalizzabili.

Ogni scadenza deve mostrare:

- importo stimato;
- importo certo, se derivato da dichiarazione/F24;
- saldo conto tasse previsto;
- deficit o avanzo;
- fatture attese prima della scadenza;
- accantonamenti futuri previsti;
- livello di rischio.

Vista consigliata:

- timeline verticale o orizzontale, non calendario mensile classico;
- ogni scadenza e una card con importo stimato/certo;
- mostrare separatamente: saldo, primo acconto, secondo acconto, INPS, imposta, bolli;
- simulazione incorporata: includi/escludi incassi futuri prima della scadenza.

Esempio card:

```text
30 giugno 2026
Saldo + primo acconto

Stimato: 7.399 euro
Conto tasse previsto: 7.534 euro
Margine: +135 euro
Stato: coperto con margine basso
```

### 9. Simulatore

Funzione molto importante.

Domande che l'app deve poter simulare:

- posso saltare questo accantonamento?
- se incasso questa fattura a settembre invece che a luglio, resto coperto?
- quanto devo recuperare entro novembre?
- quante nuove fatture devo incassare per coprire il secondo acconto?
- se accantono il 33% invece del 32%, quanto margine ho?
- quanto posso prelevare dal conto tasse senza compromettere la prossima scadenza?

Interfaccia consigliata:

- slider o stepper per importo nuovo incasso;
- toggle per includere fatture attese;
- toggle per recuperare o saltare vecchi accantonamenti;
- selettore scadenza: giugno, novembre, anno completo;
- risultato immediato in linguaggio naturale.

Esempi di output:

```text
Se riparti da oggi e accantoni il 33,03%, resti coperto per giugno.
Per novembre ti servono almeno 13.300 euro di nuovi incassi prima della scadenza.
```

```text
Puoi saltare questo accantonamento solo se incassi almeno 4.200 euro entro il 30 novembre.
```

### 10. Importazione iniziale

Scelta di prodotto:

L'app non deve offrire come feature generale l'import diretto da qualunque file Excel personale. E troppo fragile: ogni utente organizza fogli, formule e colonne in modo diverso. Una feature del genere renderebbe Accantona dipendente da strutture imprevedibili e aumenterebbe il rischio di import sbagliati su dati fiscali.

Approccio consigliato:

- migrazione una tantum del file Excel attuale del primo utente/progetto, tramite script dedicato o procedura manuale assistita;
- import CSV standardizzato per l'app pubblica;
- template CSV ufficiale di Accantona;
- anteprima dati importati;
- validazione importi/date;
- rilevamento duplicati;
- import separato di fatture, F24, dichiarazioni e saldo conto tasse.

Versione avanzata:

- OCR/PDF parsing per F24 e dichiarazioni;
- allegati PDF archiviati localmente.

Conclusione: usare l'Excel attuale come fonte di migrazione e validazione iniziale, non come formato stabile da supportare nel prodotto.

## Modello dati suggerito

### Invoice

```swift
struct Invoice {
    var id: UUID
    var number: String
    var clientId: UUID?
    var contractId: UUID?
    var description: String
    var issueDate: Date
    var expectedPaymentDate: Date?
    var paidDate: Date?
    var amount: Decimal
    var stampDuty: Decimal
    var status: InvoiceStatus
    var notes: String
}
```

### TaxParameters

```swift
struct TaxParameters {
    var id: UUID
    var year: Int
    var substituteTaxRate: Decimal
    var profitabilityCoefficient: Decimal
    var inpsRate: Decimal
    var prudentialExtraRate: Decimal
    var appliedReserveRate: Decimal
}
```

Formula:

```swift
appliedReserveRate = profitabilityCoefficient * (substituteTaxRate + inpsRate) + prudentialExtraRate
```

### ReserveEntry

```swift
struct ReserveEntry {
    var id: UUID
    var invoiceId: UUID?
    var date: Date
    var incomeAmount: Decimal
    var appliedRate: Decimal
    var theoreticalAmount: Decimal
    var actualReservedAmount: Decimal
    var status: ReserveStatus
    var notes: String
}
```

### TaxPayment

```swift
struct TaxPayment {
    var id: UUID
    var paymentDate: Date
    var taxYear: Int
    var type: TaxPaymentType
    var section: TaxPaymentSection
    var code: String
    var amountPaid: Decimal
    var amountCompensated: Decimal
    var notes: String
}
```

### TaxReturnSummary

```swift
struct TaxReturnSummary {
    var id: UUID
    var declarationYear: Int
    var taxYear: Int
    var revenues: Decimal
    var grossTaxableIncome: Decimal
    var deductedContributions: Decimal
    var netTaxableIncome: Decimal
    var substituteTaxDue: Decimal
    var substituteTaxAdvancesPaid: Decimal
    var substituteTaxBalance: Decimal
    var inpsDue: Decimal
    var inpsAdvancesPaid: Decimal
    var inpsBalance: Decimal
}
```

## Calcoli principali

### Accantonamento per singolo incasso

```text
base previdenziale/fiscale = incasso * coefficiente redditivita
quota imposta = base * aliquota imposta sostitutiva
quota INPS = base * aliquota INPS
accantonamento teorico = quota imposta + quota INPS
accantonamento prudenziale = accantonamento teorico + incasso * margine extra
```

Con parametri 2025/2026:

```text
teorico = incasso * 0,7800 * (0,1500 + 0,2607)
teorico = incasso * 0,320346
prudenziale = incasso * 0,330346
```

### Copertura prossima scadenza

```text
saldo previsto conto tasse
+ accantonamenti futuri attesi entro scadenza
- pagamenti fiscali previsti entro scadenza
= margine/deficit
```

### Recupero accantonamenti saltati

```text
deficit stimato alla scadenza / aliquota accantonamento applicata = incassi necessari per recuperare
```

Esempio discusso:

```text
deficit stimato secondo acconto novembre 2026 senza recupero vecchi accantonamenti: circa 4.400 euro
aliquota prudenziale: 33,0346%
incassi necessari per coprirlo: circa 13.300 euro
```

## Schermate consigliate MVP

1. Dashboard
2. Fatture
3. Dettaglio fattura
4. Accantonamenti
5. Scadenze
6. Conto tasse
7. F24 / versamenti
8. Parametri fiscali
9. Import dati
10. Simulatore

## Architettura di navigazione

Tab bar consigliata:

1. Oggi
2. Fatture
3. Scadenze
4. Cassa
5. Altro

Dettaglio:

- **Oggi**: dashboard, prossima scadenza, azioni rapide.
- **Fatture**: elenco, ricerca, filtri, nuova fattura.
- **Scadenze**: giugno, novembre, bolli, simulazioni per data.
- **Cassa**: saldo conto tasse, movimenti, accantonamenti mancanti.
- **Altro**: F24, dichiarazioni, parametri fiscali, import/export, impostazioni.

Questa struttura evita di mettere troppe tab principali e mantiene la dashboard come ingresso naturale.

## Stati vuoti e onboarding

L'onboarding deve essere breve e orientato al risultato.

Passi:

1. Scegli regime fiscale iniziale.
2. Conferma parametri: imposta, coefficiente, INPS, margine prudenziale.
3. Inserisci saldo conto tasse.
4. Inserisci o importa prime fatture.
5. Inserisci ultimo F24 o ultima dichiarazione, opzionale.

Stati vuoti utili:

- Nessuna fattura: mostra pulsante "Aggiungi prima fattura".
- Nessun saldo conto tasse: mostra "Inserisci saldo per sapere se sei coperto".
- Nessuna scadenza configurata: crea automaticamente giugno/novembre per l'anno corrente.

Gli stati vuoti devono essere belli, ma funzionali: niente illustrazioni generiche che occupano mezzo schermo senza aiutare.

## Funzioni non indispensabili nella MVP ma utili dopo

- OCR F24 e dichiarazioni.
- Import automatico PDF.
- Export Excel/CSV.
- Backup iCloud.
- Widget iOS con saldo tasse e prossima scadenza.
- Notifiche scadenze.
- Protezione Face ID.
- Multi-partita IVA/profili fiscali.
- Grafici mensili incassi/accantonamenti.
- Report annuale da inviare al commercialista.
- Confronto stima vs dichiarazione effettiva.

## Tecnologie consigliate

- SwiftUI per interfaccia.
- Target visuale: iOS 26+ con Liquid Glass dove disponibile.
- SwiftData o Core Data per persistenza locale.
- Foundation Decimal per importi monetari, evitando Double nei calcoli contabili.
- FileImporter per import CSV/PDF.
- Charts framework per grafici.
- UserNotifications per promemoria.
- EventKit opzionale per scadenze calendario.
- CloudKit opzionale per sincronizzazione iCloud.
- Fallback visuale per iOS precedenti tramite materiali SwiftUI standard.

## Design system tecnico

Componenti da prevedere:

- `MoneyText`: formattazione coerente degli importi.
- `StatusBadge`: coperto, margine basso, deficit, stimato, certo.
- `CoverageBar`: barra copertura scadenza.
- `ReserveBreakdownView`: incasso, accantonamento, disponibile davvero.
- `TaxDeadlineCard`: card scadenza con importi separati.
- `InvoiceRow`: riga fattura con stato pagamento e accantonamento.
- `ParameterRow`: riga impostazione fiscale con valore e spiegazione.
- `ScenarioResultCard`: output simulatore.
- `GlassSurface`: wrapper riusabile che applica Liquid Glass su iOS 26+ e fallback material sugli iOS precedenti.

Regole:

- Usare `Decimal` per calcoli, `NumberFormatter` per display.
- Arrotondare a 2 decimali solo in visualizzazione o quando si registra un movimento effettivo.
- Conservare nei record la percentuale applicata al momento dell'accantonamento, per non alterare lo storico se cambiano i parametri futuri.
- Ogni importo stimato deve avere `isEstimate = true` o campo equivalente.
- Centralizzare l'uso di Liquid Glass in componenti dedicati, per non spargere `#available(iOS 26, *)` in tutta l'app.

## Regole UX

- Usare sempre importi arrotondati a 2 decimali in interfaccia.
- Mostrare chiaramente se un importo e stimato o certo.
- Non nascondere le formule: ogni stima deve avere una spiegazione apribile.
- Usare stati colorati ma sobri:
  - verde: coperto;
  - giallo: margine basso;
  - rosso: deficit;
  - grigio: dato non disponibile.
- Evitare una UI da foglio di calcolo: l'app deve essere orientata a decisioni e azioni.
- Non mostrare tabelle dense come primo livello; usare liste e riepiloghi, con dettaglio apribile.
- Usare testo grande solo per numeri decisionali, non per ogni importo.
- Ogni schermata principale deve avere una azione primaria chiara.
- I grafici devono spiegare uno stato, non decorare.

## Dati utili da caricare nel progetto

Per iniziare lo sviluppo sono utili:

1. Excel attuale corretto, da usare come fonte di migrazione una tantum e confronto dei risultati.
2. Dichiarazioni redditi 2021-2025, almeno per estrarre quadro LM/RR.
3. F24 2024 e 2025, per validare i versamenti.
4. Esempi di fatture PDF, solo se si vuole fare import/OCR o allegati.
5. Un CSV semplificato delle fatture, ideale per la prima importazione.

Per la sola MVP non e necessario importare tutte le fatture PDF. Basta partire dai dati strutturati dell'Excel o da un CSV ricavato dall'Excel.

Non conviene progettare l'app attorno all'import Excel generico. Conviene invece definire il modello dati ideale di Accantona e usare l'Excel solo per popolare la prima base dati.

## Roadmap suggerita

### Fase 1 - MVP locale

- Creazione progetto iOS SwiftUI.
- Modello dati locale.
- Inserimento manuale fatture.
- Calcolo accantonamenti.
- Dashboard copertura scadenze.
- Parametri fiscali modificabili.
- Registro F24 manuale.

### Fase 2 - Migrazione dati

- Migrazione una tantum dall'Excel attuale.
- Export CSV normalizzato dall'Excel, se piu semplice.
- Import CSV nell'app.
- Riconciliazione fatture/incassi/accantonamenti.
- Import saldo conto tasse iniziale.

### Fase 3 - Simulazioni

- Simulatore scadenze.
- Piano recupero accantonamenti saltati.
- Scenari con date incasso diverse.

### Fase 4 - Allegati e automazioni

- Allegati PDF fatture/F24/dichiarazioni.
- Notifiche.
- Backup iCloud.
- Export report per commercialista.

### Fase 5 - Qualita visiva e rifinitura

- Motion leggero su dashboard e conferma incasso.
- Dark mode rifinita.
- Widget iOS.
- Icona app definitiva.
- Haptic feedback su azioni importanti.
- Revisione microcopy.
- Test con dati reali storici.

## Icona app

Direzione consigliata:

- simbolo astratto di accantonamento/cassa;
- evitare monete generiche troppo banali;
- possibile segno: una piccola pila/scomparto con freccia in entrata;
- colori coerenti con palette: fondo petrolio o verde scuro, simbolo avorio/menta;
- leggibile anche in piccolo.

Concetto: "mettere da parte senza pensarci due volte".

## App Store

Titolo:

```text
Accantona
```

Sottotitolo:

```text
Fatture, tasse e contributi senza Excel
```

Descrizione breve:

```text
Accantona aiuta freelance e professionisti in regime forfettario a sapere quanto mettere da parte per tasse e contributi, quanto resta davvero disponibile e se le prossime scadenze sono coperte.
```

Claim possibili:

- "Incassi una fattura. Sai subito cosa mettere da parte."
- "Il conto tasse sotto controllo, senza fogli complicati."
- "Saldo, acconti e contributi sempre leggibili."

## Criteri di successo

L'app e riuscita se permette di rispondere in meno di 10 secondi a queste domande:

- Quanto devo accantonare da questa fattura?
- Posso spendere parte del saldo tasse?
- Sono coperto per giugno?
- Sono coperto per novembre?
- Quanto devo recuperare se ho saltato accantonamenti?
- Quanto ho incassato quest'anno?
- Quante tasse/contributi sto maturando?
- Quanto ho gia pagato con F24?

## Avvertenza

L'app deve essere uno strumento gestionale e previsionale personale. Non deve sostituire il commercialista ne la dichiarazione ufficiale. I calcoli devono essere modificabili e riconciliabili con i dati ufficiali di dichiarazioni e F24.
