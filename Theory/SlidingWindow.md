# Csúszóablakos technika és kihagy-bevesz rekurzió

Ez a jegyzet a csúszóablakos (sliding window) problémamegoldási mintát és a kihagy-bevesz (include-exclude) rekurziót mutatja be, példákkal és Elixir kóddal.

> Ahol értelmes, a REPL/Livebook kimeneteket külön „Kimenet” blokkokban mutatjuk.

## Előkészület (opcionális)

```elixir
Mix.install([
  {:benchee, "~> 1.3"}
])
```

---

## Számlista elejétől kezdődő folytonos részlistái

```elixir
defmodule Reszlistak0 do
  def reszlistak([x | xs]), do: reszlistak(xs, [x], [[x]])
  def reszlistak([]), do: []
  def reszlistak([y | ys], ss, zss) do
    ss_uj = [y | ss]
    reszlistak(ys, ss_uj, [Enum.reverse(ss_uj) | zss])
  end
  def reszlistak([], _ss, zss), do: zss
end

# Példa
Reszlistak0.reszlistak([1, 2, 3, 4, 5]) |> Enum.reverse()
```

Kimenet:

```text
[[1], [1, 2], [1, 2, 3], [1, 2, 3, 4], [1, 2, 3, 4, 5]]
```

---

## Számlista összes folytonos részlistája

```elixir
defmodule Reszlistak1 do
  def reszlistak([_x | _xs] = xxs), do: reszlistak(xxs, [])
  def reszlistak([_x | xs] = xxs, zss) do
    reszlistak(xs, Reszlistak0.reszlistak(xxs) ++ zss)
  end
  def reszlistak([], zss), do: zss
end

# Példa
Reszlistak1.reszlistak([1, 2, 3, 4, 5]) |> Enum.reverse()
```

Kimenet (részlet):

```text
[
  [1],
  [1, 2],
  [1, 2, 3],
  [1, 2, 3, 4],
  [1, 2, 3, 4, 5],
  [2],
  [2, 3],
  [2, 3, 4],
  [2, 3, 4, 5],
  [3],
  ...
]
```

---

## Számlista összes folytonos részlistája és ezek összege

```elixir
defmodule Reszlistak2 do
  def reszlistak(xs), do: reszlistak(Reszlistak1.reszlistak(xs), [])
  def reszlistak([xs | xss], zss), do: reszlistak(xss, [{Enum.sum(xs), xs} | zss])
  def reszlistak([], zss), do: zss
end

# Példa
Reszlistak2.reszlistak([1, 2, 3, 4, 5]) |> Enum.reverse()
```

Kimenet (részlet):

```text
[
  {5, [5]},
  {9, [4, 5]},
  {4, [4]},
  {12, [3, 4, 5]},
  ...
]
```

---

## Számlista max. összegű folytonos részlistái

```elixir
defmodule Reszlistak3 do
  def reszlistak(xs), do: reszlistak(Reszlistak1.reszlistak(xs), 0, [])
  def reszlistak([xs | xss], max, zss) do
    sum = Enum.sum(xs)
    cond do
      sum > max -> reszlistak(xss, sum, [xs])
      sum == max -> reszlistak(xss, max, [xs | zss])
      true -> reszlistak(xss, max, zss)
    end
  end
  def reszlistak([], max, zss), do: {max, zss}
end

# Példa
Reszlistak3.reszlistak([1, 2, 3, 4, 5])
Reszlistak3.reszlistak([1, 2, 3, 4, -10, 4, 3, 2, 1])
```

Kimenet:

```text
{15, [[1, 2, 3, 4, 5]]}
{10, [[1, 2, 3, 4], [1, 2, 3, 4, -10, 4, 3, 2, 1], [4, 3, 2, 1]]}
```

---

## Számlista elejétől kezdődő folytonos részlistái és összegük

```elixir
defmodule Reszlistak0ossz do
  def reszlistak([x | xs]), do: reszlistak(xs, [x], [{x, [x]}])
  def reszlistak([]), do: []
  def reszlistak([y | ys], ss, zss) do
    ss_uj = [y | ss]
    reszlistak(ys, ss_uj, [{Enum.sum(ss_uj), Enum.reverse(ss_uj)} | zss])
  end
  def reszlistak([], _ss, zss), do: zss
end

# Példa
Reszlistak0ossz.reszlistak([1, 2, 3, 4, 5]) |> Enum.reverse()
Reszlistak0ossz.reszlistak([1, 2, 3, -3, -2, 5]) |> Enum.reverse()
```

Kimenet (részlet):

```text
[
  {1, [1]},
  {3, [1, 2]},
  {6, [1, 2, 3]},
  {10, [1, 2, 3, 4]},
  {15, [1, 2, 3, 4, 5]}
]
```

---

## Számlista elejétől kezdődő, max. összegű folytonos részlistái

```elixir
defmodule Reszlistak0max do
  def reszlistak([x | xs]), do: reszlistak(xs, [x], x, [[x]])
  def reszlistak([]), do: []
  def reszlistak([y | ys], ss, max, zss) do
    ss_uj = [y | ss]
    ss_uj_rev = Enum.reverse(ss_uj)
    sum = Enum.sum(ss_uj_rev)
    cond do
      sum > max -> reszlistak(ys, ss_uj, sum, [ss_uj_rev])
      sum == max -> reszlistak(ys, ss_uj, max, [ss_uj_rev | zss])
      true -> reszlistak(ys, ss_uj, max, zss)
    end
  end
  def reszlistak([], _ss, max, zss), do: {max, Enum.reverse(zss)}
end

# Példa
Reszlistak0max.reszlistak([1, 2, 3, -3, -2, 5])
Reszlistak0max.reszlistak([6, -6, 1, 2, 3, -3, -2, 5])
```

Kimenet:

```text
{6, [[1, 2, 3], [1, 2, 3, -3, -2, 5]]}
{6, [[6], [6, -6, 1, 2, 3], [6, -6, 1, 2, 3, -3, -2, 5]]}
```

---

## Alternatíva: Elejétől kezdődő max. részlisták „take”-kel

```elixir
defmodule Reszlistak0maxTake do
  def reszlistak(xs), do: reszlistak(xs, length(xs) - 1, Enum.sum(xs), [xs])
  def reszlistak(_xs, 0, max, zss), do: {max, zss}
  def reszlistak(xs, len, max, zss) do
    ss = Enum.take(xs, len)
    sum = Enum.sum(ss)
    cond do
      sum > max -> reszlistak(xs, len - 1, sum, [ss])
      sum == max -> reszlistak(xs, len - 1, max, [ss | zss])
      true -> reszlistak(xs, len - 1, max, zss)
    end
  end
end

# Példa
Reszlistak0maxTake.reszlistak([1, 2, 3, -3, -2, 5])
Reszlistak0maxTake.reszlistak([6, -6, 1, 2, 3, -3, -2, 5])
```

---

## Számlista max. összegű folytonos részlistái (globálisan)

```elixir
defmodule Reszlistak3max do
  # Reszlistak0max.reszlistak/1 segédfüggvény beégetve
  def reszlistak([_x | xs] = xxs), do: reszlistak(xs, Reszlistak0max.reszlistak(xxs))
  def reszlistak([]), do: {}
  def reszlistak([_y | ys] = yys, {maxsum, zss}) do
    {max, mss} = Reszlistak0max.reszlistak(yys)
    cond do
      max > maxsum -> reszlistak(ys, {max, mss})
      max == maxsum -> reszlistak(ys, {maxsum, zss ++ mss}) # hatékonyság vs. sorrend!
      true -> reszlistak(ys, {maxsum, zss})
    end
  end
  def reszlistak([], maxlists), do: maxlists
end

# Példa
Reszlistak3max.reszlistak([1, 2, 3, 4, 5])
Reszlistak3max.reszlistak([1, 2, 3, 4, -10, 4, 3, 2, 1])
```

---

## Paraméterezhető segédfüggvénnyel (higher-order)

```elixir
defmodule Reszlistak3mxrls do
  # Számlista elejétől kezdődő, folytonos, max. összegű részlistákat előállító
  # segédfüggvény mxrls paraméterként átadva
  def reszlistak(mxrls, [_x | xs] = xxs), do: reszlistak(mxrls, xs, mxrls.(xxs))
  def reszlistak(_mxrls, []), do: {}
  def reszlistak(mxrls, [_y | ys] = yys, {maxsum, zss}) do
    {max, mss} = mxrls.(yys)
    cond do
      max > maxsum -> reszlistak(mxrls, ys, {max, mss})
      max == maxsum -> reszlistak(mxrls, ys, {maxsum, zss ++ mss}) # hatékonyság vs. sorrend!
      true -> reszlistak(mxrls, ys, {maxsum, zss})
    end
  end
  def reszlistak(_mxrls, [], maxlists), do: maxlists
end

# Példák
(&Reszlistak0max.reszlistak/1) |> Reszlistak3mxrls.reszlistak([1, 2, 3, 4, 5])
(&Reszlistak0max.reszlistak/1) |> Reszlistak3mxrls.reszlistak([1, 2, 3, 4, -10, 4, 3, 2, 1])
(&Reszlistak0maxTake.reszlistak/1) |> Reszlistak3mxrls.reszlistak([1, 2, 3, 4, 5])
(&Reszlistak0maxTake.reszlistak/1) |> Reszlistak3mxrls.reszlistak([1, 2, 3, 4, -10, 4, 3, 2, 1])
```

---

## Véletlen példa generálása

```elixir
randomlist =
  (for n <- 1..10, do: (if rem(n, 3) == 0, do: -1, else: 1) * Enum.random(1..5))
  |> IO.inspect()

(&Reszlistak0max.reszlistak/1) |> Reszlistak3mxrls.reszlistak(randomlist)
```

Minta kimenet:

```text
[3, 3, -1, 2, 4, -3, 4, 3, -5, 3]
{15, [[3, 3, -1, 2, 4, -3, 4, 3]]}
```

---

## Kihagy-bevesz (include-exclude) rekurzió – Kombinációk

```elixir
defmodule Kombinaciok do
  def komb(ns), do: komb(ns, [])
  defp komb([n | ns], acc) do
    komb(ns, acc) ++ komb(ns, [n | acc])
  end
  defp komb([], acc), do: [acc]
end

# Példa
Kombinaciok.komb([1, 2, 3]) |> Enum.sort()
```

Kimenet:

```text
[[], [1], [2], [2, 1], [3], [3, 1], [3, 2], [3, 2, 1]]
```

---

## Összeg „testvéries” elosztása (CEOI’1995)

Feladat: az érméket két ember között úgy elosztani, hogy az összegek különbségének abszolút értéke minimális legyen.

```elixir
defmodule ElosztS do
  def sort(ls), do: Enum.sort(ls, fn a, b -> b < a end)
  @type p_int() :: integer()
  @type my_map() :: %{[p_int()] => p_int()}
  @spec max_osszegek(map :: my_map()) :: resmap :: my_map()
  def max_osszegek(map) do
    maxval = Enum.max(Map.values(map))
    for {k, v} <- map, v == maxval, into: %{}, do: {k, v}
  end
end

# Megoldás

defmodule Eloszt do
  @spec eloszt(vals :: [ElosztS.p_int()]) :: map :: ElosztS.my_map()
  def eloszt([_, _ | _] = vals) do
    tot = Enum.sum(vals) |> IO.inspect(label: "Listaösszeg")
    tgt = div(tot, 2) |> IO.inspect(label: "Célérték")
    eloszt(Map.new(), vals, tgt, [], 0)
    |> ElosztS.max_osszegek()
  end
  def eloszt(_), do: "A listának legalább kételeműnek kell lennie."

  @spec eloszt(map :: ElosztS.my_map(), vals :: [ElosztS.p_int()], tgt :: ElosztS.p_int(), curr :: [ElosztS.p_int()], sum :: ElosztS.p_int()) :: ElosztS.my_map()
  defp eloszt(map, [val | vals], tgt, curr, sum) do
    curr_new = [val | curr]
    sum_new = sum + val

    (if sum_new <= tgt, do: Map.put(map, curr_new, sum_new), else: map)
    |> eloszt(vals, tgt, curr_new, sum_new) # 1. ág: val-t bevesszük
    |> eloszt(vals, tgt, curr, sum)         # 2. ág: val-t kihagyjuk
  end
  defp eloszt(map, [], _tgt, _curr, _sum), do: map
end

# Példák
Eloszt.eloszt([28, 7, 11, 8, 9, 7, 27])
Eloszt.eloszt([1, 2, 3, 4, 5])
Eloszt.eloszt([4, 1, 2, 5, 3])
Eloszt.eloszt([4, 1, 2, 5, 6, 3, 7])
```

Minta kimenetek (részlet):

```text
Listaösszeg: 97
Célérték: 48
%{[9, 11, 28] => 48}

Listaösszeg: 15
Célérték: 7
%{[4, 2, 1] => 7, [4, 3] => 7, [5, 2] => 7}

Listaösszeg: 28
Célérték: 14
%{ ... több megoldás ... }
```
