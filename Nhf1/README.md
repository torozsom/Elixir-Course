Nhf1 — Helix (Számtekercs) megoldó dokumentáció

Ez a README összefoglalja a `feladat.txt`-ben leírt problémát, bemutatja, hogyan bontja le a `nhf1.ex` kisebb, kezelhető feladatokra, miért adnak ezek együtt helyes és teljes megoldást, és milyen implementációs döntések (algoritmusok, adatszerkezetek) állnak mögötte. Tartalmaz futtatási és mérési útmutatót, valamint javasolt további optimalizációkat is.

## Problémaösszefoglaló (feladat.txt alapján)

Adott egy n×n-es négyzetes tábla. Néhány mezőben már 1 és m közötti szám van, a többi üres (kimenetben 0). Úgy kell további 1..m számokat elhelyezni, hogy az alábbiak teljesüljenek:

- Sor/oszlop latin feltétel: minden sorban és minden oszlopban az 1..m számok mindegyike pontosan egyszer szerepel; a fennmaradó mezők 0-k.
- Helix (spirál) sorrend: ha a táblát a bal felső sarokból induló, a külső „keretet” körbejáró, majd befelé rekurzáló spirál mentén járjuk be, akkor a nem-0 értékek sorban az 1,2,…,m,1,2,…,m,… ciklust követik.

A `helix/1` bemenete `{n, m, constraints}`, ahol `constraints :: [{{r,c}, v}]` rögzített, 1-alapú koordinátákon ír elő konkrét `v ∈ 1..m` értéket.

A kimenet a lehetséges táblák listája (tetszőleges sorrendben). Minden tábla `n×n` egész szám lista-lista, ahol a 0 üres mezőt, az 1..m pedig elhelyezett értéket jelent.

Típusok (a kódban is):

- `@type size() :: integer()`  — tábla méret n, n > 0
- `@type cycle() :: integer()` — ciklushossz m, 0 < m ≤ n
- `@type value() :: integer()` — cellaérték 1..m
- `@type field() :: {row(), col()}` 1..n tartományú sor/oszlop indexekkel
- `@type puzzle_desc() :: {size(), cycle(), [field_value()]}`
- `@type solution() :: [[integer()]]`

Specifikáció:

`@spec helix(sd :: puzzle_desc()) :: solutions()`

Példa (feladat.txt):

`{6, 3, [{{1,5},2}, {{2,2},1}, {{4,6},1}]}` egy (egyetlen) megoldással rendelkezik; a solver ezt a táblát adja vissza 0-kkal az üres mezőkön.

## A megoldás felbontása (nhf1.ex)

A globális feltételeket egy rögzített spirál sorrend mentén lokális lépésekre fordítjuk, és erős metszésekkel (pruning) támogatott visszalépéses keresést (DFS) futtatunk. Fő részek:

1) Spirális bejárás előállítása
- `build_spiral_positions/1` és `build_spiral_layers/5` a teljes koordinátasorrendet generálja a külső peremtől befelé, duplikáció nélkül. Ez 0..(n^2−1) lineáris indexet indukál.

2) Megszorítások (kényszerek) indexre vetítése
- A bemeneti `{{r,c}, v}` kényszereket „spirálindex → fix érték” formára képezzük le.
- A `build_constraint_arrays/2` három tömböt készít a hot path-hoz:
  - `forced_values_t`: indexenként 0 (nincs kényszer) vagy v ∈ 1..m;
  - `forced_prefix_counts`: prefix-összegek, hány kényszer esik az i előtti indexekre (lookahead határokhoz);
  - `next_forced_index_t`: a következő (≥ i) kényszer indexe vagy −1.
- A `validate_constraints/3` defenzív input-ellenőrzést végez.

3) Sor/oszlop egyediség és kvóta bitmaszkokkal
- Minden sorhoz és oszlophoz tartunk egy „használt értékek” bitmaszkot és egy számlálót a nem-0 darabokra.
- A `value_mask_t` előre tartalmazza a 0 és 1..m maszkjait.
- A `can_place_mask?/8` O(1)-ben dönti el, hogy (row, col) pozícióba lerakható-e az adott érték: a megfelelő bitnek szabadnak kell lennie mindkét maszkban, és a sor/oszlop számlálója < m kell legyen.
- Az `apply_value_mask/3` állítja be a biteket, a `counts_meet_quota?/2` pedig ellenőrzi levélszinten, hogy minden sor/oszlop pontosan m nem-0-t kapott.

4) Suffix kapacitások előszámítása a metszéshez
- A `compute_suffix_capacities/2` előállítja, hogy az index i-től a végéig még hány spirálpozíció jut egyes sorokra/oszlopokra. Keresés közben a `has_sufficient_line_capacity?/9` gyorsan kizárja azokat az ágakat, ahol valamelyik sor/oszlop már nem érheti el az m darab nem-0 kvótát.

5) Spirálfázis és keresés
- A lépés `idx`-nél az eddig lerakott nem-0 darab `placed_count`. A következő elvárt helix-érték lokálisan adódik: `next_value = (placed_count mod m) + 1`.
- A `dfs_spiral_search/…` a backtracking magja. Minden spirálpozíciónál:
  - Ha itt kényszer van, az csak akkor maradhat, ha megegyezik a `next_value`-val és átmegy a sor/oszlop ellenőrzésen; különben metszés.
  - Ha nincs kényszer, két ág lehetséges:
    - PLACE: lerakjuk a `next_value`-t, ha engedett;
    - SKIP: üresen hagyjuk (0) — de csak ha ez a közeli kényszerekig megtartható helix-illeszthetőséget eredményez.
- Globális kapacitásmetszés: ha a hátralévő pozíciók száma < a hátralévő nem-0 helyezések száma, az ágat lezárjuk.
- Igazítás (alignment) lookahead: az `alignment_window_allows?/8` csak akkor hívja az `alignment_feasible?/6`-ot, ha a következő kényszer indexe egy konfigurálható ablakon belül van. Ez megakadályozza, hogy SKIP döntések később biztos lehetetlenséget okozzanak.

6) Megoldás összeállítása
- Ha minden kényszer teljesült és összesen `n*m` nem-0-t helyeztünk el (azaz soronként és oszloponként m-et), az `assemble_board_from_map/2` egyetlen táblává építi az állapotot; a többi helyen 0 marad.

## Miért adnak ezek együtt helyes megoldást?

- Helyesség (nincsenek hamis pozitívok)
  - A spirál szabályt inkrementálisan tartatjuk be: az elhelyezett k-adik nem-0 értéknek `((k mod m) + 1)`-nek kell lennie, így a fix spirál mentén a nem-0 szekvencia pontosan az 1..m ciklust adja.
  - A sor/oszlop latin szabályt lokálisan ellenőrizzük bitmaszkokkal és számlálókkal, így duplikáció nem keletkezik, és a kvóta m teljesül.
  - A kényszerek pontos indexeiken egyezniük kell a helix fázissal; az ellentmondó ágak azonnal kizáródnak.
  - A metszések csak olyan ágakat vágnak le, amelyek biztosan nem képesek teljesíteni a kvótákat vagy az igazítást — érvényes megoldást nem veszítünk el miattuk.

- Teljesség (nincsenek hamis negatívok)
  - A DFS bejár minden, a kényszerekkel konzisztens SKIP/PLACE kombinációt. Minden érvényes tábla megfeleltethető egy útnak, ahol a szükséges helyezéseket megtesszük, minden más pozíciót kihagyunk. A spirál teljes rendezést ad, ezért a keresés minden megoldást elér.

- Termináció
  - A keresési tér véges (n^2 index, bináris döntések, kényszerekkel), így a futás befejeződik. A metszések csak gyorsítanak, de a helyességhez nem szükségesek.

## Implementációs döntések és trade-offok

- Fix bejárás és lokális fázisszabály
  - A globális helix feltételt lokális szabállyá alakítjuk: `next_value = (placed_count mod m) + 1`. Nem kell a teljes prefixet cipelni; a fázist a `placed_count` hordozza.

- Tuple-ök a hot path-on listák helyett
  - Sok tömb-szerű adatot tuple-ben tárolunk (`spiral_positions_t`, sor/oszlop indexek, maszkok, suffix kapacitások, kényszerek), mert az `elem/2` és `put_elem/3` gyors véletlen hozzáférést és kisméretű frissítést tesz lehetővé backtracking közben.

- Bitmaszkok az egyediséghez
  - Értékenként (1..m) egy bitet használunk, így O(1) az ellenőrzés/frissítés. A `Bitwise` import csökkenti az overheadet.

- Suffix kapacitások mint „jóslók”
  - Előre kiszámítjuk soronként/oszloponként a hátralévő helyek számát; ez olcsó, de erős metszést ad, ha egy vonal biztosan nem érheti el az m kvótát.

- Kényszertömbök és ablakolt igazítás
  - A `forced_values_t`, `forced_prefix_counts`, `next_forced_index_t` mikrolookaheadot tesz lehetővé. Az igazítás ellenőrzését egy konfigurálható ablak (module attribútum: `@alignment_window`, alapértelmezés 256) korlátozza a per-lépés költség miatt; futásidőben felülbírálható `HELIX_ALIGN_WIN` környezeti változóval.

- Egyszerű tábla-reprezentáció
  - A táblát csak levélszinten állítjuk össze egy tömör hozzárendelés-mapból; ez csökkenti az allokációt és a másolást a keresés során.

## Futtatás és benchmark

A workspace gyökeréből vagy a `Nhf1` mappából futtatható. A solver fájl a `nhf1.ex`-ben levő teszteseteket is kiírja.

```pwsh
elixir Nhf1/nhf1.ex
```

Benchee benchmark a mellékelt szkripttel:

```pwsh
elixir Nhf1/bench.exs
```

Bementek szűrése `BENCH_FILTER` környezeti változóval (regex vagy részsztring):

```pwsh
$env:BENCH_FILTER = "tc1[01]"; elixir Nhf1/bench.exs   # csak tc10 és tc11
$env:BENCH_FILTER = "8x8";      elixir Nhf1/bench.exs   # csak 8×8-as esetek
```

Tipp: az igazítás lookahead ablak hangolása (0 letiltja):

```pwsh
$env:HELIX_ALIGN_WIN = "0";    elixir Nhf1/bench.exs
$env:HELIX_ALIGN_WIN = "256";  elixir Nhf1/bench.exs
```

## Teljesítmény-pillanatkép (példamérések)

A `Nhf1/bench.exs`-szel, a mellékelt teszteseteken mértük:

- 8×8, m=4 (tc10): ~0,94 s; ~401 MB
- 9×9, m=3 (tc11): ~0,17 s; ~59 MB
- 8×8, m=3 (tc9): ~0,056 s; ~23 MB
- 6×6, m=3 (tc5): ~1,0–1,1 ms; ~0,38 MB

Eredetük:

- Duplikációmentes spirálgenerálás (egy sor/oszlopos rétegek körültekintő kezelése)
- Akkumulátoros DFS; a táblák csak levélszinten materializálódnak
- Bitmaszk alapú sor/oszlop ellenőrzés és kvóták (O(1))
- Többlépcsős metszés: globális kapacitás + suffix kapacitások + ablakolt igazítás a SKIP ágon

## További optimalizációs ötletek

Az alap metszések implementálva vannak. Lehetséges fejlesztések:

1) Erősebb alignment lookahead
   - Több közeljövőbeli kényszerre kiterjeszteni a vizsgálatot (pl. k darab következő fix index), vagy szigorúbb kongruencia-korlátokat fenntartani a `placed_count`-ra kényszerek között.

2) Ágképzési heurisztikák
   - Preferálni a PLACE ágat, ha egy sor/oszlop közel jár a kvótához vagy ha a suffix kapacitás „szűk”, így gyorsabban érünk zsákutcába és hamarabb vágunk.

3) Adatszerkezet finomhangolás
   - Speciális bitkészletek/primitívek kipróbálása; ahol dominál a véletlen hozzáférés, maradjanak a tuple-ök.

4) Könnyűsúlyú memoizáció
   - Csak kompakt állapotprojekciókat érdemes cache-elni, pl. `(idx, row_mask[row], col_mask[col], placed_count)`, és csak akkor, ha az ütközés/overhead vállalható.

5) Koraibb konfliktusdetektálás
   - Ha egy sor/oszlop elérte az m kvótát, gyorsan ellenőrizni, hogy nem maradt-e ugyanazon a vonalon ellentétes kényszer; ha igen, azonnal metszünk.

6) Párhuzamosítás
   - A DFS fa felső szintjeinek szétosztása független feladatokra (`Task.async_stream`) korlátozott konkurenciával.

7) Mikro-optimalizációk
   - Hot path maszkok inline-olása; ideiglenes allokációk csökkentése; gyakori tuple-ök lokális változóban tartása; SKIP ágon a tuple-módosítások minimalizálása.

## Megjegyzések

- A kód a `Nhf1/nhf1.ex` fájlban, a benchmark a `Nhf1/bench.exs`-ben van; a feladatleírás a `Nhf1/feladat.txt`.
- Az `@alignment_window` modul-attribútum alapértelmezése 256; futásidőben a `HELIX_ALIGN_WIN` környezeti változóval felülbírálható.
- A megoldás tervezésekor Elixir 1.18 és Erlang/OTP 28 (a kiírás szerint) célzott.


