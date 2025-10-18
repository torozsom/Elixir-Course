Számtekercs – megoldói dokumentáció (Nhf1)

Ez a dokumentum a `Nhf1/nhf1.ex` jelenlegi megoldását írja le: hogyan bontottuk fel a feladatot (feladat.txt), miért helyes az így kialakított megközelítés, milyen adatszerkezeteket és algoritmusokat használunk, hogyan működik minden segédfüggvény, és végül milyen optimalizációk vezethetnek gyorsabb futáshoz.

## probléma összefoglaló

Adott egy n×n tábla és egy 1..m értékkészlet. Olyan táblákat keresünk, ahol:
- minden sorban és minden oszlopban az 1..m számok mindegyike pontosan egyszer szerepel (a többi cella 0),
- a bal felső sarokból induló spirális bejárás mentén a nem-0 számok rendre 1,2,..,m,1,2,..,m,… ciklust követnek.
Előre adott megszorítások: néhány cella 1..m közötti értéke rögzített.

Kimenet: az összes ilyen tábla listája.

## bontás kisebb feladatokra és indoklás

1) Spirális bejárás előállítása
- A spirál determinisztikus: külső peremet járjuk be (felső sor, jobb oszlop, alsó sor, bal oszlop), majd a belső (n-2)×(n-2) négyzetre rekurzálunk.
- A spirál indexe (0..n^2-1) meghatározza, hogy hány nem-0 értéket helyeztünk el addig (s), így a következő elhelyezhető érték determinisztikus: next_value = (s mod m) + 1.
- Ezzel a globális spirál feltételt lokálisan, lépésről lépésre tartatjuk be.

2) Megszorítások kezelése
- A megadott `fixed_cells` listát a spirál indextere képezzük le (pozíció→index), így az adott indexhez gyorsan ellenőrizhető a kényszerérték.
- A kényszer csak akkor helyezhető, ha a spirál fázisban éppen az a `next_value` következne; különben az adott elágazás elvetendő. Ha nincs kényszer, szabadon dönthetünk place/skip között.

3) Sor/oszlop egyediség és kvóták
- Soronként és oszloponként m darab nem-0 értéknek kell állnia, és mindegyik 1..m érték egyszer fordulhat elő.
- Ezt bitmaszkokkal (1..m bitek) és számlálókkal (hány nem-0/tengely) valósítjuk meg, így O(1) az ellenőrzés és a frissítés.

4) Visszalépéses keresés (DFS)
- A spirál indexeit balról jobbra növeljük. Minden indexcella esetén két ág: helyezés (ha lehet) vagy kihagyás (ha nincs kényszer).
- A levélnél (idx == n^2) csak akkor elfogadott a tábla, ha globálisan n*m nem-0-t tettünk (minden sor/oszlop m-et tartalmaz).
- Ezzel garantáltan minden érvényes tábla előáll, a lokális szabályok pedig erősen szűkítik a keresési teret.
 - A keresés elején globális kapacitás-ellenőrzést végzünk: ha a hátralévő spirálpozíciók száma kisebb, mint a még hátralévő nem-0 értékek száma (n*m - placed), az ágat azonnal lezárjuk.

Miért helyes? A spirál és a next_value összeköti a globális ciklust a lokális lépéssel; a sor/oszlop maszk+kvóta pedig biztosítja az egyediség/kvóta feltételt. A két feltétel együtt pontosan a kiírt problémát kényszeríti ki.

## adatszerkezetek és miért ezeket használjuk

- spiral_positions :: [{row, col}] – a spirál sorrendje. Könnyű róla indexelni és a pozíciókat az indexhez rendelni.
- spiral_positions_t :: tuple – gyors elem/2 hozzáférés a DFS-ben.
- index_by_position :: %{ {r,c} => i } – kényszerek gyors illesztéséhez.
- forced_values_by_index :: %{ i => v } – a DFS lépésnél O(1) nézet.
- row_value_masks, col_value_masks :: tuple(int) – m-bites maszkok, a használt értékek jelzésére. A tuple put_elem/elem műveletei O(1)-ek.
- row_nonzero_counts, col_nonzero_counts :: tuple(int) – a „kvóta” (m) betartására.
- build_suffix_counts eredménye (row_suffix_counts, col_suffix_counts) :: tuple(tuple) – kapacitás-pruninghoz (aktívan használjuk).

Ezek a struktúrák minimális allokációval és gyors indexeléssel támogatják a backtrackinget.

## függvények és szerepük

- helix/1
  - Belépési pont. Ellenőrzi az inputot, előállítja a spirált és a kényszereket indexre képezi, inicializálja a maszkokat/számlálókat és a suffix statisztikát. Meghívja a visszalépéses keresést; a megoldásokat közvetlenül a levélszinten építi fel (nincs utólagos uniq/validálás).

- spiral_path/1 és spiral_path_layers/5
  - Előállítja a teljes spirál koordinátalistát. Rétegenként halad, duplikációk nélkül (a szélekhez feltételeket használ).

- build_suffix_counts/2
  - Suffix statisztika: a „következő indextől a végéig” tartományban hány pozíció esik egy adott sorra/oszlopra. A jelenlegi megoldás ezt aktívan használja kapacitás-pruninghoz.

- backtrack_over_spiral/14
  - A magkereső, akkumulátoros stílusban. Rész-állapota tartalmazza a „placements” listát (spirálindex, érték párok) és egy eredmény-akkumulátort.
  - Minden lépésben kiszámítja a next_value-t, és két ágat vizsgál:
    - PLACE: ha nincs kényszer, vagy a kényszer értéke megegyezik a next_value-val, és a sor/oszlop maszk+kvóta engedi → frissít, rekurzál.
    - SKIP: csak ha nincs kényszer → 0-ként továbblép változatlan maszkokkal/számlálókkal.
  - Pruningok:
    - Globális kapacitás: ha a hátralévő spirálpozíciók száma < a hátralévő nem-0 értékek száma (n*m - placed), az ágat lezárjuk.
    - Lokális (suffix) kapacitás: a következő indextől mért sor/oszlop-kapacitás elegendő-e a kvótához; ha nem, az ágat lezárjuk.
  - Báziseset: ha `placed_count == n*m` és minden sor/oszlop nem-0 darabszáma m, a „placements”-ből egyszeri allokációval táblát építünk, és az eredményhez adjuk.

- can_place_value?/8
  - O(1)-ben eldönti, hogy egy érték elhelyezhető-e egy cellába a sor/oszlop maszkok és számlálók alapján.

- mark_value_used/3
  - Beállítja a megfelelő bitet a sor/oszlop maszkban.

- counts_reach_target?/2
  - Igaz, ha minden érintett számláló elérte az m-et.

- build_board_from_assignments/2
  - A kiválasztott (nem-0) hozzárendelésekből táblát épít, a hiányzó helyeket 0-val tölti.

- valid_solution_board?/4
  - Defenzív ellenőrzés: sor/oszlop kvóta teljesült, és a spirál menti nem-0 sorozat pontosan a 1..m ciklust adja (hossz: n*m). A jelenlegi implementáció nem hívja; hibakereséshez opcionális.
 
- capacity_ok_for_lines?/9
  - A következő index utáni suffix tartományt vizsgálja: az érintett sorban/oszlopban maradt cellák száma elegendő-e a még hiányzó nem-0 értékekhez (m - current_count). Ha bármelyik tengelyen kevés a hely, az ágat lezárjuk.

## miért működik ez a megközelítés?

- A spirál index→next_value leképezése lokálissá teszi a globális ciklust.
- A sor/oszlop maszk+kvóta lokálisan is elég erős megszorítás, így a keresés korán elvágja a nem ígéretes ágakat.
- A kényszerértékek indexbe rendezése O(1) döntést tesz lehetővé minden lépésben.

## teljesítmény (Benchee) és eddigi optimalizációk

Mérés: a repo-ban található `Nhf1/bench.exs` Benchee-szkripttel mértük a `Nhf1.helix/1` futási idejét és memóriahasználatát a mellékelt 0–11 teszteseteken.

Válogatott eredmények (átlag, hozzávetőlegesen):
- 8×8, m=4 (tc10): ~0.94 s; ~401 MB.
- 9×9, m=3 (tc11): ~0.17 s; ~59 MB.
- 8×8, m=3 (tc9): ~0.056 s; ~23 MB.
- 6×6, m=3 (tc5): ~1.0–1.1 ms; ~0.38 MB.

A fenti számokat az alábbiak adják:
- Duplikációmentes spirálgenerálás (élszűrők az egysoros/egyoszlopos rétegekre).
- Akkumulátoros DFS: a táblák csak levélszinten épülnek.
- Bitmaszkos sor/oszlop-ellenőrzés és kvótaszámlálás (O(1)).
- Kettős pruning: globális kapacitás + suffix-alapú sor/oszlop kapacitás.

## optimalizációs terv (további gyorsítások)

Az alap megoldás helyes és a fenti két pruning már aktív. További, még nem implementált ötletek:

1) Kényszer-igazítás (alignment) lookahead
 - A következő kényszerindex(ek)ig nézzük meg, hogy skip-ekkel eltolható-e úgy a fázis, hogy a kényszer értéke pont a megfelelő `next_value`-ra essen. Ha lehetetlen, zárjuk az ágat.

2) Branch-heurisztika
- A spirál fix, de a SKIP/PLACE döntésnél előnyben részesíthetjük a PLACE ágat olyan celláknál, ahol a sor/oszlop kvóta már magasabb (kevesebb mozgástér), így hamarabb futunk zsákutcába, és gyorsabb a visszalépés.

3) Bitmaszk optimalizációk
- Előszámolt maszkok (például `mask_for_value[v] = 1 <<< (v-1)`) csökkenthetik a műveletek számát.
- A tuple helyett (speciális esetben) Erlang bitset-ek vagy kis-int optimalizációk kipróbálhatók, bár a tuple + elem/put_elem már gyors.

4) Memoizáció (óvatosan)
- Állapotrész-hash: (idx, row_value_masks[row_idx0], col_value_masks[col_idx0], placed_count) formában;
- csak akkor éri meg, ha sok az azonos részállapot; különben a hash kezelése többe kerülhet.

5) Early goal pruning
- Amint valamelyik sor/oszlop eléri az m kvótát, ha az adott tengelyen maradt hely még tartalmaz kényszerellentmondást (például ugyanott későbbi kényszer van más értékre), az ágat lezárhatjuk.

6) Részleges validáció
- Időnként ellenőrizzük a spirál nem-0 szekvencia fázisát a közeljövőbeli kényszerekkel (pár lépésre előre), és zárjuk le a biztosan érvénytelen ágakat.

7) Párhuzamosítás
- A backtracking felső néhány szintjén a külön ágak függetlenül futtathatók; Elixir Task/Flow-vel korlátozott szinten párhuzamosítható.

8) Mikro-optimalizációk
- Maszkok előkészítése tömbbe (`mask_for_value[v] = 1 <<< (v-1)`).
- Inline frissítések, ideiglenes változók minimalizálása a hot path-on.
- PLACE ág preferálása „szűk” suffix-kapacitásnál a gyorsabb zsákutcákért.

## futtatás

Nyissa meg a `Nhf1/nhf1.ex` fájlt és futtassa a workspace gyökérből:

```pwsh
elixir Nhf1/nhf1.ex
```

Ez kiírja az összehasonlító tesztesetek eredményeit (true/false párok). A jelenlegi megoldás a mellékelt 0–11-es teszteseteket teljesíti.

Benchee benchmark futtatása:

```pwsh
elixir Nhf1/bench.exs
```

## zárszó

A megoldás egyszerű, de erős lokális szabályokra épít (spirálfázis + sor/oszlop egyediség + kvóta). Ez jó alap a későbbi, célzott pruningokhoz, amelyekkel még nagyobb táblákra is gyors maradhat a keresés.

