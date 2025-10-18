defmodule Nhf1 do
  @moduledoc """
  Számtekercs

  @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"

  @date   "2025-10-18"
  """

  import Bitwise

  # Alignment lookahead ablakméret (indexekben). Csak akkor futtatjuk a kényszer-igazítást,
  # ha a következő kényszer ezen ablakon belül van.
  @alignment_window 64


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

          # Kényszerek tömbösítése gyors hozzáféréshez és lookaheadhoz
          n2 = length(spiral_positions)
          {forced_values_t, forced_prefix_counts, next_forced_t} = build_forced_arrays(forced_values_by_index, n2)

          # Előre kiszámolt maszkok az 1..m értékekhez
          mask_for_value_t = build_mask_table(m)

          # Suffix kapacitások (sor/oszlop pozíciók száma i..vég tartományban) – opcionális pruninghoz
          {row_suffix_counts, col_suffix_counts} = build_suffix_counts(spiral_positions, n)

          # Kezdeti állapot: sor/oszlop értékmaszkok és nem-0 darabszámok
          zero_masks = for _ <- 1..n, do: 0
          zero_counts_list = for _ <- 1..n, do: 0
          row_value_masks = List.to_tuple(zero_masks)
          col_value_masks = List.to_tuple(zero_masks)
          row_nonzero_counts = List.to_tuple(zero_counts_list)
          col_nonzero_counts = List.to_tuple(zero_counts_list)

          placements = []
          boards_acc =
            backtrack_over_spiral(0, 0, placements, n, m,
                                  spiral_positions_t,
                                  row_value_masks, col_value_masks, row_nonzero_counts, col_nonzero_counts,
                                  row_suffix_counts, col_suffix_counts,
                                  mask_for_value_t,
                                  forced_values_t, forced_prefix_counts, next_forced_t,
                                  [])
          boards_acc
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
  @spec backtrack_over_spiral(non_neg_integer(), non_neg_integer(), list(), size(), cycle(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), tuple(), [solution()]) :: [solution()]
  defp backtrack_over_spiral(idx, placed_count, placements, n, m,
                             spiral_positions_t,
                             row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts,
                             row_suffix_counts, col_suffix_counts,
                             mask_for_value_t,
                             forced_values_t, forced_prefix_counts, next_forced_t,
                             acc) do
    n2 = tuple_size(spiral_positions_t)
    # Globális kapacitás-pruning: a hátralévő pozíciók száma nem lehet kevesebb a még elhelyezendő nem-0 értékeknél
    remaining_positions = n2 - idx
    remaining_needed = n * m - placed_count
    if remaining_positions < remaining_needed do
      acc
    else if idx == n2 do
      # Alapeset: akkor és csak akkor megoldás, ha minden sor/oszlop m darab nem-0 értéket tartalmaz,
      # és globálisan is n*m darab értéket helyeztünk el.
      if placed_count == n * m and counts_reach_target?(row_nonzero_counts, m) and counts_reach_target?(col_nonzero_counts, m) do
        # Építsük meg a táblát a placements alapján
        assignments =
          Enum.reduce(placements, %{}, fn {pidx, v}, accm ->
            {rr, cc} = elem(spiral_positions_t, pidx)
            Map.put(accm, {rr, cc}, v)
          end)
        board = build_board_from_assignments(assignments, n)
        [board | acc]
      else
        acc
      end
    else
      {r, c} = elem(spiral_positions_t, idx)
      row_idx0 = r - 1
      col_idx0 = c - 1
      forced_value = elem(forced_values_t, idx)
      next_value = rem(placed_count, m) + 1
      next_mask = elem(mask_for_value_t, next_value)

      acc_after_place =
        # Helyezés ága: ha nincs kényszer, vagy a kényszer épp `next_value`, és a sor/oszlop szabályok engedik.
        if (forced_value == 0 or forced_value == next_value) and can_place_value?(row_idx0, col_idx0, next_mask, row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts, m) do
          new_row_value_masks = mark_mask_used(row_value_masks, row_idx0, next_mask)
          new_col_value_masks_by_col = mark_mask_used(col_value_masks_by_col, col_idx0, next_mask)
          new_row_nonzero_counts = put_elem(row_nonzero_counts, row_idx0, elem(row_nonzero_counts, row_idx0) + 1)
          new_col_nonzero_counts = put_elem(col_nonzero_counts, col_idx0, elem(col_nonzero_counts, col_idx0) + 1)
          # Lokális kapacitás-pruning: a hátralévő pozíciók azonos sorban/oszlopban elegendőek-e a kvótához
          if capacity_ok_for_lines?(idx + 1, row_idx0, col_idx0, new_row_nonzero_counts, new_col_nonzero_counts, row_suffix_counts, col_suffix_counts, n, m) do
            new_placements = [{idx, next_value} | placements]
            backtrack_over_spiral(idx + 1, placed_count + 1, new_placements, n, m,
                                  spiral_positions_t,
                                  new_row_value_masks, new_col_value_masks_by_col, new_row_nonzero_counts, new_col_nonzero_counts,
                                  row_suffix_counts, col_suffix_counts,
                                  mask_for_value_t,
                                  forced_values_t, forced_prefix_counts, next_forced_t,
                                  acc)
          else
            acc
          end
        else
          acc
        end

      acc_after_skip =
        # Kihagyás (0) ága: csak akkor engedett, ha nincs kényszer érték ezen a pozíción.
        if forced_value == 0 do
          # Lokális kapacitás-pruning a sorra/oszlopra nézve, miután elhagytuk ezt a cellát
          if capacity_ok_for_lines?(idx + 1, row_idx0, col_idx0, row_nonzero_counts, col_nonzero_counts, row_suffix_counts, col_suffix_counts, n, m) do
            # Alignment lookahead csak akkor, ha a következő kényszer közel van
            if alignment_window_ok?(idx + 1, placed_count, m, forced_values_t, forced_prefix_counts, next_forced_t) do
              backtrack_over_spiral(idx + 1, placed_count, placements, n, m,
                                    spiral_positions_t,
                                    row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts,
                                    row_suffix_counts, col_suffix_counts,
                                    mask_for_value_t,
                                    forced_values_t, forced_prefix_counts, next_forced_t,
                                    acc_after_place)
            else
              acc_after_place
            end
          else
            acc_after_place
          end
        else
          acc_after_place
        end

      acc_after_skip
    end end
  end

  # Eldönti, hogy a v érték elhelyezhető-e a (row_idx0, col_idx0) cellába a sor/oszlop egyediség és kvóta alapján.
  @spec can_place_value?(non_neg_integer(), non_neg_integer(), non_neg_integer(), tuple(), tuple(), tuple(), tuple(), cycle()) :: boolean()
  defp can_place_value?(row_idx0, col_idx0, mask, row_value_masks, col_value_masks_by_col, row_nonzero_counts, col_nonzero_counts, m) do
    row_ok = (elem(row_value_masks, row_idx0) &&& mask) == 0 and elem(row_nonzero_counts, row_idx0) < m
    col_ok = (elem(col_value_masks_by_col, col_idx0) &&& mask) == 0 and elem(col_nonzero_counts, col_idx0) < m
    row_ok and col_ok
  end

  # Beállítja a v érték bitjét a megadott maszk-tuple adott indexében.
  @spec mark_mask_used(tuple(), non_neg_integer(), non_neg_integer()) :: tuple()
  defp mark_mask_used(bitset_tuple, idx, mask) do
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

  # (Korábbi defenzív validátor eltávolítva; a keresés konstrukciósan érvényes táblákat ad.)

  # Ellenőrzi, hogy a következő idx-től kezdődő suffix pozíciók elegendőek-e a vizsgált sor/oszlop kvótájának
  # teljesítéséhez a jelenlegi (módosított) számlálókkal.
  @spec capacity_ok_for_lines?(non_neg_integer(), non_neg_integer(), non_neg_integer(), tuple(), tuple(), tuple(), tuple(), size(), cycle()) :: boolean()
  defp capacity_ok_for_lines?(next_idx, row_idx0, col_idx0, row_nonzero_counts, col_nonzero_counts, row_suffix_counts, col_suffix_counts, _n, m) do
    # A build_suffix_counts eredménye úgy rendezett, hogy index = (összes_pozíciók_száma - next_idx)
    # adja a next_idx..vég tartomány kapacitását. Összes_pozíciók_száma = tuple_size - 1.
    total_positions = tuple_size(row_suffix_counts) - 1
    suffix_index = total_positions - next_idx
    row_suffix = elem(row_suffix_counts, suffix_index)
    col_suffix = elem(col_suffix_counts, suffix_index)
    remaining_row_slots = elem(row_suffix, row_idx0)
    remaining_col_slots = elem(col_suffix, col_idx0)

    row_needed = m - elem(row_nonzero_counts, row_idx0)
    col_needed = m - elem(col_nonzero_counts, col_idx0)

    remaining_row_slots >= row_needed and remaining_col_slots >= col_needed
  end

  # Kényszerek tömbjeinek felépítése: érték-tuple, prefix kényszerszámok és a következő kényszer indexe.
  @spec build_forced_arrays(map(), non_neg_integer()) :: {tuple(), tuple(), tuple()}
  defp build_forced_arrays(forced_map, n2) do
    # forced_values_t: hossz n2, 0 ha nincs kényszer, különben 1..m
    forced_values_list = for i <- 0..(n2 - 1), do: Map.get(forced_map, i, 0)
    forced_values_t = List.to_tuple(forced_values_list)
    # prefix counts: hossz n2+1, pref[0]=0, pref[i+1]=pref[i]+(forced_values[i]!=0)
    {pref_list, _} =
      Enum.map_reduce(0..(n2 - 1), 0, fn i, acc ->
        v = elem(forced_values_t, i)
        new_acc = acc + if v == 0, do: 0, else: 1
        {new_acc, new_acc}
      end)
    pref_full = [0 | pref_list]
    forced_prefix_counts = List.to_tuple(pref_full)
    # next_forced_t: a következő (>=i) kényszer indexe vagy -1
    {next_list, _last} =
      Enum.reduce(Enum.to_list(0..(n2 - 1)) |> Enum.reverse(), {[], -1}, fn i, {acc, last} ->
        v = elem(forced_values_t, i)
        new_last = if v == 0, do: last, else: i
        {[new_last | acc], new_last}
      end)
    next_forced_t = List.to_tuple(next_list)
    {forced_values_t, forced_prefix_counts, next_forced_t}
  end

  # Előszámolt maszkok táblája az 1..m értékekhez. Index 0 -> 0 maszk.
  @spec build_mask_table(cycle()) :: tuple()
  defp build_mask_table(m) do
    masks = [0 | Enum.to_list(1..m) |> Enum.map(fn v -> 1 <<< (v - 1) end)]
    List.to_tuple(masks)
  end

  # Igaz, ha a következő kényszer indexéig lehetséges olyan számú helyezés (min..max között),
  # ami moduló m illeszkedik a szükséges fázisra.
  @spec alignment_possible?(non_neg_integer(), non_neg_integer(), cycle(), tuple(), tuple(), tuple()) :: boolean()
  defp alignment_possible?(idx, placed_count, m, forced_values_t, forced_prefix_counts, next_forced_t) do
    n2 = tuple_size(next_forced_t)
    if idx >= n2 do
      true
    else
      fi = elem(next_forced_t, idx)
      if fi == -1 do
        true
      else
        v = elem(forced_values_t, fi)
        # kötelező helyezések száma az [idx..fi] intervallumban
        min_place = elem(forced_prefix_counts, fi + 1) - elem(forced_prefix_counts, idx)
        max_place = fi - idx + 1
        # t ≡ (v - placed_count) (mod m)
        r0 = rem(v - placed_count, m)
        r = if r0 < 0, do: r0 + m, else: r0
        # legkisebb t >= min_place, t ≡ r (mod m)
        first_t =
          if r == 0 do
            ceil_div(min_place, m) * m
          else
            if min_place <= r do
              r
            else
              k = ceil_div(min_place - r, m)
              r + k * m
            end
          end
        first_t <= max_place
      end
    end
  end

  @spec ceil_div(non_neg_integer(), pos_integer()) :: non_neg_integer()
  defp ceil_div(a, b) do
    div(a + b - 1, b)
  end

  # Csak akkor futtatjuk az alignment ellenőrzést, ha a következő kényszer az ablakon belül van.
  @spec alignment_window_ok?(non_neg_integer(), non_neg_integer(), cycle(), tuple(), tuple(), tuple()) :: boolean()
  defp alignment_window_ok?(next_idx, placed_count, m, forced_values_t, forced_prefix_counts, next_forced_t) do
    n2 = tuple_size(next_forced_t)
    if next_idx >= n2 do
      true
    else
      fi = elem(next_forced_t, next_idx)
      if fi == -1 do
        true
      else
        if fi - next_idx <= @alignment_window do
          alignment_possible?(next_idx, placed_count, m, forced_values_t, forced_prefix_counts, next_forced_t)
        else
          true
        end
      end
    end
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
