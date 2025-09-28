# Fibonacci hét változatban

A Fibonacci-számok jól ismert definíciója:

$F_0 = 0,\quad F_1 = 1,\quad F_i = F_{i-2} + F_{i-1} \text{ ha } i > 1$

Az alábbiakban több, egymástól eltérő megvalósítást mutatunk be Elixirben — a naív rekurziótól a dinamikus programozásig és hely-optimalizált iterációig.

## 1) Naív rekurzió (fa rekurzió)

Idő: O(2^n) • Tár: O(2^n)

```elixir
defmodule Fib do
  # Tree recursion
  @spec fib(i :: integer()) :: n :: integer()
  def fib(0), do: 0
  def fib(1), do: 1
  def fib(i), do: fib(i - 1) + fib(i - 2)
end

# Példa
Fib.fib(23)
```

Kimenet:

```text
28657
```

## 2) Memoizáció (top-down DP)

Idő: O(n) • Tár: O(n)

```elixir
defmodule FibM do
  # Memoization (top down) – dinamikus programozás
  @spec fib_mem(i :: integer()) :: n :: integer()
  def fib_mem(i), do: fib_m(i, %{0 => 0, 1 => 1}) |> elem(0)

  @type mem() :: %{index :: integer() => value :: integer()}
  @spec fib_m(i :: integer(), mem :: mem()) :: {n :: integer(), uj_mem :: mem()}
  def fib_m(i, mem) do
    case mem[i] do
      nil ->
        {prev, memp} = fib_m(i - 2, mem)
        {curr, memc} = fib_m(i - 1, memp)
        val = prev + curr
        {val, Map.put(memc, i, val)}

      val ->
        {val, mem}
    end
  end
end

# Példa
FibM.fib_mem(63)
```

Kimenet:

```text
6557470319842
```

## 3) Tabuláció (bottom-up DP) – Map

Idő: O(n) • Tár: O(n)

```elixir
defmodule FibT do
  # Tabulation (bottom-up) – dinamikus programozás
  @spec fib_tab(i :: integer()) :: n :: integer()
  def fib_tab(i), do: fib_t(i, 2, %{0 => 0, 1 => 1})

  @type tab() :: %{index :: integer() => value :: integer()}

  @spec fib_t(i :: integer(), j :: integer(), tab :: tab()) :: n :: integer()
  def fib_t(i, j, tab) when i < j, do: tab[i]
  def fib_t(i, j, tab) do
    tab0 = Map.put(tab, j, tab[j - 2] + tab[j - 1])
    fib_t(i, j + 1, tab0)
  end
end

# Példa
FibT.fib_tab(63)
```

Kimenet:

```text
6557470319842
```

## 4) Tabuláció – Erlang :array

Idő: O(n) • Tár: O(n)

```elixir
defmodule FibAerl do
  # Tabulation (bottom-up) – dinamikus programozás, Erlang :array
  @spec fib_tab(i :: integer()) :: n :: integer()
  def fib_tab(i), do: fib_t(i, 2, :array.set(1, 1, :array.set(0, 0, :array.new())))

  # Megjegyzés: a typespec itt illusztratív jellegű
  @type tab(integer) :: any()

  @spec fib_t(i :: integer(), j :: integer(), tab :: tab(integer())) :: n :: integer()
  def fib_t(i, j, tab) when i < j, do: :array.get(i, tab)
  def fib_t(i, j, tab) do
    prev = :array.get(j - 2, tab)
    curr = :array.get(j - 1, tab)
    tab0 = :array.set(j, prev + curr, tab)
    fib_t(i, j + 1, tab0)
  end
end

# Példa
FibAerl.fib_tab(1023)
```

Kimenet (részletként, nagyon nagy szám):

```text
2785293550699592923938812412668093509353307352123703806913182668987369503203465183625616759613324452749958549669966882191
```

## 5) Tabuláció – Elixir Array (illusztratív)

Idő: O(n) • Tár: O(n)

```elixir
defmodule FibAex do
  # Tabulation (bottom-up) – dinamikus programozás, Elixir Array
  @spec fib_tab(i :: integer()) :: n :: integer()
  def fib_tab(i), do: fib_t(i, 2, Arrays.new([0, 1]))

  @type tab(integer) :: any()

  @spec fib_t(i :: integer(), j :: integer(), tab :: tab(integer)) :: n :: integer()
  def fib_t(i, j, tab) when i < j, do: Arrays.get(tab, i)
  def fib_t(i, j, tab) do
    prev = Arrays.get(tab, j - 2)
    curr = Arrays.get(tab, j - 1)
    tab0 = Arrays.append(tab, prev + curr)
    fib_t(i, j + 1, tab0)
  end
end

# Példa
FibAex.fib_tab(1023)
```

Kimenet (részletként, nagyon nagy szám):

```text
2785293550699592923938812412668093509353307352123703806913182668987369503203465183625616759613324452749958549669966882191
```

## 6) Tabuláció – Lista alapú

Idő: O(n) • Tár: O(n)

```elixir
defmodule FibLtab do
  # Tabulation (bottom-up) – dinamikus programozás, Elixir List
  @spec fib_tab(i :: integer()) :: n :: integer()
  def fib_tab(i), do: fib_t(i, 2, [1, 0])

  @type tab(integer) :: any()

  @spec fib_t(i :: integer(), j :: integer(), tab :: tab(integer)) :: n :: integer()
  def fib_t(i, j, tab) when i < j, do: hd(tab)
  def fib_t(i, j, tab) do
    prev = hd(tl(tab))
    curr = hd(tab)
    tab0 = [prev + curr | tab]
    fib_t(i, j + 1, tab0)
  end
end

# Példa
FibLtab.fib_tab(63)
```

Kimenet:

```text
6557470319842
```

## 7) Iteratív, hely-optimalizált (O(1) tár)

Idő: O(n) • Tár: O(1)

```elixir
defmodule FibI do
  # Space optimized (bottom up)
  @spec fib_iter(i :: integer()) :: n :: integer()
  def fib_iter(i), do: fib_i(i, 1, 0)

  @spec fib_i(i :: integer(), curr :: integer(), prev :: integer()) :: n :: integer()
  defp fib_i(0, _curr, prev), do: prev
  defp fib_i(1, curr, _prev), do: curr
  defp fib_i(i, curr, prev), do: fib_i(i - 1, prev + curr, curr)
end

# Példa
FibI.fib_iter(2203)
```

Kimenet (részletként, nagyon nagy szám):

```text
1122758802217805139807062374577053774698103216103328357864188914950437190254759573354894973127917403652055351021118529152
```

## 8) Memoizációs lépések megjelenítése (memória visszaadása)

```elixir
defmodule FibMm do
  @spec fib_mem(i :: integer()) :: mem :: %{integer() => integer()}
  def fib_mem(i), do: FibM.fib_m(i, %{0 => 0, 1 => 1}) |> elem(1)
end

# Példa
FibMm.fib_mem(5)
```

Kimenet:

```text
%{0 => 0, 1 => 1, 2 => 1, 3 => 2, 4 => 3, 5 => 5}
```

## 9) Livebook/Kino interaktív bemenet példa

```elixir
# Interaktív bemenet (n slider); önálló cellába kell rakni
cell = Kino.Input.number("Fibonacci index", default: 10, min: 0, max: 35)
# Bemenet beolvasása
index =
  cell
  |> IO.inspect(label: "Kino input cell")
  |> Kino.Input.read()
  |> IO.inspect(label: "Kino input read")
```

Minta kimenet:

```text
Kino input cell: %Kino.Input{ ... }
Kino input read: 10
10
```

Tábla előállítása (Explorer):

```elixir
mem = FibMm.fib_mem(index)
Explorer.DataFrame.new(Enum.map(mem, fn {k, v} -> %{index: k, value: inspect(%{k => v})} end))
```

## 10) Tabuláció debug-olva (dbg/1)

```elixir
defmodule FibTdbg do
  # Tabulation (bottom-up) – dinamikus programozás
  @spec fib_tab(i :: integer()) :: n :: integer()
  def fib_tab(i), do: fib_t(%{0 => 0, 1 => 1}, 2, i)

  @type fib() :: %{index :: integer() => value :: integer()}

  @spec fib_t(mem :: fib(), j :: integer(), i :: integer()) :: n :: integer()
  def fib_t(tab, j, i) when j > i, do: tab[i]
  def fib_t(tab, j, i) do
    tab
    |> Map.put(j, tab[j - 1] + tab[j - 2])
    |> fib_t(j + 1, i)
    |> dbg()
  end
end

# Példa
FibTdbg.fib_tab(8)
```

Kimenet:

```text
21
6
```
