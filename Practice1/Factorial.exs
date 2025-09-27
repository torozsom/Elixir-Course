defmodule Factorial do
  @moduledoc """
  Module to compute factorial of a number using recursion.
  Demonstrates both plain recursion and tail recursion.
  """

  @doc """
  Computes the factorial of an integer `n`.

  ## Examples

      iex> Factorial.factorial(5)
      120
      iex> Factorial.factorial(0)
      1
      iex> Factorial.factorial(-3)
      ** (ArgumentError) factorial is undefined for negative numbers
  """
  @spec factorial(integer()) :: integer()
  # Negative input case
  def factorial(n) when n < 0,
    do: raise(ArgumentError, "factorial is undefined for negative numbers")
  # Base case: factorial of 0 is 1.
  def factorial(0), do: 1
  # Recursive case: n! = n * (n-1)!
  def factorial(n) when n > 0, do: n * factorial(n - 1)



  @doc """
  Computes the factorial of an integer `n` using tail recursion.

  Tail recursion is memory-efficient because the BEAM VM
  reuses the same stack frame (tail call optimization).

  ## Examples

      iex> Factorial.fac(6)
      720
      iex> Factorial.fac(0)
      1
  """
  @spec fac(integer()) :: integer()
  # Negative input case
  def fac(n) when n < 0,
    do: raise(ArgumentError, "factorial is undefined for negative numbers")
  # Public function starts the tail-recursive computation with an accumulator of 1.
  def fac(n), do: fac(n, 1)

  @spec fac(integer(), integer()) :: integer()
  # Base case: when n is 0, return the accumulator.
  defp fac(0, acc), do: acc
  # Recursive case: n! = n * (n-1)! (using accumulator).
  defp fac(n, acc), do: fac(n - 1, n * acc)

end


# Example usage:
IO.inspect(Factorial.factorial(5), label: "Factorial of 5")
IO.inspect(Factorial.factorial(0), label: "Factorial of 0")

IO.inspect(Factorial.fac(6), label: "Tail-recursive Factorial of 6")
IO.inspect(Factorial.fac(0), label: "Tail-recursive Factorial of 0")
