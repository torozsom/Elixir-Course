defmodule Nhf1 do
  @moduledoc """
  Számtekercs

  @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"

  @date   "2025-10-24"
  """

  import Bitwise


  @type size()  :: integer() # tábla mérete (0 < n)
  @type cycle() :: integer() # ciklus hossza (0 < m <= n)
  @type value() :: integer() # mező értéke (0 < v <= m)

  @type row()   :: integer()       # sor száma (1-től n-ig)
  @type col()   :: integer()       # oszlop száma (1-től n-ig)
  @type field() :: {row(), col()}  # mező koordinátái

  @type field_value() :: {field(), value()}                 # mező és értéke
  @type puzzle_desc() :: {size(), cycle(), [field_value()]} # feladvány

  @type retval()    :: integer()    # eredménymező értéke (0 <= rv <= m)
  @type solution()  :: [[retval()]] # egy megoldás
  @type solutions() :: [solution()] # összes megoldás



  @doc """
  A helix/1 a számtekercs feladvány összes megoldását állítja elő.

  Bemenet: `{n, m, megszorítások}`, ahol `megszorítások :: [{{r,c}, v}]` az adott nem-0
  értékek helyét és értékét tartalmazza (1 ≤ v ≤ m). A 0 érték üres cellát jelent.

  Kimenet: a lehetséges táblák listája (bármilyen sorrendben), ahol
  - minden sorban és oszlopban az 1..m számok pontosan egyszer szerepelnek,
  - a bal felső sarokból induló spirális bejárás mentén a nem-0 értékek a
    1,2,..,m,1,2,..,m,… ciklust követik.
  """
  @spec helix(sd :: puzzle_desc()) :: ss :: solutions()
  # ss az sd feladványleíróval megadott feladvány összes megoldásának listája
  def helix(sd) do
    case sd do
      {n, m, fixed_cells} when is_integer(n) and n > 0 and is_integer(m) and m > 0 and m <= n and is_list(fixed_cells) ->
        # Mező- és értéktartományok ellenőrzése
        with :ok <- validate_constraints(n, m, fixed_cells) do
          # Spirális bejárási útvonal
          spiral_positions = spiral_path(n)
          spiral_positions_t = List.to_tuple(spiral_positions)
          # Pozíció → spirálindex leképezés
          index_by_position = spiral_positions |> Enum.with_index() |> Map.new()
          forced_values_by_index =
            fixed_cells
            |> Enum.reduce(%{}, fn {{r, c}, v}, acc -> Map.put(acc, Map.fetch!(index_by_position, {r, c}), v) end)

          # Suffix kapacitások (sor/oszlop pozíciók száma i..vég tartományban) – opcionális pruninghoz
          {row_suffix_counts, col_suffix_counts} = build_suffix_counts(spiral_positions, n)

          # Kezdeti állapot: sor/oszlop értékmaszkok és nem-0 darabszámok
          zero_masks = for _ <- 1..n, do: 0
          zero_counts_list = for _ <- 1..n, do: 0
          row_value_masks = List.to_tuple(zero_masks)
          col_value_masks = List.to_tuple(zero_masks)
          row_nonzero_counts = List.to_tuple(zero_counts_list)
          col_nonzero_counts = List.to_tuple(zero_counts_list)

          board_assignments = %{}

          assignment_solutions =
            backtrack_over_spiral(0, 0, board_assignments, n, m,
                                  spiral_positions_t,
                                  row_value_masks, col_value_masks, row_nonzero_counts, col_nonzero_counts,
                                  row_suffix_counts, col_suffix_counts,
                                  forced_values_by_index)

          boards = Enum.map(assignment_solutions, &build_board_from_assignments(&1, n))
          # Ensure uniqueness and final validation (defensive)
          positions_list = Tuple.to_list(spiral_positions_t)
          validated_boards =
            boards
            |> Enum.uniq()
            |> Enum.filter(&valid_solution_board?(&1, n, m, positions_list))
          validated_boards
        end
      _ -> []
    end
  end


  # Ellenőrzi, hogy a megadott megszorítások (pozíciók és értékek) a tábla és az 1..m tartományon belül vannak-e.
  @spec validate_constraints(size(), cycle(), [field_value()]) :: :ok | {:error, term()}
  defp validate_constraints(n, m, constraints) do
    ok = Enum.all?(constraints, fn
      {{r, c}, v} when is_integer(r) and is_integer(c) and is_integer(v) ->
        1 <= r and r <= n and 1 <= c and c <= n and 1 <= v and v <= m
      _ -> false
    end)

    if ok, do: :ok, else: {:error, :invalid_constraints}
  end


  # n×n spirális bejárás koordinátalistája (külső peremtől befelé).
  @spec spiral_path(size()) :: [field()]
  defp spiral_path(n) do
    spiral_path_layers(1, 1, n, n, [])
  end

  # Alapeset: elfogytak a rétegek.
  @spec spiral_path_layers(integer(), integer(), integer(), integer(), [field()]) :: [field()]
  defp spiral_path_layers(top, left, bottom, right, acc) when top > bottom or left > right, do: acc
  # Egy réteg bejárása: top row → right col → bottom row → left col, majd a belső négyzet folytatása.
  defp spiral_path_layers(top, left, bottom, right, acc) do
    top_row = for c <- left..right, do: {top, c}
    right_col = if top < bottom, do: (for r <- (top + 1)..bottom, do: {r, right}), else: []
    bottom_row = if top < bottom, do: (for c <- (right - 1)..left//-1, do: {bottom, c}), else: []
    left_col = if left < right, do: (for r <- (bottom - 1)..(top + 1)//-1, do: {r, left}), else: []

    acc2 = acc ++ top_row ++ right_col ++ bottom_row ++ left_col
    spiral_path_layers(top + 1, left + 1, bottom - 1, right - 1, acc2)
  end

  # Suffix kapacitások (i..vég): hány pozíció esik még az adott sorra/oszlopra – olcsó pruninghoz használható.
  @spec build_suffix_counts([field()], size()) :: {tuple(), tuple()}
  defp build_suffix_counts(positions, n) do
    zero_row = List.to_tuple(for _ <- 1..n, do: 0)
    # Start from suffix at end (all zeros)
    {row_acc, col_acc} =
      Enum.reduce(Enum.reverse(positions), {[zero_row], [zero_row]}, fn {r, c}, {rl, cl} ->
        prev_row = hd(rl)
        prev_col = hd(cl)
        row_idx0 = r - 1
        col_idx0 = c - 1
        new_row = put_elem(prev_row, row_idx0, elem(prev_row, row_idx0) + 1)
        new_col = put_elem(prev_col, col_idx0, elem(prev_col, col_idx0) + 1)
        {[new_row | rl], [new_col | cl]}
      end)

    row_suffix = row_acc |> Enum.reverse() |> List.to_tuple()
    col_suffix = col_acc |> Enum.reverse() |> List.to_tuple()
    {row_suffix, col_suffix}
  end

  # Index-alapú visszalépéses keresés a spirál mentén.
  # Minden lépésben a soron következő nem-0 érték `next_value = (placed_count mod m) + 1`.
  @spec backtrack_over_spiral(non_neg_integer(), non_neg_integer(), map(), size(), cycle(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), map()) :: [map()]
  defp backtrack_over_spiral(idx, placed_count, board_assignments, n, m,
                             spiral_positions_t,
                             row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts,
                             row_suffix_counts, col_suffix_counts,
                             forced_values_by_index) do
    n2 = tuple_size(spiral_positions_t)
    if idx == n2 do
      # Alapeset: akkor és csak akkor megoldás, ha minden sor/oszlop m darab nem-0 értéket tartalmaz,
      # és globálisan is n*m darab értéket helyeztünk el.
      if placed_count == n * m and counts_reach_target?(row_nonzero_counts, m) and counts_reach_target?(col_nonzero_counts, m), do: [board_assignments], else: []
    else
      {r, c} = elem(spiral_positions_t, idx)
      row_idx0 = r - 1
      col_idx0 = c - 1
      forced_value = Map.get(forced_values_by_index, idx, 0)
      next_value = rem(placed_count, m) + 1

      solutions_place_branch =
        # Helyezés ága: ha nincs kényszer, vagy a kényszer épp `next_value`, és a sor/oszlop szabályok engedik.
        if (forced_value == 0 or forced_value == next_value) and can_place_value?(row_idx0, col_idx0, next_value, row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts, m) do
          new_row_value_masks = mark_value_used(row_value_masks, row_idx0, next_value)
          new_col_value_masks_by_col = mark_value_used(col_value_masks_by_col, col_idx0, next_value)
          new_row_nonzero_counts = put_elem(row_nonzero_counts, row_idx0, elem(row_nonzero_counts, row_idx0) + 1)
          new_col_nonzero_counts = put_elem(col_nonzero_counts, col_idx0, elem(col_nonzero_counts, col_idx0) + 1)
          new_assignments = Map.put(board_assignments, {r, c}, next_value)
          backtrack_over_spiral(idx + 1, placed_count + 1, new_assignments, n, m,
                                spiral_positions_t,
                                new_row_value_masks, new_col_value_masks_by_col, new_row_nonzero_counts, new_col_nonzero_counts,
                                row_suffix_counts, col_suffix_counts,
                                forced_values_by_index)
        else
          []
        end

      solutions_skip_branch =
        # Kihagyás (0) ága: csak akkor engedett, ha nincs kényszer érték ezen a pozíción.
        if forced_value == 0 do
          backtrack_over_spiral(idx + 1, placed_count, board_assignments, n, m,
                                spiral_positions_t,
                                row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts,
                                row_suffix_counts, col_suffix_counts,
                                forced_values_by_index)
        else
          []
        end

      solutions_place_branch ++ solutions_skip_branch
    end
  end

  # Eldönti, hogy a v érték elhelyezhető-e a (row_idx0, col_idx0) cellába a sor/oszlop egyediség és kvóta alapján.
  @spec can_place_value?(non_neg_integer(), non_neg_integer(), value(), tuple(), tuple(), tuple(), tuple(), cycle()) :: boolean()
  defp can_place_value?(row_idx0, col_idx0, v, row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts, m) do
    mask = 1 <<< (v - 1)
    row_ok = (elem(row_value_masks, row_idx0) &&& mask) == 0 and elem(row_nonzero_counts, row_idx0) < m
    col_ok = (elem(col_value_masks_by_col, col_idx0) &&& mask) == 0 and elem(col_nonzero_counts, col_idx0) < m
    row_ok and col_ok
  end

  # Beállítja a v érték bitjét a megadott maszk-tuple adott indexében.
  @spec mark_value_used(tuple(), non_neg_integer(), value()) :: tuple()
  defp mark_value_used(bitset_tuple, idx, v) do
    mask = 1 <<< (v - 1)
    put_elem(bitset_tuple, idx, elem(bitset_tuple, idx) ||| mask)
  end

  # Igaz, ha minden sor/oszlop elérte az m darab nem-0 értéket.
  @spec counts_reach_target?(tuple(), cycle()) :: boolean()
  defp counts_reach_target?(counts_tuple, m) do
    Enum.all?(0..(tuple_size(counts_tuple) - 1), fn i -> elem(counts_tuple, i) == m end)
  end

  # Map-ből n×n táblát épít; a hiányzó cellák értéke 0.
  @spec build_board_from_assignments(%{{row(), col()} => value()}, size()) :: solution()
  defp build_board_from_assignments(assignments, n) do
    for r <- 1..n do
      for c <- 1..n do
        Map.get(assignments, {r, c}, 0)
      end
    end
  end

  # Defenzív ellenőrzés: sor/oszlop kvóta m, és a spirál menti NEM-0 értékek 1..m ciklust alkotnak.
  @spec valid_solution_board?(solution(), size(), cycle(), [field()]) :: boolean()
  defp valid_solution_board?(board, n, m, spiral_positions) do
    rows_ok = Enum.all?(board, fn row -> Enum.count(row, & &1 != 0) == m end)
    cols_ok =
      Enum.all?(0..(n-1), fn c ->
        Enum.count(0..(n-1), fn r -> board |> Enum.at(r) |> Enum.at(c) |> Kernel.!=(0) end) == m
      end)
    if not (rows_ok and cols_ok), do: false, else: (
      seq = for {r, c} <- spiral_positions, do: board |> Enum.at(r-1) |> Enum.at(c-1)
      nz = Enum.filter(seq, &(&1 != 0))
      if length(nz) != n * m, do: false, else: (
        expected = Enum.map(0..(n*m - 1), fn i -> rem(i, m) + 1 end)
        nz == expected
      )
    )
  end

end



defmodule Nhf1Kiadott do

  testcases = # %{key => {size, cycle, constraints, solutions}}
    %{
      0 => {3, 2, [], [[[0, 1, 2], [1, 2, 0], [2, 0, 1]], [[0, 1, 2], [2, 0, 1], [1, 2, 0]], [[1, 2, 0], [2, 0, 1], [0, 1, 2]]]},
      1 => {4, 2, [{{1, 1}, 1}, {{1, 4}, 2}], [[[1, 0, 0, 2], [0, 1, 2, 0], [0, 2, 1, 0], [2, 0, 0, 1]], [[1, 0, 0, 2], [2, 0, 0, 1], [0, 2, 1, 0], [0, 1, 2, 0]], [[1, 0, 0, 2], [2, 0, 1, 0], [0, 2, 0, 1], [0, 1, 2, 0]]]},
      2 => {4, 1, [{{1, 1}, 1}], [[[1, 0, 0, 0], [0, 0, 0, 1], [0, 0, 1, 0], [0, 1, 0, 0]], [[1, 0, 0, 0], [0, 0, 0, 1], [0, 1, 0, 0], [0, 0, 1, 0]], [[1, 0, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1], [0, 1, 0, 0]], [[1, 0, 0, 0], [0, 0, 1, 0], [0, 1, 0, 0], [0, 0, 0, 1]], [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 1, 0]], [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]]},
      3 => {4, 3, [], []},
      4 => {5, 3, [{{1, 3}, 1}, {{2, 2}, 2}], [[[0, 0, 1, 2, 3], [0, 2, 0, 3, 1], [1, 3, 0, 0, 2], [3, 0, 2, 1, 0], [2, 1, 3, 0, 0]], [[0, 0, 1, 2, 3], [0, 2, 3, 0, 1], [1, 3, 0, 0, 2], [3, 0, 2, 1, 0], [2, 1, 0, 3, 0]]]},
      5 => {6, 3, [{{1, 5}, 2}, {{2, 2}, 1}, {{4, 6}, 1}], [[[1, 0, 0, 0, 2, 3], [0, 1, 2, 3, 0, 0], [0, 3, 1, 2, 0, 0], [0, 2, 3, 0, 0, 1], [3, 0, 0, 0, 1, 2], [2, 0, 0, 1, 3, 0]]]},
      6 => {6, 3, [{{1, 5}, 2}, {{2, 2}, 1}, {{4, 6}, 1}], [[[1, 0, 0, 0, 2, 3], [0, 1, 2, 3, 0, 0], [0, 3, 1, 2, 0, 0], [0, 2, 3, 0, 0, 1], [3, 0, 0, 0, 1, 2], [2, 0, 0, 1, 3, 0]]]},
      7 => {6, 3, [{{2, 4}, 3}, {{3, 3}, 1}, {{3, 6}, 2}, {{6, 1}, 3}], [[[0, 1, 2, 0, 3, 0], [2, 0, 0, 3, 0, 1], [0, 3, 1, 0, 0, 2], [0, 0, 3, 2, 1, 0], [1, 0, 0, 0, 2, 3], [3, 2, 0, 1, 0, 0]]]},
      8 => {7, 3, [{{1, 1}, 1}, {{2, 4}, 3}, {{3, 4}, 1}, {{4, 3}, 3}, {{6, 6}, 2}, {{7, 7}, 3}], [[[1, 0, 0, 2, 0, 3, 0], [0, 1, 2, 3, 0, 0, 0], [0, 3, 0, 1, 2, 0, 0], [0, 2, 3, 0, 0, 0, 1], [3, 0, 0, 0, 0, 1, 2], [0, 0, 1, 0, 3, 2, 0], [2, 0, 0, 0, 1, 0, 3]]]},
      9 => {8, 3, [{{1, 4}, 1}, {{1, 7}, 3}, {{2, 3}, 2}, {{2, 4}, 3}, {{3, 2}, 1}, {{4, 7}, 1}, {{7, 7}, 2}], [[[0, 0, 0, 1, 0, 2, 3, 0], [0, 0, 2, 3, 0, 0, 0, 1], [0, 1, 0, 0, 2, 3, 0, 0], [0, 3, 0, 0, 0, 0, 1, 2], [1, 2, 3, 0, 0, 0, 0, 0], [3, 0, 0, 2, 0, 1, 0, 0], [0, 0, 1, 0, 3, 0, 2, 0], [2, 0, 0, 0, 1, 0, 0, 3]], [[0, 0, 0, 1, 0, 2, 3, 0], [0, 0, 2, 3, 0, 0, 0, 1], [0, 1, 0, 0, 2, 3, 0, 0], [0, 3, 0, 0, 0, 0, 1, 2], [1, 2, 3, 0, 0, 0, 0, 0], [3, 0, 0, 2, 1, 0, 0, 0], [0, 0, 1, 0, 3, 0, 2, 0], [2, 0, 0, 0, 0, 1, 0, 3]], [[0, 0, 0, 1, 0, 2, 3, 0], [0, 0, 2, 3, 0, 0, 0, 1], [0, 1, 0, 2, 0, 3, 0, 0], [0, 3, 0, 0, 0, 0, 1, 2], [1, 2, 3, 0, 0, 0, 0, 0], [3, 0, 0, 0, 2, 1, 0, 0], [0, 0, 1, 0, 3, 0, 2, 0], [2, 0, 0, 0, 1, 0, 0, 3]], [[0, 0, 0, 1, 0, 2, 3, 0], [0, 0, 2, 3, 0, 0, 0, 1], [0, 1, 0, 2, 3, 0, 0, 0], [0, 3, 0, 0, 0, 0, 1, 2], [1, 2, 3, 0, 0, 0, 0, 0], [3, 0, 0, 0, 2, 1, 0, 0], [0, 0, 0, 0, 1, 3, 2, 0], [2, 0, 1, 0, 0, 0, 0, 3]], [[0, 0, 0, 1, 0, 2, 3, 0], [0, 0, 2, 3, 0, 0, 0, 1], [0, 1, 0, 2, 3, 0, 0, 0], [0, 3, 0, 0, 0, 0, 1, 2], [1, 2, 3, 0, 0, 0, 0, 0], [3, 0, 0, 0, 2, 1, 0, 0], [0, 0, 1, 0, 0, 3, 2, 0], [2, 0, 0, 0, 1, 0, 0, 3]]]},
      #10 => {8, 4, [{{2, 3}, 4}, {{3, 3}, 2}, {{6, 1}, 1}, {{7, 6}, 3}], [[[0, 0, 1, 2, 3, 4, 0, 0], [0, 0, 4, 0, 1, 2, 3, 0], [0, 0, 2, 3, 0, 0, 4, 1], [3, 1, 0, 4, 0, 0, 0, 2], [2, 4, 0, 0, 0, 0, 1, 3], [1, 3, 0, 0, 0, 0, 2, 4], [0, 2, 0, 1, 4, 3, 0, 0], [4, 0, 3, 0, 2, 1, 0, 0]], [[0, 0, 1, 2, 3, 4, 0, 0], [0, 0, 4, 0, 1, 2, 3, 0], [3, 0, 2, 0, 0, 0, 4, 1], [0, 1, 3, 4, 0, 0, 0, 2], [2, 4, 0, 0, 0, 0, 1, 3], [1, 3, 0, 0, 0, 0, 2, 4], [0, 2, 0, 1, 4, 3, 0, 0], [4, 0, 0, 3, 2, 1, 0, 0]]]},
      10 => {9, 3, [{{1, 7}, 3}, {{3, 1}, 1}, {{6, 1}, 3}, {{6, 2}, 2}, {{6, 6}, 1}, {{8, 4}, 3}, {{9, 2}, 1}], [[[0, 0, 0, 0, 1, 2, 3, 0, 0], [0, 0, 2, 0, 0, 0, 0, 3, 1], [1, 3, 0, 0, 0, 0, 0, 0, 2], [0, 0, 0, 1, 2, 3, 0, 0, 0], [0, 0, 0, 2, 3, 0, 1, 0, 0], [3, 2, 0, 0, 0, 1, 0, 0, 0], [0, 0, 3, 0, 0, 0, 2, 1, 0], [0, 0, 1, 3, 0, 0, 0, 2, 0], [2, 1, 0, 0, 0, 0, 0, 0, 3]]]}
    }
  for i <- 0..map_size(testcases)-1
    do
    {size, cycle, constrains, solutions} = testcases[i]
    {"Test case #{i}",
     Nhf1.helix({size, cycle, constrains}) |> Enum.sort() === solutions
    }
    |> IO.inspect
  end

end
