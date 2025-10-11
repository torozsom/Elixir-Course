# Terv a ciklikus számlisták feladat megoldásához (végleges)

## 1. Feladat rövid leírása

Generáljunk minden olyan `len` hosszú listát, amelyben az `1..m` számsorozat pontosan `n`-szer fordul elő, ebben a sorrendben, tetszőleges számú közbeszúrt `0`-val, úgy hogy a listában összesen `len - n*m` darab `0` van. A `constraints` megadott indexein előírt értékek szerepelnek.

## 2. Megközelítés: constraints-tudatos rekurzív visszalépés (backtracking)

A végleges megoldás rekurzív generálást alkalmaz, amely pozíciónként dönt arról, hogy `0`-t vagy a következő elvárt sorozatelemet (az `1..m` ciklusban) helyez-e el. A korlátokat (constraints) már a generálás közben ellenőrizzük, így a rossz ágakat korán elvetjük (pruning). Ez hatékonyabb és egyszerűbb, mint az összes lehetséges `0`-kiosztás felsorolása és utólagos szűrése.

Fő ötlet:
- Állapot: `(pos, zeros_left, placed_nonzeros, acc)`.
  - `pos`: 1-alapú aktuális pozíció a teljes listában.
  - `zeros_left`: hátralévő elhelyezhető `0`-k száma.
  - `placed_nonzeros`: eddig elhelyezett nem-0 elemek száma; ebből származik a következő elvárt érték: `expected_val = sequence[placed_nonzeros mod m]`.
  - `acc`: részleges lista fordított sorrendben, hogy a beszúrás O(1) legyen.
- Minden lépésben:
  1. Ha lehet, elhelyezünk `0`-t (és a constraint engedi), majd továbblépünk.
  2. Ha lehet, elhelyezzük a következő elvárt sorozatelemet (és a constraint engedi), majd továbblépünk.
- Végfeltétel: ha `pos > len`, `zeros_left == 0` és `placed_nonzeros == n*m`, továbbá minden constraint teljesül az összeállított listán, akkor a megoldást eltároljuk.

## 3. Miért működik ez a megközelítés?

- A constraints-pruning már a generálás során kiszűri azokat az ágakat, amelyek biztosan nem vezetnek megoldáshoz.
- A `placed_nonzeros` számláló egyszerűen és hibamentesen írja le, hogy hány nem-0 elem került be, és ebből determinisztikusan következik az elvárt következő érték (`1..m` ciklusban).
- Az akkumulátoros építés és a végső megfordítás (reverse) hatékony listakezelést biztosít.

## 4. Használt függvények és szerepük

- `cyclists/2`: belépési pont; előkészíti a `constraints_map`-ot, kiszámolja a `zeros_to_place` értéket, összeállítja a `sequence`-et, majd meghívja a backtracking generátort.
- `backtrack_build/10`: a rekurzív generátor, amely pozíciónként `0`-t vagy `expected_val`-t helyez el a korlátok figyelembevételével, és a végfeltételnél validálja a megoldást.
- `constraints_to_map/1`: a constraints-listát `%{index => value}` map-pé alakítja (1-alapú indexekkel).
- `allows?/3`: ellenőrzi, hogy a feltételek megengedik-e egy adott érték elhelyezését az adott pozíción.
- `constraints_ok?/2`: a teljes jelölt listán ellenőrzi a constraints teljesülését.

## 5. Edge case-ek és megjegyzések

- Az indexelésnél végig 1-alapú `constraints` és 0-alapú `Enum.at` különbségre figyelünk (`index - 1`).
- Ha `len - n*m == 0`, akkor nem lehet `0`-t elhelyezni, ezt a `zeros_left` számláló garantálja.
- Ha bármely constraint ellentmond az elvárt `1..m` ciklusnak a nem-0 helyeken (például más értéket kényszerít oda), az ág azonnal elvágódik.

## 6. Kimenet és rendezés

A generátor az összes valid megoldást előállítja. A visszatérési értékben `Enum.uniq` biztosítja, hogy ne legyenek duplikátumok (bár a korrekt generátor nem termel duplikátumot), a tesztösszehasonlításnál pedig rendezett összevetést használunk.

