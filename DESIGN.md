# Tape 01: The Pier Park — Design

**Genere:** analog horror psicologico, esplorazione in prima persona
**Tema:** *Bounce Back*, cioè cadere e rialzarsi
**Durata target:** 15–20 minuti
**Ambiente:** un parco costiero del 1994 che porta a un molo di legno e a un faro. Nebbia, silenzio, tutto visto dal mirino di una videocamera VHS.

---

## Il loop in una riga

Trova un luogo rotto → **tieni premuto REW** e lo vedi ricomporsi → **sintonizza** finché la statica sparisce → il ricordo si fissa: tornano colore e luce, le sagome svaniscono e parte il log.

Tre volte. Poi il faro e la scelta.

---

## Ritmo minuto per minuto

### Minuti 0–5 · "PLAY"

| Tempo | Cosa succede | Perché |
|---|---|---|
| 0:00 | Schermata nera, "TAPE 01 / THE PIER PARK", INVIO = PLAY. | Il gesto di premere play mette subito il giocatore "dentro il nastro". |
| 0:10 | OSD della videocamera, colori freddi e desaturati, fruscio. 3 righe d'intro: videocamera ritrovata, 14 novembre 1994, nastro rovinato in 3 punti. | Dà l'obiettivo senza un tutorial: tre punti rovinati. |
| 0:30 | Arco "PIER PARK", chiosco dei gelati chiuso, viale. In lontananza, sopra gli alberi, una **colonna glitch magenta/ciano** che buca la nebbia. | Primo punto di riferimento visivo: va' lì. |
| 1:30 | Più ti avvicini, più sale la **statica** (audio) e più l'immagine trema (video). Compaiono **sagome nere** immobili, rivolte verso di te. Se ti avvicini spariscono con un glitch. | Prima tensione: niente ti attacca, ma ti guardano. |
| 2:30 | **Panchina** (Memoria 01): pezzi sparsi a terra che tremano. Compare "[Q] TIENI PREMUTO — RIAVVOLGI". | Primo uso della meccanica, con un oggetto piccolo e facile da leggere. |
| 3:00 | Rewind (~3 s): icona ◀◀ REW, barra, motore del nastro, pezzi che "rimbalzano" al loro posto. Se lasci prima, tornano indietro. | Insegna "tieni premuto" con il feedback, non con le parole. |
| 3:15 | Quadrante di sintonia. Statica forte e ago giallo; quando sei vicino la statica cala, emerge un accordo pulito, l'ago diventa verde e si riempie la barra LOCK. | Il secondo gesto si capisce dall'audio: segui il suono pulito. |
| 3:30 | Chime → "MEMORIA 1/3 — RIPRISTINATA". Il lampione si accende caldo, le sagome si afflosciano, la nebbia si scalda un po'. **Log 01** (~30 s) con un pad caldo sotto. | Ricompensa sensoriale: luce, colore, silenzio, voce. |
| 4:00–5:00 | Esplorazione libera: sentieri ad anello, panchine normali, lampioni. | Respiro prima del secondo ricordo. |

### Minuti 5–15 · "REW"

| Tempo | Cosa succede | Perché |
|---|---|---|
| ~5:00 | La seconda colonna glitch (a est, oltre il viale) diventa il nuovo obiettivo. Il giocatore può anche aver già provato il molo. | Il parco è aperto: l'ordine panchina/gazebo è libero. |
| ~6:00 | Chi prova il **ponte** troppo presto trova "IL NASTRO NON TORNA PIÙ INDIETRO · RICORDI 1/2". | Una porta chiusa senza muro: spiega la regola da sola. |
| ~7:00 | **Gazebo** (Memoria 02): pali a terra, tetto crollato di sbieco. 4 sagome intorno, più vicine di prima. | Oggetto più grande, rewind più spettacolare. |
| ~8:00 | Sintonia, lock, lanterna del gazebo accesa. **Log 02** (~30 s). Il calore del filtro sale a 2/3. | Il mondo è visibilmente meno freddo: progresso leggibile. |
| ~9:00 | Si va al lungomare. Ringhiera, cartello "MOLO CHIUSO / DANNI MAREGGIATA". Rumore delle onde più forte. | Cambio di spazio: dal parco al mare. |
| ~10:00 | Il molo: passi che diventano legno, sagome **sul molo** verso il crollo. In fondo, la colonna glitch sopra l'acqua. | Corridoio stretto: la tensione più alta del gioco. |
| ~11:00 | **Ponte crollato** (Memoria 03): assi che galleggiano in acqua. Un muro invisibile impedisce di cadere. Rewind: le assi risalgono dal mare. | Il ricordo più "fisico": senza ponte non si passa. |
| ~12:00 | Sintonia, lock. Il ponte diventa calpestabile. **Il faro si accende**: lanterna e due fasci rotanti che tagliano la nebbia. **Log 03** (~30 s). | Il segnale finale ti chiama da solo. |
| 12–15 | Camminata lunga e calma sul molo (~70 m) mentre il log finisce. | Decompressione prima della scelta. |

### Minuti 15–20 · "EJECT"

| Tempo | Cosa succede | Perché |
|---|---|---|
| ~15:00 | Piattaforma del faro. "(Fine del nastro.) (Riavvolgere ancora. O espellere.)" Sull'OSD: **◀◀ REW [Q]** e **⏏ EJECT [E]**. | Scelta binaria con i due tasti che il giocatore ha già imparato. |
| — | **Finale 1: Bloccato nel rewind.** Rewind lungo e violento, poi il nastro si ferma sulla panchina: calda, intera, perfetta. ‖ PAUSE, timecode fermo, statica a righe, e ogni 3,6 s un piccolo ◀◀ con il chime che si ripete in loop. | La nostalgia come trappola: è bello, ma non si muove più. |
| — | **Finale 2: Bounce back.** Clunk dell'EJECT, nero. Poi niente OSD, niente filtro, niente fruscio: un'alba pulita sul mare, il sole basso, il pad caldo. | Togliere il filtro è il gesto di andare avanti. |
| +1 min | Testo del finale e "[R] ricomincia". | Chiusura. |

**Nota sulla durata.** Camminando senza fermarsi il percorso dura pochi minuti. I 15–20 minuti vengono dalla nebbia (si vede a ~25 m), dai sentieri ad anello, dai 3 log da ~30 s e dalla camminata sul molo. Se in playtest viene più corto, le leve sono in `player.gd` (`WALK_SPEED`), in `main.gd` (`fog_density`, le posizioni `BENCH_POS`/`GAZEBO_POS`, la lunghezza del molo) e nel numero di righe dei log.

---

## I tre log audio (testo completo)

Il narratore registra per sé stesso, non per il giocatore: voce bassa, frasi brevi, nessuna morale urlata.

### MEMORIA 01 — LA PANCHINA

> «Questa era la nostra panchina. Ci venivamo dopo scuola, a guardare il molo.»
> «Il giorno che è andato tutto storto sono venuto qui e sono rimasto seduto fino al buio.»
> «Pensavo che cadere volesse dire essere finito.»
> «Invece cadere è una cosa che ti succede. Non è chi sei.»
> «Quel giorno mi sono alzato tardi. Ma mi sono alzato.»

### MEMORIA 02 — IL GAZEBO

> «La domenica qui suonava la banda del paese.»
> «Una volta il trombettista ha sbagliato una nota, forte, davanti a tutti.»
> «Ha riso, ha ripreso fiato, e ha ricominciato dalla battuta prima.»
> «Nessuno si ricorda la nota sbagliata. Tutti si ricordano che ha finito il pezzo.»
> «Non devi ripartire da zero. Ti basta ripartire dalla battuta prima.»

### MEMORIA 03 — IL PONTE DEL MOLO

> «La mareggiata del '94 si è portata via un pezzo di molo. Dicevano che non l'avrebbero più rifatto.»
> «L'hanno rifatto con le assi vecchie e quelle nuove, mischiate.»
> «Si vede ancora, dove si è rotto. Le cicatrici si vedono sempre.»
> «Ma ci passi sopra lo stesso. Un ponte serve a questo.»
> «Il faro è in fondo. Lì il nastro finisce, e decidi tu cosa farne.»

L'arco dei tre log è: **cadere non è chi sei → non serve ripartire da zero → le cicatrici restano, ma ci passi sopra.**

---

## Segnali che spiegano tutto senza tutorial

### Visivi

| Segnale | Significato |
|---|---|
| **Colonna glitch magenta/ciano** sopra la nebbia | Lì c'è un ricordo rotto. Sparisce quando lo ripari. |
| Immagine che trema di più avvicinandosi | Sei vicino a un ricordo. |
| Pezzi a terra che tremano e sfarfallano | Questo oggetto si può riavvolgere. |
| "[Q] TIENI PREMUTO — RIAVVOLGI" | Unico testo di istruzione, e appare solo quando serve. |
| Icona ◀◀ REW in alto e barra sotto il centro | Stai riavvolgendo; la barra mostra quanto manca. |
| Pezzi che tornano indietro se lasci | Bisogna tenere premuto, non basta premere. |
| Ago **giallo → verde**, barre SIG, barra LOCK | Sei sulla frequenza giusta; restaci finché LOCK è pieno. |
| Luce calda che si accende, colore che torna | Ricordo salvato. |
| Il faro che si accende | Ultimo obiettivo. |
| Icone ◀◀ REW [Q] / ⏏ EJECT [E] | La scelta finale. |
| Batteria che perde una tacca dopo 10 minuti | Il nastro (e il tempo) stanno finendo. |

### Audio

| Suono | Significato |
|---|---|
| Fruscio costante | Stai guardando un nastro. Sparisce solo con EJECT. |
| Statica con crepitii che sale con la vicinanza | "Fuochino": c'è un ricordo rotto qui vicino. |
| Bip breve e glitch | Una sagoma è appena sparita. |
| Motore del nastro che sale di tono | Rewind in corso; più è acuto, più sei vicino. |
| Statica forte che si pulisce in un accordo | Sintonia: segui il suono pulito. |
| Chime a tre note | Ricordo fissato. |
| Pad caldo | C'è un log: puoi ascoltare camminando. |
| Borbottio a sillabe | Il protagonista parla tra sé e sé (in sincrono con il testo che appare). |
| Fiatone | Stamina bassa: rallenta. |
| Passi su erba / passi su legno | Sei passato dal parco al molo. |
| Clunk meccanico | EJECT: fine del filtro. |
