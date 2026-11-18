# TrainerDock – Ghid de utilizare

[Deutsch](USER_GUIDE.de.md) · [English](USER_GUIDE.en.md) · **Română**

[Înapoi la README și lista jocurilor](../README.ro.md)

## 1. Ce face TrainerDock

TrainerDock gestionează jocuri, căi de instalare și trainere descărcate separat.
Aplicația conține lansatorul și metadatele catalogului. Biblioteca nativă a
trainerului se încarcă în jocul ales numai când soliciți pornirea. Descărcarea
unui trainer nu pornește jocul.

Versiunea aplicației, versiunea trainerului și buildul jocului sunt independente.
Trainerele noi pot apărea într-o aplicație existentă compatibilă. Un build nou al
jocului necesită totuși un profil acceptat explicit; același număr de versiune
afișat sau același nume al jocului nu dovedește compatibilitatea.

## 2. Instalare și configurare

1. Verifică cerințele: Apple Silicon, macOS 27 sau mai nou și un build original
   acceptat în [lista jocurilor](../README.ro.md). Profilurile Intel marcate necesită Rosetta.
2. Descarcă `TrainerDock-macOS-arm64.zip` din
   [cea mai recentă versiune stabilă de pe GitHub](https://github.com/darkuser89/TrainerDock/releases/latest),
   dezarhivează-l și mută **TrainerDock.app** în Aplicații. Nu ai nevoie de Xcode pentru utilizare.
3. Deschide **Descarcă și gestionează trainerele**, apoi, dacă este nevoie,
   **Caută actualizări pentru trainere**. Găsește jocul și descarcă o versiune oferită.
   Acest pas necesită internet și nu pornește jocul.
4. Deschide **Trainere și căi de instalare** cu **⌘ ,**. Dacă un joc nu este detectat,
   alege aplicația sa `.app`. Profilurile magazinelor au căi separate: o instalare
   Steam nu poate înlocui, de exemplu, calea pentru GOG.
5. Alege jocul în stânga și profilul magazinului/buildului în dreapta.
   **Toate trainerele** include și jocuri neconfigurate; **Instalat** afișează instalările detectate.

TrainerDock nu descarcă jocuri; ai nevoie de instalările lor originale. Pachetele
au semnătură ad-hoc, fără Developer ID sau notarizare. Dacă macOS afișează o eroare,
comunică mesajul exact; nu modifica semnăturile jocurilor sau protecțiile macOS.

## 3. Pornirea jocului cu trainer

Închide mai întâi orice instanță existentă, normal, din joc. Apoi:

- **Steam:** Deschide Steam normal și alege profilul Steam în TrainerDock.
- **Epic:** Închide mai întâi Epic Games Launcher din meniul său. Serviciul de pornire
  modifică temporar asocierea de lansare Epic și o restabilește după aceea. Un client
  Epic deschis poate suprascrie asocierea din memoria cache.
- **GOG / Mac App Store:** Alege profilul acceptat și instalarea corespunzătoare.

Apasă **Joacă**. Dacă butonul spune **Descarcă trainerul**, descarcă mai întâi
pachetul; descărcarea nu pornește jocul. Identitatea jocului și trainerul sunt
verificate din nou înainte de pornire. Pentru builduri neacceptate nu se pornește
în tăcere jocul fără trainer. Nu deschide o a doua instanță pentru a ocoli un eșec de pornire.

## 4. Funcții, interfața din joc și transparență

Funcțiile apar în dreapta, în grupuri extensibile. Comutatoarele controlează efecte
continue; câmpurile numerice stabilesc valoarea dorită. Acțiunile unice trebuie
declanșate explicit. Descrierile indică stările necesare în joc, precum un inventar
deschis sau un personaj încărcat.

**⌘ ^** deschide sau închide trainerul din joc: Command plus tasta circumflex,
nu Control. Celelalte scurtături apar lângă funcții. Numele jocului apare în
stânga sus. Dacă scurtătura nu funcționează, verifică aranjamentul tastaturii și
dacă jocul are focalizarea; lansatorul poate deschide și el interfața pentru o sesiune activă potrivită.

Activarea solicitată nu înseamnă încă un efect confirmat. Starea **Activ** este
raportată numai după recitirea rezultatului din joc. Funcțiile indisponibile pot
aștepta contextul necesar; funcțiile dezactivate sau WIP nu sunt finalizate.
**Dezactivează tot** oprește efectele continue proprii trainerului. Nu anulează
modificări unice, precum bani deja cheltuiți sau obiecte deja adăugate.

Liquid Glass rămâne activ. Glisorul **Glas** din dreapta jos modifică opacitatea
fundalului: **0% transparent, 50% sticlă nativă, 100% opac**. Textele și comenzile
rămân vizibile. Valoarea este salvată pentru fiecare trainer; setările de accesibilitate
macOS, precum reducerea transparenței, au prioritate.

**Restabilește selecția la pornire** este dezactivată inițial. Când o activezi,
comutatoarele continue salvate se restabilesc numai într-un context de joc valid.
Acțiunile unice nu se repetă la pornire. Căile, selecțiile și valorile de transparență
se păstrează în preferințele utilizatorului.

## 5. Schimbarea limbii aplicației

Deschide **Trainere și căi de instalare → Limba aplicației**. Alege **Deutsch**,
**Română**, **English** sau **Limba sistemului**, apoi închide și redeschide normal
TrainerDock. Alegerea se păstrează și nu modifică limba globală din macOS.

**Limba sistemului** folosește limba principală: germana, româna și engleza sunt
recunoscute, inclusiv variantele regionale. Pentru alte limbi principale se folosește
engleza, chiar dacă germana apare mai jos în lista preferințelor. Această setare
afectează interfața lansatorului. Cataloagele trainerelor și interfețele din joc
păstrează momentan textele funcțiilor în germană.

## 6. Actualizarea, schimbarea și ștergerea trainerelor

Deschide **Descarcă și gestionează trainerele** și apasă **Caută actualizări pentru
trainere** pentru a reîmprospăta catalogul. Descarcă versiunea mai nouă a unui trainer;
**Folosește** selectează o versiune instalată. Schimbarea versiunii este posibilă
după închiderea normală a jocului.

**Actualizează toate trainerele instalate** verifică întâi catalogul online, apoi
descarcă ultimele pachete care lipsesc pentru trainerele deja instalate. Filtrul
curent de căutare nu limitează această acțiune. Descărcările se fac pe rând, cu
afișarea progresului; o eroare individuală nu le oprește pe celelalte. Trainerele
neinstalate nu sunt adăugate. Versiunile deja prezente nu sunt descărcate din nou,
iar cele mai noi nu sunt înlocuite cu unele mai vechi.

Pachetele noi nu le înlocuiesc pe cele vechi. Jocurile deschise păstrează exact
instanța de trainer folosită. După închiderea jocului poți selecta din nou o versiune
anterioară instalată, dacă profilul ei corespunde jocului instalat.

Folosește **Șterge** pentru o versiune instalată de care nu mai ai nevoie. Sesiunile
active, jocurile deschise și bibliotecile încă folosite sunt protejate. TrainerDock
nu șterge automat versiunile vechi. Ștergerea elimină pachetul trainerului, nu jocul
sau salvările sale.

## 7. Actualizarea aplicației TrainerDock

Folosește **TrainerDock → Caută actualizări…** pentru verificare manuală.
Verificările automate se pot activa sau dezactiva din același meniu. Au loc la
pornire și apoi din oră în oră, cu cel mult o verificare automată reușită pe zi.

**Descarcă și instalează** descarcă o versiune stabilă mai nouă. Actualizatorul
verifică dimensiunea și SHA-256-ul furnizat de GitHub, așteaptă închiderea jocurilor
și înlocuiește numai aplicația. Nu închide jocuri. Pachetele trainerelor, căile și
setările rămân în afara aplicației. Dacă aplicația actualizată nu pornește, înlocuirea
este anulată. Actualizările aplicației și ale trainerelor sunt operații separate.

## 8. Stocare și compilări GitHub

Pachetele descărcate sunt stocate pe versiuni la:

```text
~/Library/Application Support/TrainerDock/Modules/<id>/<version>/<id>.mhtmodule
```

Locațiile vechi MHT rămân lizibile. Folosește gestionarea trainerelor pentru ștergere
sau schimbarea versiunilor; nu înlocui manual bibliotecile unui joc deschis.
TrainerDock nu modifică salvările pentru a face un build compatibil. Modificările
produse de funcțiile trainerului pot ajunge în salvare când jocul salvează normal.

Aplicația și modulele rămân în același depozit, cu compilări și versiuni publicate separate.
GitHub compară conținutul efectiv al produselor cu ultimul catalog confirmat.
Schimbările aplicației compilează doar aplicația; cele ale trainerelor doar modulele
afectate. Dependențele comune modificate pot afecta mai multe trainere. Documentația,
testele sau simpla schimbare a numerelor de versiune nu produc actualizări de funcții.
Trainerele au joburi individuale de compilare, cel mult trei în paralel, și versiuni
publicate imuabile. Numai pachetele confirmate intră în catalogul de descărcări.
Detalii pentru dezvoltatori: [ghidul de publicare](RELEASING.md) (în germană).

## 9. Probleme frecvente

| Problemă | Ce poți face |
|---|---|
| Lipsește un joc | Alege **Toate trainerele**, actualizează catalogul și selectează aplicația `.app` corectă în setările căilor. Reîncarcă cu **⌘ R**. |
| O actualizare a jocului este respinsă | Caută un trainer corespunzător. Fără un profil verificat, buildul nou rămâne blocat; magazinul sau numele fișierului nu sunt suficiente. |
| O descărcare lipsește sau eșuează | Verifică internetul și reîmprospătează catalogul. Dacă aplicația este prea veche, instalează versiunea necesară. Comunică eroarea și versiunea trainerului/profilului. |
| O funcție așteaptă | Intră în contextul necesar și citește descrierea. Funcțiile WIP sau dezactivate rămân limitate. Prodeus este doar pentru un singur jucător. |
| Pornirea Epic eșuează | Închide normal Epic mai întâi și verifică profilul și calea Epic. Nu porni o a doua instanță a jocului în paralel. |
| Interfața, mouse-ul sau trecerea în ecran complet se blochează | Salvează dacă este posibil și închide normal. Comunică jocul, magazinul, buildul, versiunea trainerului și cauza exactă; folosește un pachet compatibil confirmat. |

Lista actuală și limitările cunoscute sunt în [README-ul în română](../README.ro.md).
Testele sintetice de compilare nu demonstrează FPS-ul din joc sau compatibilitatea
cu builduri care nu sunt enumerate.
