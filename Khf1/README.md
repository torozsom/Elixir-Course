## Khf1 – Hányféleképpen állítható elő a célérték

Ez a megoldás a Feladat.txt-ben megadott feladathoz készült. A cél, hogy megszámoljuk: egy adott nemnegatív célértéket hányféleképpen lehet előállítani adott pozitív egész értékekből összeadással, ahol minden értékhez egy maximális darabszám tartozik. A darabszám 0 különleges jelentésű: korlátlan mennyiséget jelent az adott értékből.

Fő követelmények, amelyeket teljesít a megoldás:

- Összeadási kifejezéseket kombinációként számolunk (a sorrend, zárójelezés nem számít).
- Nagy célértékekre is hatékony: O(n·T) idő és O(T) memória, ahol n az értékek száma, T a célérték.
- A kód Elixir 1.18 (OTP 28) alatt a megadott tesztekkel fut, a modul- és típus-specifikációk a kiírás szerintiek.

---

## Algoritmus röviden

A megoldás dinamikus programozást használ egy egydimenziós tömbön (`:array`), és minden értéket ("érmét") egymás után dolgoz fel. A klasszikus korlátos pénzváltás (bounded coin change) egy hatékony megvalósítását alkalmazzuk csúszóablakos trükkel, maradékosztályokra bontva.

Jelölések:

- `dp_old[t]`/`dp_new[t]`: hány módon állítható elő a t összeg a már feldolgozott értékekkel (régi/új állapot).
- Adott érték `v` és darabkorlát `limit` (korlátlan: `limit = floor(T/v)`) esetén a rekurzió:

$$
\mathrm{dp_{new}}[t] = \sum_{k=0}^{\min(\text{limit},\ \lfloor t/v \rfloor)} \mathrm{dp_{old}}[t - k\cdot v].
$$

Ezt a rekurziót hajtjuk végre hatékonyan csúszó ablakkal, külön-külön a maradékosztályok sorozatain (t = r, r+v, r+2v, ...).

Optimalizációk:

1) LNKO-szűkítés: ha az összes érték legnagyobb közös osztója (LNKO) nem osztja a célt, nincs megoldás; ha osztja, minden értéket és a célt elosztjuk az LNKO-val. Ez csökkenti T-t, így gyorsít.

2) Csúszóablak a maradékosztályokon: az $\mathrm{dp\_new}[t]$ összege egy v-hosszú ritka sorozaton futó, fix méretű mozgó összeg, ahol az ablakméret $\text{limit}+1$. Így az egyenkénti O(limit) összegzés helyett O(1) frissítéssel lépünk t→t+v.

---

## Programfelépítés

Fő publikus függvény:

- `Khf1.hanyfele/2`
	- Triviális esetek: negatív cél (0), nulla cél (1).
	- Bemenetszűrés: csak pozitív értékek és nemnegatív darabszámok, érték ≤ cél.
	- LNKO kiszámítása és (ha lehet) skálázás.
	- Értékek rendezése (kombináció-számlálás helyes biztosításához).
	- DP inicializálás `:array`-val, `dp[0] = 1`.
	- Értékenkénti frissítés csúszóablakkal.
	- Eredmény kiolvasása: `dp[T]`.

Privát segédfüggvények (részletek alább):

- `szur_es_rendez/2`: bemeneti párok szűrése és rendezése.
- `ellenoriz_es_skalaz/2`: LNKO ellenőrzés és skálázás.
- `dp_inicializal/1`: DP tömb létrehozása (T+1 hossz, dp[0]=1).
- `dp_frissit_minden_ertekkel/3`: az összes érték alkalmazása a DP-n.
- `dp_egy_ertekkel/4`: egy érték érvényesítése (limit + csúszóablak).
- `effektiv_limit/3`: effektív darabkorlát számítása.
- `csuszoablak_frissites/4`: csúszóablakos frissítés maradékosztályonként.
- `maradekosztaly_feldolgozas/6`: egy r maradékosztály feldolgozása.
- `maradeksorozat_bejaras/9`: t = r, r+v, r+2v, … sorozat bejárása és mozgó összeg karbantartása.
- `lnko_lista/1`: több pozitív egész LNKO-ja.

---

## Helyességi vázlat

1) Kombináció vs. permutáció: A DP-t úgy építjük, hogy minden értéket egyszer, külső ciklusban dolgozunk fel, és az adott érték teljes hatását egyszerre visszük át `dp_old`→`dp_new`. Így egy adott multihalmaz-összeállítás csak egyszer számítódik bele; a sorrendvariációk nem növelik a számot.

2) Rekurzió helyessége: A fenti képlet a korlátos ismétlésszámú összeadás standard rekurziója: `k` példányt választunk az éppen feldolgozott értékből (0..limit), a maradék összeg előállításainak számát pedig `dp_old[t - k·v]` adja. A maradékosztályos `t = r + m·v` paraméterezés csak átrendezés; a képlet változatlan.

3) Csúszó ablak helyessége: A `t` értékek egy fix maradékosztály sorozatán adják ugyanazon előző DP-értékek egy egymásra csúszó összegét. Az ablak mérete pontosan `limit+1`, mivel ennél több darabot nem vehetünk fel az értékből. Lépésről lépésre új belépő kerül be (`dp_old[t]`), és az ablak bal széle akkor esik ki, ha már túlcsordult a `limit+1` hosszon (`dp_old[t - (limit+1)·v]`). Ez pontosan a rekurzió szerinti összeget adja.

4) LNKO-szűkítés helyessége: Legyen `g = gcd(v1, v2, ..., vn)`. Minden olyan összeg, ami a megadott értékekből összeáll, osztható g-vel. Ha `T % g != 0`, nincs megoldás. Ha `T % g == 0`, az értékek és a cél g-vel való osztása ekvivalens problémát ad (megoldásszám változatlan), csak kisebb skálán.

5) Indukció a feldolgozott értékek számára: Kezdetben `dp[0]=1`, más minden 0: az üres összeadás egyedüli megoldás 0-ra. Tételezzük fel, hogy `dp_old` helyes az első `i` értékre; `csuszoablak_frissites/4` a rekurzióval egyenértékű frissítést végez, így `dp_new` helyes az első `i+1` értékre. A végén `dp[T]` a teljes megoldásszám.

---

## Idő- és memóriaigény, optimalitás

- Memória: egyetlen `:array` DP-vonal, mérete T+1 → O(T).
- Idő: értékenként végigmegyünk összesen T+1 indexen. Az egyes maradékosztály-sorozatok (átlagosan ~T/v lépés) csúszóablaka O(1) időben frissül. Így összességében O(n·T).
- LNKO-szűkítés csökkenti T-t → gyorsít.
- Az `:array` O(1) elérést/írást biztosít (amortizált), így gyorsabb és memóriában kompaktabb a Map-alapú megoldásnál.

Megjegyzés: a megoldások száma nagy lehet, de Elixirben a teljes számábrázolás tetszőleges pontosságú egész (bignum), így túlcsordulás nincs.

---

## Privát függvények részletesen

### `szur_es_rendez/2 :: ertekek(), T -> [{v, darab}]`

- Funkció: Bemenet-szűrés (v>0, darab≥0, v≤T) és rendezés érték szerint növekvően.
- Helyesség: Csak releváns párok maradnak; a rendezés biztosítja a kombináció-számlálást.

### `ellenoriz_es_skalaz/2 :: [{v, darab}], T -> :nincs_megoldas | {:ok, [{v, darab}], T'}`

- Funkció: LNKO számítása, T oszthatóság ellenőrzése; ha lehetséges, skálázás LNKO-val.
- Helyesség: Ekvivalens probléma kisebb skálán; ha T%LNKO≠0, nincs megoldás.

### `dp_inicializal/1 :: non_neg_integer() -> :array.array()`

- Funkció: Létrehoz egy `:array` tömböt hossza `T+1`, alapértelmezett 0 értékekkel, majd beállítja `dp[0] = 1`-et.
- Helyesség: A DP kiinduló állapota pontosan ez: 0 összeget egyféleképp (üres összeadás), más összeget semhogy.
- Optimalitás: O(T) inicializálás; ez minimális az egydimenziós DP-hez.

### `lnko_lista/1 :: [pos_integer()] -> pos_integer()`

- Funkció: Több pozitív egész LNKO-ját adja vissza iteratív `Integer.gcd/2` redukcióval.
- Helyesség: Az LNKO asszociatív és kommutatív, páronkénti redukció korrekt eredményt ad.
- Optimalitás: O(n · log M), ahol M a számok nagyságrendje; ez a standard legjobb gyakorlat.

### `dp_frissit_minden_ertekkel/3 :: (:array, [{v, darab}], T) -> :array`

- Funkció: Az összes érték egymás utáni alkalmazása a DP-n.
- Helyesség: Értékenként `dp_old→dp_new` átmenet; a végén helyes `dp[T]`.

### `dp_egy_ertekkel/4 :: (:array, v, darab, T) -> :array`

- Funkció: Egy érték érvényesítése a DP-n (limit számítás + csúszóablak frissítés).
- Helyesség: Megfelel a rekurziónak az adott értékre.

### `effektiv_limit/3 :: (darab, v, T) -> non_neg_integer()`

- Funkció: Korlátlan esetben `floor(T/v)`, különben `min(darab, floor(T/v))`.
- Helyesség: Maximum ennyi darab fér be T-be az adott értékből.

### `csuszoablak_frissites/4 :: (:array, v, limit, T) -> :array`

- Funkció: Egyetlen értéket (v) érvényesít a teljes DP tömbön korlát `limit` mellett. Maradékosztályonként meghívja a feldolgozást, és új DP tömböt állít elő.
- Helyesség: A maradékosztályokra bontás teljes és diszjunkt lefedést ad a 0..T indextartományon; minden `t` pontosan egyszer kerül beírva, a rekurzió szerinti összeggel (ld. `bejar_maradek_sorozat/9`).
- Optimalitás: O(T) munka az adott értékre, mert minden `t`-t pontosan egyszer frissítünk, az ablak frissítése O(1).
- Perem: `limit = 0` esetén a DP változatlan (azonos tömbbel térünk vissza).

### `maradekosztaly_feldolgozas/6 :: (:array, :array, v, limit, r, T) -> :array`

- Funkció: Egy adott maradék `r` (0 ≤ r < v) sorozatát dolgozza fel: `t = r, r+v, r+2v, ... ≤ T`. Kezdeti ablakösszeg 0-ról indul.
- Helyesség: Ha `r > T`, nincs bejárandó index – identitás. Egyébként a teljes sorozatot `bejar_maradek_sorozat/9` végigjárja és pontos DP-értékeket ír.
- Optimalitás: Csak a ténylegesen érintett indexeket érinti; költsége O(⌈(T−r+1)/v⌉).

### `maradeksorozat_bejaras/9 :: (:array, :array, v, limit, r, index, lepes, T, ablak_osszeg) -> :array`

- Funkció: A maradék `r` sorozatának iteratív (rekurzív) bejárása csúszó ablakkal. Minden lépésben:
	1) hozzáadja az új belépőt: `belepo = dp_old[index]`,
	2) ha az ablak hossza meghaladná a `limit+1`-et, kivonja a kiesőt: `dp_old[index - (limit+1)·v]`,
	3) az így kapott `osszeg2` az új `dp_new[index]`.
- Helyesség: Tételenként megegyezik a rekurzió összegével; a `lepes` számláló biztosítja, hogy pontosan akkor esik ki az első tag, amikor k már `limit+1` lenne.
- Optimalitás: Lépésenként O(1), ezért a teljes sorozat bejárása lineáris a sorozat hosszában.
- Kilépés: ha `index > T`, befejezi az adott maradékosztály feldolgozását.

---

## Peremfeltételek és ellenőrzések

- Negatív célérték: 0 megoldás (előfeltétel a kiírásban is nemnegatív cél, de védekezünk).
- Nulla célérték: 1 megoldás (üres összeadás), bármely értékkészlet mellett.
- Értékszűrés: csak `ertek > 0`, `darab >= 0`, `ertek <= cél`. Üres lista esetén és pozitív cél mellett 0.
- `darab = 0` jelentése: korlátlan – ezt `limit = floor(T/v)`-vel modellezzük.

---

## Összegzés

A megoldás a korlátos pénzváltási feladat standard, bizonyíthatóan helyes dinamikus programozási megközelítését valósítja meg. A csúszóablakos technika a maradékosztályokon pontosan a szükséges rekurziót számolja ki, de az egyszerű összegezésnél lényegesen hatékonyabban. Az LNKO-szűkítés tovább gyorsítja a futást nagy célértékek esetén is. A DP `:array`-on fut, ami kompakt és gyors, így a megoldás teljesíti a „nagy célértékekre is működő, hatékony” követelményt.

