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



  @spec helix(sd :: puzzle_desc()) :: ss :: solutions()
  # ss az sd feladványleíróval megadott feladvány összes megoldásának listája
  def helix(sd) do
    case sd do
      {n, m, constraints} when is_integer(n) and n > 0 and is_integer(m) and m > 0 and m <= n and is_list(constraints) ->
        with :ok <- validate_constraints(n, m, constraints) do
          positions = build_spiral_positions(n)
          _n2 = n * n
          positions_t = List.to_tuple(positions)
          if (n == 3 and m == 2 and constraints == []) or (n == 5 and m == 3 and constraints == [{{1, 3}, 1}, {{2, 2}, 2}]) do
            pos_list = positions
            uniq = Enum.uniq(pos_list)
            dups =
              pos_list
              |> Enum.group_by(& &1)
              |> Enum.filter(fn {_k, v} -> length(v) > 1 end)
          end
          index_by_pos = positions |> Enum.with_index() |> Map.new()
          constraints_by_index =
            constraints
            |> Enum.reduce(%{}, fn {{r, c}, v}, acc -> Map.put(acc, Map.fetch!(index_by_pos, {r, c}), v) end)

          # Precompute suffix capacities per row/col for indices 0..n2
          {row_suffix, col_suffix} = build_suffix_counts(positions, n)

          zero_bits = for _ <- 1..n, do: 0
          zero_counts = for _ <- 1..n, do: 0
          row_used = List.to_tuple(zero_bits)
          col_used = List.to_tuple(zero_bits)
          row_count = List.to_tuple(zero_counts)
          col_count = List.to_tuple(zero_counts)

          assignments = %{}

          solutions_assign =
            dfs_index(0, 0, assignments, n, m,
                      positions_t,
                      row_used, col_used, row_count, col_count,
                      row_suffix, col_suffix,
                      constraints_by_index)

          boards = Enum.map(solutions_assign, &build_board(&1, n))
          # Ensure uniqueness and final validation (defensive)
          positions = Tuple.to_list(positions_t)
          boards2 =
            boards
            |> Enum.uniq()
            |> Enum.filter(&valid_board?(&1, n, m, positions))
          boards2
        end
      _ -> []
    end
  end


  @doc """
  Validate constraints are within board and value ranges.
  """
  @spec validate_constraints(size(), cycle(), [field_value()]) :: :ok | {:error, term()}
  defp validate_constraints(n, m, constraints) do
    ok = Enum.all?(constraints, fn
      {{r, c}, v} when is_integer(r) and is_integer(c) and is_integer(v) ->
        1 <= r and r <= n and 1 <= c and c <= n and 1 <= v and v <= m
      _ -> false
    end)

    if ok, do: :ok, else: {:error, :invalid_constraints}
  end


  @doc """
  Build spiral positions in the specified order for n x n grid.
  """
  @spec build_spiral_positions(size()) :: [field()]
  defp build_spiral_positions(n) do
    do_spiral(1, 1, n, n, [])
  end

  @spec do_spiral(integer(), integer(), integer(), integer(), [field()]) :: [field()]
  defp do_spiral(top, left, bottom, right, acc) when top > bottom or left > right, do: acc
  defp do_spiral(top, left, bottom, right, acc) do
    top_row = for c <- left..right, do: {top, c}
    right_col = if top < bottom, do: (for r <- (top + 1)..bottom, do: {r, right}), else: []
    bottom_row = if top < bottom, do: (for c <- (right - 1)..left//-1, do: {bottom, c}), else: []
    left_col = if left < right, do: (for r <- (bottom - 1)..(top + 1)//-1, do: {r, left}), else: []

    acc2 = acc ++ top_row ++ right_col ++ bottom_row ++ left_col
    do_spiral(top + 1, left + 1, bottom - 1, right - 1, acc2)
  end

  @doc """
  Compute suffix counts for rows and columns.
  row_suffix[i][r_idx] = number of positions with row r in indices i..n2-1
  col_suffix[i][c_idx] = number of positions with col c in indices i..n2-1
  Includes entry for i == n2 (all zeros).
  """
  @spec build_suffix_counts([field()], size()) :: {tuple(), tuple()}
  defp build_suffix_counts(positions, n) do
    zero_row = List.to_tuple(for _ <- 1..n, do: 0)
    # Start from suffix at end (all zeros)
    {row_acc, col_acc} =
      Enum.reduce(Enum.reverse(positions), {[zero_row], [zero_row]}, fn {r, c}, {rl, cl} ->
        prev_row = hd(rl)
        prev_col = hd(cl)
        r_idx = r - 1
        c_idx = c - 1
        new_row = put_elem(prev_row, r_idx, elem(prev_row, r_idx) + 1)
        new_col = put_elem(prev_col, c_idx, elem(prev_col, c_idx) + 1)
        {[new_row | rl], [new_col | cl]}
      end)

    row_suffix = row_acc |> Enum.reverse() |> List.to_tuple()
    col_suffix = col_acc |> Enum.reverse() |> List.to_tuple()
    {row_suffix, col_suffix}
  end

  @doc """
  Depth-first search with index i over precomputed spiral positions.
  Includes cheap capacity pruning per row/col using suffix counts.
  """
  @spec dfs_index(non_neg_integer(), non_neg_integer(), map(), size(), cycle(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), map()) :: [map()]
  defp dfs_index(i, s, assignments, n, m,
                 positions_t,
                 row_used, col_used, row_count, col_count,
                 row_suffix, col_suffix,
                 constraints_by_index) do
    n2 = tuple_size(positions_t)
    if i == n2 do
      if s == n * m and counts_full?(row_count, m) and counts_full?(col_count, m), do: [assignments], else: []
    else
      {r, c} = elem(positions_t, i)
      r_idx = r - 1
      c_idx = c - 1
      v_forced = Map.get(constraints_by_index, i, 0)
      v_next = rem(s, m) + 1

      sols_place =
        if (v_forced == 0 or v_forced == v_next) and can_place?(r_idx, c_idx, v_next, row_used, col_used, row_count, col_count, m) do
          new_row_used = mark_used(row_used, r_idx, v_next)
          new_col_used = mark_used(col_used, c_idx, v_next)
          new_row_count = put_elem(row_count, r_idx, elem(row_count, r_idx) + 1)
          new_col_count = put_elem(col_count, c_idx, elem(col_count, c_idx) + 1)
          new_assign = Map.put(assignments, {r, c}, v_next)
          dfs_index(i + 1, s + 1, new_assign, n, m,
                    positions_t,
                    new_row_used, new_col_used, new_row_count, new_col_count,
                    row_suffix, col_suffix,
                    constraints_by_index)
        else
          []
        end

      sols_skip =
        if v_forced == 0 do
          dfs_index(i + 1, s, assignments, n, m,
                    positions_t,
                    row_used, col_used, row_count, col_count,
                    row_suffix, col_suffix,
                    constraints_by_index)
        else
          []
        end

      sols_place ++ sols_skip
    end
  end

  @doc """
  Check if value v can be placed at row r_idx, col c_idx according to uniqueness and counts.
  """
  @spec can_place?(non_neg_integer(), non_neg_integer(), value(), tuple(), tuple(), tuple(), tuple(), cycle()) :: boolean()
  defp can_place?(r_idx, c_idx, v, row_used, col_used, row_count, col_count, m) do
    mask = 1 <<< (v - 1)
    row_ok = (elem(row_used, r_idx) &&& mask) == 0 and elem(row_count, r_idx) < m
    col_ok = (elem(col_used, c_idx) &&& mask) == 0 and elem(col_count, c_idx) < m
    row_ok and col_ok
  end

  @doc """
  Conservative skip check: ensure that leaving this cell 0 cannot make it impossible to reach m values
  in this row/col given remaining cells. Cheap lower-bound pruning.
  """
  # can_skip? not needed in index-based solver with capacity checks

  @doc """
  Mark value as used in row/col bitmask.
  """
  @spec mark_used(tuple(), non_neg_integer(), value()) :: tuple()
  defp mark_used(bitset_tuple, idx, v) do
    mask = 1 <<< (v - 1)
    put_elem(bitset_tuple, idx, elem(bitset_tuple, idx) ||| mask)
  end

  @doc """
  Verify all counts equal m.
  """
  @spec counts_full?(tuple(), cycle()) :: boolean()
  defp counts_full?(counts_tuple, m) do
    Enum.all?(0..(tuple_size(counts_tuple) - 1), fn i -> elem(counts_tuple, i) == m end)
  end

  @doc """
  Build final n x n board from assignments map, filling 0 where absent.
  """
  @spec build_board(%{{row(), col()} => value()}, size()) :: solution()
  defp build_board(assignments, n) do
    for r <- 1..n do
      for c <- 1..n do
        Map.get(assignments, {r, c}, 0)
      end
    end
  end

  @doc """
  Defensive validation of a completed board:
  - Exactly m non-zeros per row and per column
  - Spiral non-zero sequence equals 1..m repeating and has total n*m elements
  """
  @spec valid_board?(solution(), size(), cycle(), [field()]) :: boolean()
  defp valid_board?(board, n, m, positions) do
    rows_ok = Enum.all?(board, fn row -> Enum.count(row, & &1 != 0) == m end)
    cols_ok =
      Enum.all?(0..(n-1), fn c ->
        Enum.count(0..(n-1), fn r -> board |> Enum.at(r) |> Enum.at(c) |> Kernel.!=(0) end) == m
      end)
    if not (rows_ok and cols_ok), do: false, else: (
      seq = for {r, c} <- positions, do: board |> Enum.at(r-1) |> Enum.at(c-1)
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
      10 => {8, 4, [{{2, 3}, 4}, {{3, 3}, 2}, {{6, 1}, 1}, {{7, 6}, 3}], [[[0, 0, 1, 2, 3, 4, 0, 0], [0, 0, 4, 0, 1, 2, 3, 0], [0, 0, 2, 3, 0, 0, 4, 1], [3, 1, 0, 4, 0, 0, 0, 2], [2, 4, 0, 0, 0, 0, 1, 3], [1, 3, 0, 0, 0, 0, 2, 4], [0, 2, 0, 1, 4, 3, 0, 0], [4, 0, 3, 0, 2, 1, 0, 0]], [[0, 0, 1, 2, 3, 4, 0, 0], [0, 0, 4, 0, 1, 2, 3, 0], [3, 0, 2, 0, 0, 0, 4, 1], [0, 1, 3, 4, 0, 0, 0, 2], [2, 4, 0, 0, 0, 0, 1, 3], [1, 3, 0, 0, 0, 0, 2, 4], [0, 2, 0, 1, 4, 3, 0, 0], [4, 0, 0, 3, 2, 1, 0, 0]]]},
      11 => {9, 3, [{{1, 7}, 3}, {{3, 1}, 1}, {{6, 1}, 3}, {{6, 2}, 2}, {{6, 6}, 1}, {{8, 4}, 3}, {{9, 2}, 1}], [[[0, 0, 0, 0, 1, 2, 3, 0, 0], [0, 0, 2, 0, 0, 0, 0, 3, 1], [1, 3, 0, 0, 0, 0, 0, 0, 2], [0, 0, 0, 1, 2, 3, 0, 0, 0], [0, 0, 0, 2, 3, 0, 1, 0, 0], [3, 2, 0, 0, 0, 1, 0, 0, 0], [0, 0, 3, 0, 0, 0, 2, 1, 0], [0, 0, 1, 3, 0, 0, 0, 2, 0], [2, 1, 0, 0, 0, 0, 0, 0, 3]]]}
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
