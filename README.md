# Tape 01: The Pier Park — prototipo Godot 4

Gioco completo dall'inizio ai 2 finali. Tutto è generato via codice: modelli, filtro VHS e audio, quindi niente asset esterni.
Il design (ritmo minuto per minuto, testo dei 3 log, segnali visivi e audio) è in **DESIGN.md**.

## Come aprirlo

1. Scarica **Godot 4.3** o più recente, versione **Standard** (non .NET): https://godotengine.org/download
2. Estrai lo zip.
3. Apri Godot → **Importa** → scegli `project.godot` → **Importa e modifica**.
4. Premi **F5**.

## Comandi

| Tasto | Azione |
|---|---|
| WASD / frecce | Cammina |
| Shift | Corri (consuma stamina) |
| Mouse | Guarda |
| **Q** o **tasto destro** (tieni premuto) | Riavvolgi un ricordo rotto |
| A/D, frecce, mouse o rotella | Sintonizza il quadrante |
| Al faro: **Q** / **E** | REW (finale 1) / EJECT (finale 2) |
| Esc | Pausa (Resume, Settings, Main menu, Quit) |
| R | Ricomincia, dopo un finale |

## Novità della v0.2

- **Menu principale** sull'alba del finale 2 (molo e faro all'alba), con PLAY, SETTINGS e QUIT.
- **To be continued...** dopo entrambi i finali: è il nastro 01, la storia continua. [R] porta al menu principale.
- **Impostazioni** salvate in `user://settings.cfg`:
  - **Video:** qualità (Bassa/Media/Alta/Ultra/Personalizzata), modalità schermo, 13 risoluzioni da 800×600 a 3840×2160, V-Sync, limite FPS, scala di rendering 3D, MSAA, ombre, distanza visiva, luci dinamiche, FOV, luminosità, intensità dell'effetto VHS, contatore FPS.
  - **Audio:** volume generale, musica, effetti, ambiente, voce dei dialoghi, silenzio quando la finestra non è attiva.
  - **Gioco:** sensibilità del mouse, inversione dell'asse Y, barra della stamina (automatica/sempre/nascosta), corsa a interruttore, oscillazione della camera, suggerimenti a schermo.
  - **Accessibilità:** sottotitoli sì/no, dimensione, sfondo, velocità del testo, "riduci glitch e lampeggi".
  - **Comandi:** l'elenco dei tasti.
- **Voce a sillabe** (stile *Bad Parenting*): il testo appare lettera per lettera, con un borbottio ogni due lettere e pause sulla punteggiatura. Ogni lettera ha la sua altezza, quindi lo stesso testo suona sempre uguale.
- **Stamina:** circa 7 s di corsa piena. A zero sei senza fiato: cammini più piano e non corri finché non torni al 35%. Si ricarica in circa 5 s da fermo, più lentamente camminando. Con poca stamina si sente il fiatone. La barra è in basso al centro.
- **Mirino** ridisegnato: più piccolo, bracci uguali, allineato al pixel.
- **Menu di pausa** con Esc.

Nota sulla risoluzione: in finestra, la risoluzione scelta è la dimensione della finestra. A schermo intero è la risoluzione interna del 3D, perché l'interfaccia resta sempre nitida. Su schermi 4:3 o ultrawide l'immagine resta 16:9 con bande nere.

## Struttura

```
scripts/
  settings.gd       autoload: tutte le impostazioni, salvataggio, preset, finestra/volumi
  menu.gd           menu principale, pausa, pannello impostazioni, contatore FPS
  main.gd           costruisce parco, molo, faro e i 3 ricordi; loop di gioco, sintonia, log, finali
  memory_node.gd    un ricordo: pezzi rotti/interi, rewind con "rimbalzo", sagome, colonna glitch
  player.gd         prima persona, passo da camminata con videocamera, ondeggiamento a mano libera
  hud.gd            mirino VHS: REC, batteria, data, timecode, PLAY/REW/PAUSE/EJECT, quadrante, sottotitoli
  audio_synth.gd    risacca, fruscio, statica, motore del rewind, accordo di sintonia, pad, chime, passi
shaders/
  vhs_post.gdshader filtro della videocamera (freddo → caldo), glitch, freeze; si spegne con EJECT
  ps1.gdshader      look low-poly: vertex snapping, texture affine, dithering
  sea.gdshader      mare con onde
  beacon.gdshader   colonne glitch sopra i ricordi e fasci del faro
```

## Dove regolare le cose

- **Durata:** `player.gd` → `WALK_SPEED`; `main.gd` → `fog_density` in `_build_env()`, `BENCH_POS` / `GAZEBO_POS`, lunghezza del molo in `_build_pier()`.
- **Testi:** tutti nel dizionario `LOGS` in cima a `main.gd`; i finali stanno in `_ending_rewind()` e `_ending_eject()`.
- **Difficoltà della sintonia:** `_dial_update()` in `main.gd` (tolleranza `0.022`, tempo di lock `2.8` s).
- **Durata del rewind:** `memory_node.gd` → `dt / 3.2`.
- **Voce vera al posto dei sottotitoli:** registra i log, aggiungi un `AudioStreamPlayer` e fallo partire in `_lock_node()` insieme a `hud.play_subs(...)`.

## Collaudo automatico

```
godot --headless --path . -- --autotest              # menu, voce, stamina, pausa, preset, tutto il gioco, finale 2
godot --path . -- --autotest --ending1               # stesso, finale 1
godot --path . -- --shots                            # salva menu, impostazioni e 11 screenshot di gioco
```
