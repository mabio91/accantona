# Import CSV fatture Accantona

Accantona importa solo CSV standardizzati. Non prova a interpretare file Excel personali o fogli con colonne arbitrarie.

## Template

```csv
numero,cliente,descrizione,data_emissione,data_incasso_prevista,data_incasso,importo,bollo,stato,note,importo_accantonato
1/2026,Cliente Alpha,Consulenza strategica,2026-01-15,2026-02-15,,3333.34,2,emessa,Da incassare,
2/2026,Cliente Beta,Workshop,2026-02-01,2026-02-20,2026-02-18,1800,2,incassata,Incassata senza accantonamento,
3/2026,Cliente Gamma,Retainer,2026-03-01,2026-03-30,2026-03-28,2500,2,incassata,Accantonamento parziale,500
```

## Colonne

- `numero`: numero fattura, obbligatorio.
- `cliente`: cliente, obbligatorio.
- `descrizione`: descrizione libera.
- `data_emissione`: obbligatoria, formato `yyyy-MM-dd`.
- `data_incasso_prevista`: opzionale, formato `yyyy-MM-dd`.
- `data_incasso`: opzionale, formato `yyyy-MM-dd`. Se presente, Accantona tratta la fattura come incassata e genera un accantonamento.
- `importo`: obbligatorio, maggiore di zero.
- `bollo`: opzionale, usa `0` o lascia vuoto.
- `stato`: `bozza`, `emessa`, `incassata`, `annullata`.
- `note`: testo libero.
- `importo_accantonato`: opzionale. Se maggiore di zero, Accantona crea anche il movimento positivo nel ledger della cassa tasse.

## Regole

- Le date devono usare `yyyy-MM-dd`.
- Gli importi possono usare punto decimale (`3333.34`) o virgola decimale (`3333,34`).
- Se usi la virgola decimale in un CSV separato da virgole, metti l'importo tra virgolette: `"3333,34"`.
- In alternativa puoi usare `;` come separatore, utile per file esportati in formato italiano.
- Accantona salta le fatture duplicate con stesso `numero + cliente + data_emissione`.
- Le righe con errori vengono mostrate in anteprima e non vengono importate.

## Effetti import

- Ogni riga valida crea una `Invoice`.
- Se `data_incasso` e presente, viene creato anche un `ReserveEntry` calcolato con i parametri fiscali correnti.
- Se `importo_accantonato` e valorizzato, viene creato un movimento ledger `Accantonamento import CSV`.
