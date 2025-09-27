defmodule LinkedList do
  @moduledoc """
  Basic operations on **singly linked lists** implemented with **recursion**.
  Educational, pattern-matching–focused examples.
  """


  # ---------------------------------------------------------------------------
  # Head and tail
  # ---------------------------------------------------------------------------

  @doc """
  Returns the **head** (first element) of the list, or `nil` if the list is empty.

  ## Examples
      iex> LinkedList.head([1, 2, 3])
      1
      iex> LinkedList.head([])
      nil
  """
  @spec head([any()]) :: any() | nil
  def head([]), do: nil
  def head([head | _]), do: head


  @doc """
  Returns the **tail** (the sublist after the first element), or `nil` for an empty list.

  ## Examples
      iex> LinkedList.tail([1, 2, 3])
      [2, 3]
      iex> LinkedList.tail([])
      nil
  """
  @spec tail(list()) :: list() | nil  # list() is an alias for [any()]
  def tail([]), do: nil
  def tail([_ | tail]), do: tail



  # ---------------------------------------------------------------------------
  # Length and emptiness
  # ---------------------------------------------------------------------------

  @doc """
  Computes the list length using a **simple (non–tail-recursive)** definition.

  ## Examples
      iex> LinkedList.len([:a, :b, :c])
      3
      iex> LinkedList.len([])
      0
  """
  @spec len(list()) :: non_neg_integer()  # list() is an alias for [any()]
  def len([]), do: 0
  def len([_ | tail]), do: 1 + len(tail)


  @doc """
  Computes the list length **tail-recursively** (with an accumulator).

  ## Examples
      iex> LinkedList.len_tr([:a, :b, :c])
      3
      iex> LinkedList.len_tr([])
      0
  """
  @spec len_tr([any()]) :: non_neg_integer()
  def len_tr(list), do: len_tr(list, 0)

  @spec len_tr([any()], non_neg_integer()) :: non_neg_integer()
  defp len_tr([], acc), do: acc
  defp len_tr([_ | tail], acc), do: len_tr(tail, acc + 1)


  @doc """
  Returns `true` if the list is empty.

  ## Examples
      iex> LinkedList.empty?([])
      true
      iex> LinkedList.empty?([1, 2])
      false
  """
  @spec empty?([any()]) :: boolean()
  def empty?([]), do: true
  def empty?(_), do: false



  # ---------------------------------------------------------------------------
  # Last element
  # ---------------------------------------------------------------------------

  @doc """
  Returns the **last element** of the list, or `nil` for an empty list.

  ## Examples
      iex> LinkedList.last([1, 2, 3])
      3
      iex> LinkedList.last([:a])
      :a
      iex> LinkedList.last([])
      nil
  """
  @spec last([any()]) :: any() | nil
  def last([]), do: nil
  def last([x]), do: x
  def last([_ | tail]), do: last(tail)


  # ---------------------------------------------------------------------------
  # Summation — clause order illustration + tail recursion
  # ---------------------------------------------------------------------------

  @doc """
  Sums the list (simple, non–tail-recursive).

  Clause order note: the empty case comes first. In this function it doesn’t
  impact performance because we traverse the whole list anyway.

  ## Examples
      iex> LinkedList.sum1([1,2,3])
      6
      iex> LinkedList.sum1([])
      0
  """
  @spec sum1([number()]) :: number()
  def sum1([]), do: 0
  def sum1([head | tail]), do: head + sum1(tail)


  @doc """
  Same sum, but with the non-empty clause first (for illustration).
  """
  @spec sum2([number()]) :: number()
  def sum2([head | tail]), do: head + sum2(tail)
  def sum2([]), do: 0


  @doc """
  Sums the list **tail-recursively** (accumulator-based).

  ## Examples
      iex> LinkedList.sum_tr([1,2,3,4])
      10
      iex> LinkedList.sum_tr([])
      0
  """
  @spec sum_tr([number()]) :: number()
  def sum_tr(list), do: sum_tr(list, 0)

  @spec sum_tr([number()], number()) :: number()
  defp sum_tr([], acc), do: acc
  defp sum_tr([head | tail], acc), do: sum_tr(tail, acc + head)



  # ---------------------------------------------------------------------------
  # Extra operations: nth / slice / member?
  # ---------------------------------------------------------------------------

  @doc """
  Returns the **n-th element** (0-based), or `nil` if the list is too short
  or `n` is negative.

  ## Examples
      iex> LinkedList.nth([:a,:b,:c], 0)
      :a
      iex> LinkedList.nth([:a,:b,:c], 2)
      :c
      iex> LinkedList.nth([:a,:b,:c], 3)
      nil
      iex> LinkedList.nth([:a,:b,:c], -1)
      nil
  """
  @spec nth([any()], integer()) :: any() | nil
  def nth([], _n), do: nil
  def nth([x | _], 0), do: x
  def nth([_ | xs], n) when is_integer(n) and n > 0, do: nth(xs, n - 1)
  def nth(_xs, _n), do: nil  # negative index falls through here


  @doc """
  Returns a **slice** that starts at index `k` and has length `n`.
  Returns `nil` if not possible (e.g., not enough elements or negative `n`).

  (0-based indexing.)

  ## Examples
      iex> LinkedList.slice([1,2,3,4,5], 1, 3)
      [2,3,4]
      iex> LinkedList.slice([1,2,3,4,5], 4, 1)
      [5]
      iex> LinkedList.slice([1,2,3], 0, 0)
      []
      iex> LinkedList.slice([1,2,3], -2, 2)
      nil
      iex> LinkedList.slice([1,2,3], 2, 5)
      nil
  """
  @spec slice([any()], integer(), integer()) :: [any()] | nil
  def slice(_xs, _k, n) when n < 0, do: nil
  def slice(_xs, 0, 0), do: []

  def slice([x | xs], 0, n) when n > 0, do: [x | slice(xs, 0, n - 1)]
  def slice([_ | xs], k, n) when k > 0, do: slice(xs, k - 1, n)

  def slice([], _k, _n), do: nil
  def slice(_xs, _k, _n), do: nil


  @doc """
  Returns whether a value is **present** in the list.

  ## Examples
      iex> LinkedList.member?([1,2,3], 2)
      true
      iex> LinkedList.member?([1,2,3], 4)
      false
  """
  @spec member?([any()], any()) :: boolean()
  def member?([], _e), do: false
  def member?([e | _], e), do: true
  def member?([_ | xs], e), do: member?(xs, e)



  # ---------------------------------------------------------------------------
  # Reversing and concatenation
  # ---------------------------------------------------------------------------

  @doc """
  Concatenates **two lists** (left to right) using pure recursion.

  ## Examples
      iex> LinkedList.append([1,2], [3,4])
      [1,2,3,4]
      iex> LinkedList.append([], [1])
      [1]
  """
  @spec append([any()], [any()]) :: [any()]
  def append([], ys), do: ys
  def append([x | xs], ys), do: [x | append(xs, ys)]


  @doc """
  Reverses the list **tail-recursively**.

  ## Examples
      iex> LinkedList.rev([1,2,3])
      [3,2,1]
      iex> LinkedList.rev([])
      []
  """
  @spec rev([any()]) :: [any()]
  def rev(xs), do: rev(xs, [])

  @spec rev([any()], [any()]) :: [any()]
  defp rev([], acc), do: acc
  defp rev([x | xs], acc), do: rev(xs, [x | acc])


  @doc """
  `revapp(xs, ys)` = `rev(xs) ++ ys`, but done **efficiently** in one pass.

  ## Examples
      iex> LinkedList.revapp([1,2,3], [10,20])
      [3,2,1,10,20]
  """
  @spec revapp([any()], [any()]) :: [any()]
  def revapp(xs, ys), do: revapp(xs, ys, [])
  defp revapp([], ys, acc), do: append(acc, ys)
  defp revapp([x | xs], ys, acc), do: revapp(xs, ys, [x | acc])



  # ---------------------------------------------------------------------------
  # Bag-style difference
  # ---------------------------------------------------------------------------

  @doc """
  `diff(xs, ys)` returns the elements of `xs` that are **not present** in `ys`.
  Treats the list as a **bag**: equal values count as separate occurrences.

  ## Examples
      iex> LinkedList.diff([1,2,2,3,4], [2,4,5])
      [1,2,3]
      iex> LinkedList.diff([], [1,2])
      []
  """
  @spec diff([any()], [any()]) :: [any()]
  def diff([], _ys), do: []
  def diff([x | xs], ys) do
    if member?(ys, x), do: diff(xs, ys), else: [x | diff(xs, ys)]
  end
end
