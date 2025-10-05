defmodule Khf2 do
  @moduledoc """
  Számtekercs kiterítése

  @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"

  @date   "2025-10-05"
  """



  # Alapadatok
  @type size()  :: integer() # tábla mérete (0 < n)
  @type cycle() :: integer() # ciklus hossza (0 < m <= n)
  @type value() :: integer() # mező értéke (0 < v <= m vagy "")


  # Mezőkoordináták
  @type row()   :: integer()       # sor száma (1-től n-ig)
  @type col()   :: integer()       # oszlop száma (1-től n-ig)
  @type field() :: {row(), col()}  # mező koordinátái


  # Feladványleírók
  @type field_value() :: {field(), value()}           # mező és értéke
  @type field_opt_value() :: {field(), value() | nil} # mező és opcionális értéke


  # 1. elem: méret, 2. elem: ciklushossz,
  # többi elem esetleg: mezők és értékük
  @type list_desc() :: [String.t()]



  @spec helix(input :: list_desc()) :: output :: [field_opt_value()]
  @doc """
  # Az input szöveges feladványleíró-lista szerinti számtekercs kiterített listája output
  """
  def helix(input) do
    {size, _cycle, filled_fields_map} = parse_input_strings(input)
    spiral_fields = generate_spiral_coords(size)
    assign_values_to_coords(spiral_fields, filled_fields_map)
  end



  # A szöveges bemenet feldolgozása: visszaadja a tábla méretét, a ciklus hosszát, és a kitöltött mezők mapjét
  @spec parse_input_strings(input :: list_desc()) :: result :: {size(), cycle(), map()}
  defp parse_input_strings([size_str, cycle_str | field_strs]) do
    size = String.trim(size_str) |> String.to_integer()
    cycle = String.trim(cycle_str) |> String.to_integer()
    filled_fields_map =
      field_strs
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(
          fn field_str ->
            [row, col, value] =
              field_str
              |> String.split(~r/\s+/, trim: true)
              |> Enum.map(&String.to_integer/1)
            {{row, col}, value}
          end
        )
      |> Map.new()
    {size, cycle, filled_fields_map}
  end


  # Spirális koordinátalista generálása n×n-es táblára
  @spec generate_spiral_coords(size :: size()) :: result :: [field()]
  defp generate_spiral_coords(size), do: generate_spiral_coords(1, 1, size, size, [])

  @spec generate_spiral_coords(left :: integer(),
                               top :: integer(),
                               right :: integer(),
                               bottom :: integer(),
                               acc :: [field()]) :: result :: [field()]

  # Ha a bal szélső oszlop nagyobb, mint a jobb; vagy a felső sor nagyobb, mint az alsó, akkor vége
  defp generate_spiral_coords(left, top, right, bottom, acc)
    when left > right or top > bottom, do: acc

  # Ha csak egy mező maradt, azt adjuk hozzá
  defp generate_spiral_coords(left, top, right, bottom, acc)
    when left == right and top == bottom, do: acc ++ [{top, left}]

  # Hozzáadjuk a külső réteget spirálisan, majd folytatjuk beljebb
  defp generate_spiral_coords(left, top, right, bottom, acc) do
    # Felső sor balról jobbra
    top_row = for col <- left..right, do: {top, col}

    # Jobb oszlop fentről lefelé (top+1-től, mert sarkot már bejártuk)
    right_col = for row <- (top+1)..bottom, do: {row, right}

    # Alsó sor jobbról balra (ha több sor van)
    bottom_row = if bottom > top, do: (for col <- (right-1)..left//-1, do: {bottom, col}), else: []

    # Bal oszlop lentről felfelé (ha több oszlop van)
    left_col = if right > left, do: (for row <- (bottom-1)..(top+1)//-1, do: {row, left}), else: []
    layer = top_row ++ right_col ++ bottom_row ++ left_col
    generate_spiral_coords(left+1, top+1, right-1, bottom-1, acc ++ layer)
  end


  # A spirális koordinátalistához hozzárendeljük a kitöltött értékeket vagy nil-t
  @spec assign_values_to_coords(spiral_fields :: [field()], filled_fields_map :: map()) :: result :: [field_opt_value()]
  defp assign_values_to_coords(spiral_fields, filled_fields_map) do
    Enum.map(
      spiral_fields,
      fn field ->
        {field, Map.get(filled_fields_map, field, nil)}
      end
    )
  end

end
