Számtekercs – részletes terv (Nhf1)

Cél
- A helix/1 függvény megvalósítása, amely az n×n táblára visszaadja az összes olyan kitöltést, ahol:
	- minden sorban és oszlopban az 1..m számok pontosan egyszer szerepelnek (a többi mező 0), és
	- a bal felső sarokból induló, kifelé→befelé haladó spirális bejárás mentén a nem-0 számok rendre 1,2,..,m,1,2,..,m,… ciklust követnek.
- Bemenet: {n, m, megszorítások}, ahol megszorítások: [{{r,c}, v}], 1≤v≤m.
- Kimenet: a megoldások listája (mátrixok listája), tetszőleges sorrendben.

1) Feladat lebontása kisebb logikai egységekre
1.1 Spirális bejárás generálása
- Készítsünk egy positions listát az n×n mező összes (r,c) koordinátájáról, a kiírás szerinti sorrendben (felső sor bal→jobb, jobb szélső oszlop fel→le, alsó sor jobb→bal, bal szélső oszlop le→fel; majd rekurzívan a belső (n-2)×(n-2) négyzet).
- Ez biztosítja, hogy a bejárás indexe (i=0..n^2-1) determinisztikusan adott legyen.

1.2 Kötelező értékek (megszorítások) előfeldolgozása
- Alakítsuk a megadott megszorításokat két irányba is gyorsan elérhetővé:
	- constraints_by_pos :: map {(r,c) -> v}
	- constraints_by_index :: map {i -> v}, ahol i a positions szerinti index.
- Konfliktusellenőrzés: ugyanarra a cellára két különböző v esetén nincs megoldás.

1.3 Sor/oszlop szabályok és állapot
- Minden sorban és oszlopban az 1..m számok pontosan egyszer szerepelhetnek.
- Ennek hatékony ellenőrzésére bitmaszkokat és számlálókat vezetünk:
	- row_used[r]: m bites maszk, jelzi, hogy a sorban mely értékek szerepeltek már (1..m → bitek 0..m-1)
	- col_used[c]: ugyanez oszlopokra
	- row_count[r], col_count[c]: hány nem-0 került már elhelyezésre az adott sorban/ oszlopban; a cél mindkettőnél m.

1.4 A spirális sorrendhez illesztett értékevolúció
- Legyen s az eddig elhelyezett (nem-0) darabszám. A következő elhelyezhető érték v_next = (s mod m) + 1.
- Egy cellában két lehetőség van:
	- elhelyezünk v_next-et (ha nem ütközik semmivel),
	- vagy 0-t hagyunk (kihagyás), ha nincs kényszerített érték.
- Ha a cellára megszorítás van és v≠v_next, akkor a cellába csak 0 kerülhet → de ez ellentmond a feladatnak? Nem: a feladat azt írja, hogy a spirál mentén a számok (tehát a nem-0 értékek) követik az 1..m ciklust; a 0-k nem számok, kihagyhatók. Ha a megszorítás kötelező v, akkor az csak akkor érvényes, ha épp v_next == v; különben az adott feltétel miatt nincs megoldás az adott elágazásban. (A tesztesetek ezt a logikát erősítik.)

1.5 Visszalépéses keresés (DFS)
- A positions listán lépünk sorban (i=0..n^2-1), fent definiált két ággal (helyez/skip), megkötés esetén szűkebb.
- Elágazáskor frissítjük a row_used/col_used bitmaszkokat és számlálókat.
- A levél (i == n^2) esetén akkor fogadjuk el a táblát, ha
	- globálisan s == n*m (pontosan n*m nem-0 lett elhelyezve), és
	- minden sor_count és oszlop_count éppen m.

1.6 Megoldás konstruálása
- Az assignments :: map {(r,c) -> v} állapotból a végén n×n listát építünk, hiányzó cellákba 0.

2) Miért jó ez a bontás, és miért oldja meg a problémát?
- A spirális sorrend előállítása rögzíti az 1..m ciklus helyes időzítését: a s (eddig elhelyezett) számok száma egyértelművé teszi az aktuálisan tehető v_next értéket. Így a globális spirális feltételt lokálisan, lépésről lépésre biztosítjuk.
- A sor/oszlop feltétel lokálisan, a bitmaszkos ellenőrzéssel és számlálókkal biztosítható; a keresés így csak a kikényszerített helyekre tesz értéket, máshol 0-t hagyhat.
- A megszorításokat pozícióra és indexre is előkészítve gyorsan kizárjuk a nyilvánvaló ellentmondásokat.
- A DFS garantálja, hogy az összes kombinációt bejárjuk, de a lokális szabályokkal drasztikusan csökkentjük a keresési teret.

3) Implementációs döntések
3.1 Adatszerkezetek
- positions :: [{row,col}] – a spirál sorrendje (lista).
- constraints_by_pos :: %{ {r,c} => v } – gyors kényszerérték lekérdezés cella szerint.
- (Opcionális) constraints_by_index :: %{ i => v } – ha index szerint is hasznos.
- assignments :: %{ {r,c} => v } – csak a nem-0 értékeket tároljuk.
- row_used, col_used :: tuple() – soronként/oszloponként m bites egész (bitmaszk). A tuple-t elem/put_elem műveletekkel kezeljük O(1)-ben.
- row_count, col_count :: tuple() – sor/oszlop nem-0 darabszám azonnali ellenőrzéshez.

3.2 Algoritmusok
- build_spiral_positions(n): réteges spirál generálás (top..bottom + left..right határok tologatása). A széleket megfelelő irányban járjuk végig, majd rekurzív/aniteratív beszűkítés.
- DFS(rest_positions, s, state):
	- Ha nincs több pozíció: akkor csak akkor jó, ha s==n*m és minden count==m.
	- Különben nézzük a fej pozíciót. Számoljuk v_next-et.
	- Ha van kényszer (forced_val):
		- ha forced_val == v_next és tehető a sor/oszlop szabályok szerint: tegyük és menjünk tovább.
		- különben: nincs megoldás ebből az állapotból.
	- Ha nincs kényszer: két ág: place v_next (ha tehető), vagy skip (0).
- A bitmaszkokkal a „v már szerepelt?” ellenőrzés és a felvétel O(1), a számolók is O(1), így egy lépés olcsó.

3.3 Optimalizációk
- Kapacitás-pruning (opcionális, később): előre számolt suffix tömbök (row_suffix, col_suffix), melyek megadják, hogy az i..vég tartományban hány pozíció tartozik egy adott sorhoz/oszlophoz. Ha egy sorban/oszlopban már x nem-0 van, de a hátralévő helyek száma < (m - x), az ág kizárható.
- Konstraint-igazítás lookahead (opcionális, később): a következő kényszerindexig megállapítjuk, hogy a v_next megfelelően „eltolható-e” skip-ekkel (0-kal), hogy a kötelező érték pont jó moduló fázisban legyen.
- Memoizáció (óvatosan): csak kis állapotrész memoizálható értelmesen (például i, row_used[r], col_used[c], s), de az állapottér gyorsan nagy. Először a fenti két pruning bőven elég lehet.
- Adatszerkezet: positions listát tuple-lé alakítani és indexeléssel (elem/2) elérni gyorsabb lehet, ha gyakran kell közbenső elem; de a DFS-ben a lista fejének elvétele olcsó, ezért a lista jó választás.

3.4 Helyesség vs. teljesítmény
- Első körben a helyes megoldások generálása a cél (tesztesetek). Ehhez elég a spirál, a v_next logika, a bitmaszkok, számlálók és a kényszerek kezelése.
- Ha futásidő gond lenne nagyobb n/m mellett, bekapcsoljuk a kapacitás-pruningot és/vagy a kényszer-igazítás lookaheadot.

3.5 Eredmény formátum
- Minden megoldás egy n×n lista-lista.
- A 0 érték marad üresnek, más érték 1..m közé esik.
- A megoldásokat akár rendezhetjük is a tesztesetek összehasonlíthatósága végett, de a feladat tetszőleges sorrendet enged.

4) Tesztelés a mellékelt példákkal
- A `Nhf1Kiadott` blokkban szereplő tesztkészletet futtatva ellenőrizzük az implementációt.
- Első körben a „pruning nélküli” korrektségi megoldás; ezt követően finomíthatunk.

5) Hibaforrások és óvintézkedések
- Spirál sorrend: irányok és belső négyzet határainak helyes léptetése (külön figyelem cyclops-esetek: 1 sor/oszlop marad).
- Indexelés: sor/oszlop 1-indexelt, a belső tárolások 0-indexesek (bitmaszk offset), erre figyelni kell.
- Megszorítás: ha forced_val adott, de a spirál fázisa (v_next) nem egyezik, és nem engedünk skip-et, akkor túl korán kizárunk; helyes elv: a forced csak akkor elhelyezhető, ha pont jó a fázis, különben az az ág bukik – de más ágakon a skip-ek miatt még igazítható.
- Végfeltétel: s==n*m és minden row/col count==m; különben lehet „félig kész” tábla, amit nem szabad megoldásnak tekinteni.

6) Időkomplexitás és várható teljesítmény
- A legrosszabb eset exponenciális, de a sor/oszlop egyediség és a spirál-ciklus erős korlátozások.
- A tipikus n (<=9-10) és m (<=n) mellett a tesztek alapján jól kezelhető keresési tér várható.

