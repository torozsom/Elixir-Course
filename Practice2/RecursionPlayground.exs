# RecursionPlayground.exs
# =============================================================================
# Recursion styles, guards, and classic list exercises
#
# Run:
#   elixir RecursionPlayground.exs
#
# Notes:
# - Every multi-clause function below includes short comments next to each clause
#   explaining the role of that particular clause (base case / guard / recursive step).
# - Prefer tail recursion for large inputs; use guards when pattern matching alone
#   cannot express the condition (e.g., n >= 0).
# =============================================================================


# -----------------------------------------------------------------------------
# 0) Guards & patterns — factorial as a minimal guard example
# -----------------------------------------------------------------------------

defmodule GuardsDemo do
  @moduledoc """
  Guard examples. In function heads you **cannot** write expressions like `n >= 0`
  as a pattern; use a **guard** instead (`when n >= 0`).

  Allowed in guards: only side-effect-free guard-safe functions (e.g., type checks,
  comparisons, arithmetic). You cannot call arbitrary user functions in guards.
  """

  @doc """
  Simple factorial with a guard ensuring `n >= 0`. Negative input raises.

  ## Examples

      iex> GuardsDemo.fac(0)
      1
      iex> GuardsDemo.fac(5)
      120
  """
  @spec fac(non_neg_integer()) :: pos_integer()
  # base case: 0! = 1
  def fac(0), do: 1
  # guard + step
  def fac(n) when is_integer(n) and n > 0, do: n * fac(n - 1)
  # fallback
  def fac(n), do: raise(ArgumentError, "fac/1 expects n >= 0, got: #{inspect(n)}")
end



# -----------------------------------------------------------------------------
# 1) Printing before vs. after recursion (tail vs. head recursion)
# -----------------------------------------------------------------------------

defmodule UptoBy3 do
  @moduledoc """
  Prints numbers divisible by 3 in the range 1..n in **increasing order**.

  We provide two implementations:
  - `upto_by_3_tail/1`: prints **before** the recursive call (tail recursion pattern).
  - `upto_by_3_head/1`: recurses first (counting **down**), prints **after** to keep
    the output increasing while demonstrating head recursion.
  """

  @doc """
  Tail-recursive version: iterate i = 1..n, print before the tail call.

  ## Example
      iex> UptoBy3.upto_by_3_tail(10)
      :ok
  """
  @spec upto_by_3_tail(non_neg_integer()) :: :ok
  def upto_by_3_tail(n), do: loop(1, n)

  # base: done when i > n
  defp loop(i, n) when i > n, do: :ok

  # step: print if divisible by 3, then tail-call with i+1
  defp loop(i, n) do
    # side effect before recursion
    if rem(i, 3) == 0, do: IO.puts(i)
    # tail call
    loop(i + 1, n)
  end


  @doc """
  Head-recursive version that still prints in **increasing** order.

  Trick: recurse from n down to 1, then print after the recursive return.

  ## Example
      iex> UptoBy3.upto_by_3_head(10)
      :ok
  """
  @spec upto_by_3_head(non_neg_integer()) :: :ok
  def upto_by_3_head(n), do: down(n)

  # base: done at 0
  defp down(0), do: :ok

  # step: recurse first (head recursion), then print on unwind if divisible by 3
  defp down(i) when i > 0 do
    # head recursion
    down(i - 1)
    # side effect after recursion
    if rem(i, 3) == 0, do: IO.puts(i)
  end
end



# -----------------------------------------------------------------------------
# 2) Optional: “middle recursion” demo (work both before and after)
# -----------------------------------------------------------------------------

defmodule MiddleRecursionDemo do
  @moduledoc """
  Demonstrates 'middle recursion': do something, recurse, then do something else.
  This shape cannot be tail-call optimized.
  """

  @doc """
  Logs a simple trace around recursion (pre/ post), then returns :ok.
  """
  @spec trace(non_neg_integer()) :: :ok
  def trace(0) do
    # base: print and finish
    IO.puts("[base] i=0")
    :ok
  end

  def trace(i) when i > 0 do
    # pre-recursion work
    IO.puts("[pre ] i=#{i}")
    # recursion in the middle
    trace(i - 1)
    # post-recursion work
    IO.puts("[post] i=#{i}")
    :ok
  end
end



# -----------------------------------------------------------------------------
# 3) L1 — Split: cut a list into {prefix_of_n, suffix_rest}
# -----------------------------------------------------------------------------

defmodule Split do
  @moduledoc """
  `split(xs, n) :: {prefix, suffix}` without using Enum.split/take/drop to implement it.
  Tail-recursive with an accumulator (we reverse at the end).
  """

  @doc """
  Returns `{first n elements, the rest}`. If `n <= 0` the prefix is `[]`.
  If `n >= length(xs)` the suffix is `[]`.

  ## Examples

      iex> Split.split([10,20,30,40,50], 3)
      {[10,20,30], [40,50]}
      iex> Split.split(~c"egyedem-begyedem", 8) == Enum.split(~c"egyedem-begyedem", 8)
      true
  """
  @spec split([any()], integer()) :: {[any()], [any()]}
  def split(xs, n), do: split(xs, n, [])

  # base: if n <= 0, we're done collecting prefix
  defp split(xs, n, acc) when n <= 0, do: {Enum.reverse(acc), xs}

  # base: ran out of input before n elements
  defp split([], _n, acc), do: {Enum.reverse(acc), []}

  # step: take head into prefix accumulator and decrement n
  defp split([x | xs], n, acc), do: split(xs, n - 1, [x | acc])
end



# -----------------------------------------------------------------------------
# 4) L2 — TakeWhile: maximal prefix satisfying a predicate
# -----------------------------------------------------------------------------

defmodule Take do
  @moduledoc """
  `takewhile(xs, f)` builds the longest prefix for which `f.(x)` is true.
  Tail-recursive with an accumulator (reverse once at the end).
  """

  @doc """
  Returns the prefix of `xs` for which `f` holds, stopping at the first failure.

  ## Examples

      iex> Take.takewhile(~c"abcdefghijkl", fn x -> x < ?f end)
      ~c"abcde"
  """
  @spec takewhile([any()], (any() -> boolean())) :: [any()]
  def takewhile(xs, f), do: takewhile(xs, f, [])

  # step: keep collecting while predicate holds
  defp takewhile([x | xs], f, acc) do
    if f.(x), do: takewhile(xs, f, [x | acc])
  end

  # base: stop on first failure or at end, reverse what we collected
  defp takewhile(xs, _f, acc) when is_list(xs), do: Enum.reverse(acc)
end



# -----------------------------------------------------------------------------
# 5) L3 — DropEvery: drop every n-th element (starting at index 0)
# -----------------------------------------------------------------------------

defmodule Drop do
  @moduledoc """
  `dropevery(xs, n)` removes elements at indices 0, n, 2n, ... (0-based).
  If `n <= 0`, the function returns `xs` unchanged (documented choice).
  """

  @doc """
  Drop every n-th element, counting from index 0.

  ## Examples

      iex> Drop.dropevery(~c"abcdefghijkl", 5)
      ~c"bcdeghijl"
      iex> Drop.dropevery(~c"1234567", 2)
      ~c"246"
  """
  @spec dropevery([any()], integer()) :: [any()]
  # guard: non-positive n → no-op
  def dropevery(xs, n) when not (is_integer(n) and n > 0), do: xs
  def dropevery(xs, n), do: go(xs, 0, n, [])

  # base: end of input → reverse accumulator
  defp go([], _i, _n, acc), do: Enum.reverse(acc)

  # step: drop when index is divisible by n
  defp go([_x | xs], i, n, acc) when rem(i, n) == 0, do: go(xs, i + 1, n, acc)

  # step: keep element otherwise
  defp go([x | xs], i, n, acc), do: go(xs, i + 1, n, [x | acc])
end



# -----------------------------------------------------------------------------
# 6) L4 — Tails: list of progressively shorter suffixes
# -----------------------------------------------------------------------------

defmodule Tails do
  @moduledoc """
  `tails(xs)` returns `[[x1..xn], [x2..xn], ..., [xn], []]`.
  """

  @doc """
  Suffix list including the empty suffix as the last element.

  ## Examples

      iex> Tails.tails([1,4,2])
      [[1,4,2],[4,2],[2],[]]
      iex> Tails.tails([])
      [[]]
  """
  @spec tails([any()]) :: [[any()]]
  # base: empty list → list with empty suffix
  def tails([]), do: [[]]
  # step: prepend current list, recurse on tail
  def tails([_ | xs] = all), do: [all | tails(xs)]
end



# -----------------------------------------------------------------------------
# 7) L5 — Pairs: pair up consecutive elements (1-2, 3-4, ...)
# -----------------------------------------------------------------------------

defmodule Pairs do
  @moduledoc """
  `pairs(xs)` groups elements into consecutive pairs, dropping the last one if odd length.
  """

  @doc """
  Make pairs: [a,b,c,d,...] -> [{a,b},{c,d},...]

  ## Examples

      iex> Pairs.pairs(Enum.to_list(1..6))
      [{1,2},{3,4},{5,6}]
      iex> Pairs.pairs([1])
      []
  """
  @spec pairs([any()]) :: [{any(), any()}]
  # step: form a pair and continue
  def pairs([a, b | xs]), do: [{a, b} | pairs(xs)]
  # base: empty or single element → done
  def pairs(_), do: []
end



# -----------------------------------------------------------------------------
# 8) L6 — Parosan: elements immediately followed by an equal element
# -----------------------------------------------------------------------------

defmodule Parosan do
  @moduledoc """
  Return each element that is immediately followed by an equal element.
  For runs of length k (k >= 2), result contains k-1 copies of that value.
  """

  @doc """
  Examples:

      iex> Parosan.parosan([:a, :a, :a, 2, 3, 3, :a, 2, :b, :b, 4, 4])
      [:a, :a, 3, :b, 4]
      iex> Parosan.parosan([:a, 2, 3, :a, 2, :b, 4])
      []
  """
  @spec parosan([any()]) :: [any()]
  # step: found a pair → take one and shift by one
  def parosan([x, x | xs]), do: [x | parosan([x | xs])]
  # step: no pair at head → skip one
  def parosan([_ | xs]), do: parosan(xs)
  # base: end of list
  def parosan([]), do: []
end



# -----------------------------------------------------------------------------
# 9) Quick checks
# -----------------------------------------------------------------------------

IO.puts("\n-- Quick checks --")

IO.puts(GuardsDemo.fac(5) == 120)

UptoBy3.upto_by_3_tail(10)
UptoBy3.upto_by_3_head(10)

IO.puts(Split.split([10, 20, 30, 40, 50], 3) === {[10, 20, 30], [40, 50]})
IO.puts(Take.takewhile(~c"abcdefghijkl", fn x -> x < ?f end) === ~c"abcde")

IO.inspect(Drop.dropevery(~c"abcdefghijkl", 5) === ~c"bcdeghijl")
IO.inspect(Drop.dropevery(~c"1234567", 2) === ~c"246")
IO.inspect(Drop.dropevery([], 3) === [])

IO.puts(Tails.tails([1, 4, 2]) === [[1, 4, 2], [4, 2], [2], []])
IO.puts(Tails.tails([]) === [[]])

zs = Enum.map(1..10, & &1) |> Pairs.pairs()
IO.puts(zs == [{1, 2}, {3, 4}, {5, 6}, {7, 8}, {9, 10}])

IO.puts(Parosan.parosan([:a, :a, :a, 2, 3, 3, :a, 2, :b, :b, 4, 4]) === [:a, :a, 3, :b, 4])
IO.puts(Parosan.parosan([:a]) === [])
