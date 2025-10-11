defmodule Khf3 do
  @moduledoc """
  Ciklikus számlisták

  @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"

  @date   "2025-10-11"
  """



  @type count() :: integer() # számsorozatok száma, n (1 < n)
  @type cycle() :: integer() # számsorozat hossza, m (1 <= m)
  @type size()  :: integer() # listahossz, len (1 < len)

  @type value() :: integer() # listaelem értéke, val (0 <= val <= m)
  @type index() :: integer() # listaelem sorszáma, ix (1 <= ix <= len)
  @type index_value() :: {index(), value()} # listaelem indexe és értéke



  @spec cyclists({n::count(), m::cycle(), len::size()}, constraints::[index_value()])
    :: results::[[value()]]
  # results az összes olyan len hosszú lista listája, melyekben
  # * az 1-től m-ig tartó számsorozat – ebben a sorrendben, esetleg közbeszúrt 0-kal – n-szer ismétlődik,
  # * len-n*m számú helyen 0-k vannak,
  # * a constraints korlát-listában felsorolt indexű cellákban a megadott értékű elemek vannak.
  def cyclists({num_sequences, seq_length, total_length}, constraints) do
    constraints_map = constraints_to_map(constraints)
    zeros_to_place = total_length - num_sequences * seq_length
    sequence = Enum.to_list(1..seq_length)

    # Pozíciónként vagy 0 vagy a következő elvárt szekvenciaelem.
    backtrack_build(1, total_length, num_sequences, seq_length, zeros_to_place, sequence, constraints_map, 0, [], [])
      |> Enum.uniq()
  end



  # constraints listából map-et készít.
  @spec constraints_to_map([index_value()]) :: %{index() => value()}
  defp constraints_to_map(constraints) do
    Map.new(constraints)
  end


  # A backtrack_build a megoldásokat pozícióról pozícióra építi fel, és minden lépésben
  # két lehetőséget vizsgál: 0 elhelyezése (ha maradt és a constraint megengedi), vagy
  # a következő elvárt szekvenciaelem elhelyezése (ha még nem fogyott el az összes nem-0).
  # A függvény a korlátokat már generálás közben figyelembe veszi (pruning),
  # az akkumulátor (acc) a részlegesen felépített lista elemeit tárolja
  # fordított sorrendben, hogy a beszúrás O(1) legyen.
  @spec backtrack_build(
    integer, integer, integer, integer, integer,
    [value()], %{index() => value()}, integer, [value()], [[value()]]
    ) :: result :: [[value()]]
  defp backtrack_build(
    pos, total_length, num_sequences, seq_length, zeros_left,
    sequence, constraints_map, placed_nonzeros, acc, results
    ) do
    cond do
      pos > total_length ->
        # Minden elem felépítve, ellenőrizzük a számlálókat és a korlátokat
        candidate = Enum.reverse(acc)
        if zeros_left == 0
          and placed_nonzeros == num_sequences * seq_length
          and constraints_ok?(candidate, constraints_map),
        do: [candidate | results],
        else: results

      true ->
        # Próbáljuk 0-t tenni, ha van még és nem ütközik a korlátokkal
        results_after_zero =
          if zeros_left > 0 and allows?(constraints_map, pos, 0) do
            backtrack_build(
              pos + 1, total_length, num_sequences, seq_length, zeros_left - 1,
              sequence, constraints_map, placed_nonzeros, [0 | acc], results
            )
          else
            results
          end

        # Próbáljuk a következő szekvenciaelemet tenni, ha még van elhelyezhető nem-0
        next_results =
          if placed_nonzeros < num_sequences * seq_length do
            expected_val = Enum.at(sequence, rem(placed_nonzeros, seq_length))
            if allows?(constraints_map, pos, expected_val) do
              new_placed_nonzeros = placed_nonzeros + 1
              backtrack_build(pos + 1, total_length, num_sequences, seq_length, zeros_left, sequence, constraints_map, new_placed_nonzeros, [expected_val | acc], results_after_zero)
            else
              results_after_zero
            end
          else
            results_after_zero
          end

        next_results
    end
  end


  # Ellenőrzi, hogy a constraints megengedi-e az értéket az adott pozíción
  @spec allows?(%{index() => value()}, index(), value()) :: result :: boolean
  defp allows?(constraints_map, index, value) do
    case Map.get(constraints_map, index) do
      nil -> true
      ^value -> true
      _ -> false
    end
  end


  # Ellenőrzi, hogy a constraints teljesül-e egy listán.
  @spec constraints_ok?([value()], %{index() => value()}) :: result :: boolean()
  defp constraints_ok?(candidate, constraints_map) do
    Enum.all?(constraints_map, fn {index, value} -> Enum.at(candidate, index - 1) == value end)
  end
end
