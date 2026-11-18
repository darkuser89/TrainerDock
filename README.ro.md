# TrainerDock · Mac Game Trainers

[Deutsch](README.md) · [English](README.en.md) · **Română**

[Descarcă aplicația](https://github.com/darkuser89/TrainerDock/releases/latest) ·
[Ghid detaliat de utilizare](docs/USER_GUIDE.ro.md)

Un lansator nativ pentru macOS, cu trainere independente pentru jocuri. Jocurile
instalate apar în stânga, iar funcțiile trainerului și butonul de pornire în dreapta.
Poți alege aplicația fiecărui joc în **Trainere și căi de instalare**.

Proiectul conține în prezent **29 de trainere independente**. Tabelul prezintă
profilurile disponibile din `Modules/`; versiunile se referă la **joc**, nu la
pachetele trainerelor, care au versiuni separate. Pachetele publicate sunt disponibile
în catalogul din aplicație. Trainerele noi apar fără actualizarea aplicației:
folosește **Caută actualizări pentru trainere** într-o versiune compatibilă de TrainerDock.

| Joc | Magazin acceptat | Versiune joc/profil | Observații |
|---|---|---|---|
| Balatro | Steam | 1.0.1o-FULL (Build 17459173) | |
| Control Ultimate Edition | Steam / Mac App Store | Steam 1.34; MAS 1.33.1 / 1.371 | |
| Crimson Desert | Steam | Bundle 1.0.35 (buildurile 450 și 466; Steam 26636972) | |
| Cyberpunk 2077 | Steam | 2.5.0 | |
| Dead Island 2 | Steam / Mac App Store | 0.6.4 | **Steam: numai versiunea Uncut; MAS: numai versiunea German Cut** |
| Death Stranding Director’s Cut | Mac App Store | 1.004 (Bundle 1.1.4) | |
| Dome Keeper | Steam | 5.0.8.14 | |
| DREDGE | Epic Games Store / GOG | Epic 1.5.5; GOG 1.5.3 | GOG folosește Rosetta |
| Escape from Duckov | Steam | 2.3.30 | |
| Frostpunk | Steam | 1.6.1 (Bundle 1.1.1, Build 15262773) | Rosetta |
| Frostpunk 2 | Steam | 1.6.1 (Bundle 0.5.591, Build 24037022) | |
| House Flipper | Steam | 1.26252 (Build 25247477) | Rosetta |
| inZOI | Steam | Bundle 5.4.95 (Build 26264076) | |
| Lies of P | Steam | 1.14.0 | |
| No Man’s Sky | Steam | Bundle 4.70 (Builds 26386568, 26540391) | |
| Prodeus | Steam | 1.0.2 (Build 9679369) | **Numai pentru un singur jucător** |
| Resident Evil 2 | Mac App Store | 1.0.2 | |
| Resident Evil 3 | Mac App Store | 1.0.0 | |
| Resident Evil 4 | Mac App Store | 1.0.7 | |
| Resident Evil 7 | Mac App Store | 1.0.4 | |
| Resident Evil Village | Mac App Store | 1.1.8 | |
| RoboCop: Rogue City | Steam | 0.0.1 | |
| Stray (WIP) | Steam | 1.5 (Build 12863654) | **Neterminat; patru funcții dezactivate** |
| Terraria | Steam | 1.4.5.8 (Build 24893155) | |
| The Long Dark | Steam / Epic Games Store | Steam 2.60 (Build 26450964); Epic 2.55 | |
| Turok | Steam | 2.0 (Build 18198095) | Rosetta |
| Turok 2: Seeds of Evil | Steam | 2.0 (Build 20961743) | Rosetta |
| Vampire Crawlers | Steam | 1.6.1 (Build 25304267) | |
| Vampire Survivors | Steam / Epic Games Store | 1.16.111 | |

Control include toate cele douăsprezece funcții solicitate. Limite native și
verificări: [modulul Control](Modules/control/README.md) (în germană).

Trainerele acceptă numai buildurile originale verificate. Lansatorul rulează pe
Apple Silicon; profilurile Intel acceptate explicit folosesc Rosetta. Alte magazine
și actualizări ale jocurilor nu sunt acceptate automat.

## Primii pași

1. Descarcă `TrainerDock-macOS-arm64.zip` din cea mai recentă versiune stabilă,
   dezarhivează-l și mută **TrainerDock.app** în dosarul Aplicații.
2. Deschide **Descarcă și gestionează trainerele** și descarcă trainerele dorite.
   Configurează căile lipsă în **Trainere și căi de instalare**.
3. Alege jocul și profilul magazinului. Deschide Steam pentru profilurile Steam;
   pentru Epic, închide mai întâi Epic Games Launcher din meniul său. Închide normal
   orice instanță a jocului care rulează deja, apoi apasă **Joacă** în TrainerDock.
4. Folosește comenzile din lansator sau deschide trainerul din joc cu **⌘ ^**.
   Scurtăturile fiecărei funcții apar lângă comenzi. **Dezactivează tot** oprește
   efectele continue, dar nu anulează modificările aplicate o singură dată.

Căutarea și filtrele **Instalat / Toate trainerele** restrâng biblioteca. Pictogramele
provin din aplicațiile jocurilor instalate. Dimensiunea ferestrei se păstrează la
schimbarea jocului. **⌘ ,** deschide setările, **⌘ R** reîncarcă trainerele și jocurile,
iar **⌘ 1** deschide biblioteca.

Interfața lansatorului este disponibilă în germană, română și engleză. Implicit,
urmează limba principală din macOS; pentru alte limbi folosește engleza. Alege
**Limba aplicației** în **Trainere și căi de instalare**, apoi repornește TrainerDock.
**Limba sistemului** reactivează alegerea automată. Cataloagele funcțiilor și trainerele
din joc păstrează propriile texte în germană; alegerea limbii lansatorului nu le traduce.

Liquid Glass rămâne activ și respectă setările de accesibilitate macOS. Glisorul
**Glas** din trainer modifică doar fundalul, de la transparent la opac; valoarea
se salvează separat pentru fiecare trainer. Căile lungi sunt afișate în setări și
în indicația butonului pentru cale, fără să ocupe vederea principală.

**Restabilește selecția la pornire** este dezactivată implicit. Dacă o activezi,
comutatoarele continue salvate sunt restabilite numai într-un context de joc valid.
Acțiunile unice nu se execută niciodată automat.

## Cerințe

Pentru utilizare: **Apple Silicon, macOS 27 sau mai nou** și un build original
acceptat al jocului. Catalogul și descărcările necesită acces la internet.
Profilurile Intel necesită și Rosetta. Xcode cu SDK macOS 27 sau mai nou este
necesar numai pentru dezvoltare, nu pentru aplicația descărcată.

## Descărcări și actualizări independente

[GitHub Actions](https://github.com/darkuser89/TrainerDock/actions/workflows/build-release.yml)
compară conținutul produselor cu ultimul catalog publicat cu succes și compilează
numai produsele noi sau modificate efectiv. Aplicația și trainerele au joburi separate,
cu cel mult trei compilări de trainere în paralel. Modificările exclusiv în documentație,
scripturi sau lansator nu produc versiuni noi pentru trainere neschimbate.
Pull requesturile rulează verificări, fără publicare.

[Versiunile stabile ale aplicației](https://github.com/darkuser89/TrainerDock/releases/latest)
oferă `TrainerDock-macOS-arm64.zip` și `SHA256SUMS`. Aplicația conține metadatele
catalogului, fără trainere native incluse. Fiecare trainer are propriul prerelease
imuabil `trainer-<id-joc>-v<versiune>` și se descarcă prin TrainerDock.
Versiunile vechi rămân disponibile. **Actualizează toate trainerele instalate**
descarcă doar pachetele mai noi care lipsesc, pentru trainerele deja instalate.

TrainerDock caută actualizări ale aplicației la pornire și apoi din oră în oră,
cu cel mult o verificare automată reușită pe zi. Pentru verificare manuală folosește
**TrainerDock → Caută actualizări…**; verificările automate se pot dezactiva din
același meniu. Instalarea începe după **Descarcă și instalează**. Dimensiunea și
SHA-256-ul furnizat de GitHub sunt verificate. Se înlocuiește numai aplicația;
trainerele, căile și setările rămân separate. Jocurile deschise amână instalarea
aplicației și nu sunt închise de actualizator.

Pachetele au semnătură ad-hoc, fără Developer ID sau notarizare. Nu sunt necesare
chei suplimentare de semnare pentru actualizări, certificate Apple sau confirmări
în Portchei. Protecțiile macOS rămân nemodificate.

## Compilare locală

Deschide `TrainerDock.xcodeproj` în Xcode. Schema **TrainerDock** compilează întregul
proiect; **TrainerDock-Launcher** doar lansatorul; `Trainer-<id-joc>` un singur
trainer complet. Verificările sintetice nu pornesc jocuri.

Instalează mai întâi antetele pentru arhive cu `brew install libarchive`. Aplicația
folosește biblioteca de sistem macOS, fără o cale Homebrew la rulare. Prin scripturi:

```sh
./script/build_and_run.sh --build-only   # Compilează și execută verificările sintetice
./script/build_and_run.sh --verify       # Deschide și lansatorul
python3 -B script/build.py --module <id-joc> --configuration Release
```

Aplicația curentă este construită în afara depozitului, la
`~/Library/Developer/TrainerDock/TrainerDock.app`. Modulele locale sunt construite
în `~/Library/Developer/TrainerDock/Modules` și nu se instalează automat.
`TRAINERDOCK_BUILD_DIR` poate indica un alt dosar separat; dosarele de cod și audit
sunt excluse. Bibliotecile trainerelor se încarcă doar în procesul jocului ales,
niciodată în lansator.

Două trainere C# folosesc în compilările GitHub numai componentele noastre compilate.
Sursele, profilurile originale și fișierele sunt legate prin SHA-256; componentele
învechite sunt respinse. Assembly-urile jocurilor nu sunt încărcate pe GitHub.
Vezi [publicarea versiunilor](docs/RELEASING.md) (în germană).

La prima pornire, TrainerDock importă căile, selecțiile și valorile de transparență
din vechiul MHT. Modulele utilizatorului se află în
`~/Library/Application Support/TrainerDock/Modules`; locațiile vechi rămân lizibile.
Numele SDK și formatul `.mhtmodule` rămân compatibile.

Documentație de dezvoltare (în germană): [AGENTS.md](AGENTS.md),
[module](docs/MODULES.md), [arhitectură](docs/ARCHITECTURE.md) și
[șablonul reutilizabil de trainer](Templates/Trainer/README.md) (`$trainer-template`).
Modulele noi din șablon sunt dezactivate pentru dezvoltare, fără adrese preluate
din alte jocuri sau efecte simulate.

Păstrează sincronizate cele trei README-uri și ghiduri când se schimbă utilizarea,
cerințele sau lista jocurilor.
