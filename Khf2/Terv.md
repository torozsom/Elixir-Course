# Számtekercs feladat – részletes megoldási terv

## 1. Feladat értelmezése és átfogalmazása

A feladat egy n×n-es négyzetes táblán elhelyezett számokkal kapcsolatos. A tábla mezőiben 1 és m közötti számok lehetnek, illetve üres mezők. A cél, hogy a tábla minden sorában és oszlopában az 1..m számok mindegyike pontosan egyszer szerepeljen, és a bal felső sarokból induló, spirálisan ("tekeredő vonal") bejárt mezőkön a számok rendre az 1,2,...,m,1,2,...,m,... sorrendben kövessék egymást. A feladatban egy függvényt kell írni, amely egy szöveges leírás alapján visszaadja a spirál mentén a mezők koordinátáit és értékeit (vagy nil-t, ha nincs érték).

A feladat tehát három fő részre bontható:
- A spirális (tekeredő) bejárás generálása, amely visszaadja a mezők koordinátáit a kívánt sorrendben.
- A szöveges leírás feldolgozása, amelyből kiolvassuk a tábla méretét, a ciklushosszt, és a kitöltött mezők értékeit.
- A kimeneti lista előállítása, amely a spirál mentén sorolja fel a mezőket, minden mezőhöz hozzárendelve a kitöltött értéket vagy nil-t.

## 2. Részfeladatok

### 2.1. Szöveges leírás feldolgozása
- A bemeneti lista első két eleme a tábla mérete (n) és a ciklushossz (m).
- A további elemek a kitöltött mezők: mindegyik egy string, amely három számot tartalmaz (sor, oszlop, érték).
- Ezeket fel kell dolgozni, hogy egy map-et kapjunk, amely kulcsa a mező koordinátája, értéke pedig a mező értéke.

### 2.2. Spirális bejárás generálása
- Egy rekurzív algoritmus, amely egy n×n-es mátrix "külső keretét" bal felső saroktól spirálisan bejárja, majd ugyanezt megteszi a belső (n-2)×(n-2)-es mátrixra, amíg el nem fogy a tábla.
- Az eredmény egy lista, amely a mezők koordinátáit tartalmazza a spirál sorrendjében.

### 2.3. Kimeneti lista előállítása
- A spirál mentén kapott koordinátalistán végigiterálunk, és minden mezőhöz hozzárendeljük a kitöltött értéket (ha van ilyen), különben nil-t.
- Az eredmény egy lista: `[{mező_koord, érték_vagy_nil}, ...]`.

## 3. Miért oldják meg ezek a részfeladatok a problémát?
- A szöveges leírás feldolgozása biztosítja, hogy a bemenetből ki tudjuk nyerni a szükséges információkat.
- A spirális bejárás algoritmusa pontosan a feladatban leírt sorrendet adja vissza, így a kimenet megfelel a követelményeknek.
- A kimeneti lista előállítása összekapcsolja a bejárás sorrendjét a kitöltött értékekkel, így a kívánt formátumot kapjuk.

## 4. Implementációs döntések

### 4.1. Adatszerkezetek
- A kitöltött mezőket egy map-ben tároljuk: kulcs: {sor, oszlop}, érték: szám.
- A spirális bejárás eredménye egy lista: [{sor, oszlop}].
- A végső eredmény egy lista: `[{mező_koord, érték_vagy_nil}]`.

### 4.2. Függvények
- `helix/1`: főfüggvény, amely a bemeneti listából előállítja a kimenetet.
- `parse_input/1`: feldolgozza a szöveges leírást, visszaadja n, m, és a kitöltött mezők map-jét.
- `spiral_coords/1`: generálja a spirális sorrendű koordinátalistát n×n-es táblára.
- `assign_values/2`: a spirális koordinátalistához hozzárendeli a kitöltött értékeket vagy nil-t.

### 4.3. Optimalizálás
- A map-es keresés O(1) időben adja vissza, hogy egy mezőhöz tartozik-e érték.
- A spirális bejárás rekurzív, de minden szinten csak a kerületet járja be, így összesen O(n^2) időben fut.
- A bemenet feldolgozása egyszerű string-feldolgozás, kis bemeneti méret mellett gyors.

### 4.4. Egyéb megfontolások
- A függvények legyenek tisztán funkcionálisak, mellékhatás nélküliek.
- A segédfüggvények legyenek privátak (`defp`).
- A típusdefiníciókat és @spec-eket használjuk a dokumentáció és típusellenőrzés miatt.
- A kód legyen jól olvasható, a lépések világosan elkülönüljenek.
