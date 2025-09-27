# Basics.exs
# =============================================================================
# Functional Programming in Elixir
#
# Run:
#   elixir Basics.exs
#
# Or inside IEx:
#   iex -S mix
#   iex> c("Basics.exs")
# =============================================================================



# -----------------------------------------------------------------------------
# 1) Anonymous functions and the pipe operator: |>
# -----------------------------------------------------------------------------
# The value on the left is passed as the *first argument* to the function
# on the right-hand side.
#
#   a |> f()   is equivalent to   f(a)

sum_of_doubles =
  [1, 2, 3]
  |> Enum.map(&(&1 * 2))  # &(&1 * 2) is equivalent to `fn x -> x * 2 end` which
  |> Enum.sum()

IO.inspect(sum_of_doubles, label: "sum_of_doubles (should be 12)")

# &(.....) is the "capture operator" to create anonymous functions
# &1, &2, ... are the arguments of that anonymous function
# alternatively, we could write: Enum.map(fn x -> x * 2 end)
# or if we have a multiple-arity function: Enum.map(fn x -> foo(x, 2) end)
# or with capture: Enum.map(&foo(&1, 2))



# -----------------------------------------------------------------------------
# 2) Functions, private helpers, clauses, and guards
# -----------------------------------------------------------------------------

defmodule Functions do
  @moduledoc """
  Different ways to define functions (public/private, multiple clauses, guards).
  """

  def foo1() do
    1 + 3
  end

  def foo2(), do: 1 + 3


  def foo3(x) do
    x + 3
  end

  def foo4(x), do: x + 3


  def foo5(x, y) do
    x + y
  end

  def foo6(x, y), do: x + y


  @doc "Adds `x` and `y`, then doubles the result via a private helper."
  def sum_and_double(x, y), do: double(x + y)
  defp double(z), do: z * 2


  @doc """
  Absolute value with a guard.

  ## Examples

      iex> Functions.abs(-5)
      5
      iex> Functions.abs(7)
      7
  """
  def abs(x) when x < 0, do: -x
  def abs(x), do: x
end


IO.inspect(Functions.foo1(), label: "Functions.foo1()")
IO.inspect(Functions.foo3(2), label: "Functions.foo3(2)")
IO.inspect(Functions.foo5(2, 3), label: "Functions.foo5(2,3)")
IO.inspect(Functions.sum_and_double(2, 3), label: "sum_and_double(2,3)")
IO.inspect(Functions.abs(-7), label: "abs(-7)")



# -----------------------------------------------------------------------------
# 3) Module docs, @spec and custom @type
# -----------------------------------------------------------------------------

defmodule Basics do
  @moduledoc """
  Demonstrates module/function documentation and type specifications.
  """

  @type myint :: integer() # custom type alias

  @doc "Increments an integer by 1."
  @spec func1(myint()) :: myint()
  def func1(p1), do: p1 + 1


  @doc "Same as `func1/1`, shown with a more compact @spec."
  @spec func2(integer()) :: integer()
  def func2(p1), do: p1 + 1
end


IO.inspect(Basics.func1(41), label: "Basics.func1(41)")
IO.inspect(Basics.func2(-2), label: "Basics.func2(-2)")



# -----------------------------------------------------------------------------
# 4) Strings vs. charlists (and conversions)
# -----------------------------------------------------------------------------

string = "Hello"
charlist = 'abc'
charlist_via_sig = ~c"abc"
string_via_sig  = ~s'abc'

IO.inspect(to_charlist("almárium"), label: "to_charlist/1")
IO.inspect(to_string(~c"almárium"), label: "to_string/1")

IO.inspect(string, label: "string")
IO.inspect(charlist, label: "charlist")
IO.inspect(charlist_via_sig, label: "charlist_via_sig")
IO.inspect(string_via_sig, label: "string_via_sig")

cl = ~c"abc"
[chead | ctail] = cl
IO.inspect({chead, ctail}, label: "{head, tail} of charlist")
IO.puts("codepoint of 'a' is ?a = #{?a}")



# -----------------------------------------------------------------------------
# 5) Pin operator (^) and type guards
# -----------------------------------------------------------------------------

x = 1
result =
  case {1, 2} do
    {^x, y} -> {:matched_first_equals_x, y}
    _ -> :nope
  end

IO.inspect(result, label: "pin operator result")


defmodule TypesDemo do
  @moduledoc """
  Guards with type-checking functions (`is_integer/1`, `is_list/1`, etc.).
  """

  @doc """
  Adds two integers. Returns `{:error, :integers_only}` otherwise.
  """
  @spec add_ints(term(), term()) :: integer() | {:error, :integers_only}
  def add_ints(a, b) when is_integer(a) and is_integer(b), do: a + b
  def add_ints(_, _), do: {:error, :integers_only}
end


IO.inspect(TypesDemo.add_ints(2, 3), label: "add_ints(2,3)")
IO.inspect(TypesDemo.add_ints(2, 3.0), label: "add_ints(2,3.0)")



# -----------------------------------------------------------------------------
# 6) Function capture (&) and application
# -----------------------------------------------------------------------------

add = &Functions.foo5/2
IO.inspect(add.(10, 20), label: "&Functions.foo5/2 applied")



# -----------------------------------------------------------------------------
# 7) Idiomatic example (pipe + Enum + pattern matching)
# -----------------------------------------------------------------------------

first_even_or_nil =
  1..10
  |> Enum.filter(&(rem(&1, 2) == 0))
  |> Enum.take(1)
  |> case do
       [x] -> x
       []  -> nil
     end


IO.inspect(first_even_or_nil, label: "first even in 1..10 (or nil)")
