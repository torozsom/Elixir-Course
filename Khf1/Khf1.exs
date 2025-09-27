defmodule Khf1 do
  @moduledoc """
  Hányféle módon állítható elő a célérték

  @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"

  @date   "2025-09-27"
  """



  @type ertek() :: integer() # az összeg előállítására felhasználható érték (0 < ertek)
  @type darab() :: integer() # az értékből rendelkezésre álló maximális darabszám (0 <= darabszám)
  @type ertekek() :: %{ertek() => darab()}



  @doc "Visszaadja, hány különböző módon állítható elő a célérték a megadott multihalmazból."
  @spec hanyfele(ertekek :: ertekek(), celertek :: integer()) :: integer()
  # Negatív cél -> 0
  def hanyfele(_ertekek, celertek) when celertek < 0, do: 0
  # Nulla cél -> 1 (üres összeadás)
  def hanyfele(_ertekek, 0), do: 1

  # Általános eset: szűrés -> LNKO-ellenőrzés -> DP -> eredmény
  def hanyfele(ertekek, celertek) when is_map(ertekek) and is_integer(celertek) do
    parok = szur_es_rendez(ertekek, celertek)

    case parok do
      [] -> 0
      _ ->
        case ellenoriz_es_skalaz(parok, celertek) do
          :nincs_megoldas -> 0
          {:ok, parok_skalazott, celertek_skalazott} ->
            dp0 = dp_inicializal(celertek_skalazott)
            dp_vegso = dp_frissit_minden_ertekkel(dp0, parok_skalazott, celertek_skalazott)
            :array.get(celertek_skalazott, dp_vegso)
        end
    end
  end



  # Bemenet-szűrés és rendezés: csak pozitív értékek, nemnegatív darabszámok, ertek <= celertek; növekvő sorrendben.
  @spec szur_es_rendez(ertekek(), non_neg_integer()) :: [{pos_integer(), non_neg_integer()}]
  defp szur_es_rendez(ertekek, celertek) do
    ertekek
    |> Enum.filter(
      fn {ertek, darab} ->
        is_integer(ertek) and ertek > 0 and is_integer(darab) and darab >= 0 and ertek <= celertek
      end
    )
    |> Enum.sort_by(&elem(&1, 0))
  end


  # Több pozitív egész legnagyobb közös osztója (LNKO).
  @spec lnko_lista([pos_integer()]) :: pos_integer()
  # Egyelemű lista LNKO-ja önmaga.
  defp lnko_lista([x]), do: x
  # Páronkénti redukció, amíg egy szám marad.
  defp lnko_lista([x, y | tobbi]), do: lnko_lista([Integer.gcd(x, y) | tobbi])


  # LNKO-ellenőrzés és skálázás: ha T % LNKO != 0 -> nincs megoldás, különben osztunk LNKO-val.
  @spec ellenoriz_es_skalaz([{pos_integer(), non_neg_integer()}], non_neg_integer()) ::
          :nincs_megoldas | {:ok, [{pos_integer(), non_neg_integer()}], non_neg_integer()}
  defp ellenoriz_es_skalaz(parok, celertek) do
    lnko = parok |> Enum.map(&elem(&1, 0)) |> lnko_lista()

    if rem(celertek, lnko) != 0 do
      :nincs_megoldas
    else
      if lnko > 1 do
        parok_s = Enum.map(parok, fn {e, d} -> {div(e, lnko), d} end)
        {:ok, parok_s, div(celertek, lnko)}
      else
        {:ok, parok, celertek}
      end
    end
  end


  # DP tömb inicializálása: méret T+1, alap 0; dp[0] = 1 (üres összeadás).
  @spec dp_inicializal(non_neg_integer()) :: :array.array()
  defp dp_inicializal(celertek) do
    arr = :array.new(size: celertek + 1, default: 0)
    :array.set(0, 1, arr)
  end


  # Effektív korlát: darab=0 -> floor(T/v); különben min(darab, floor(T/v)).
  @spec effektiv_limit(non_neg_integer(), pos_integer(), non_neg_integer()) :: non_neg_integer()
  defp effektiv_limit(darab, ertek, celertek) do
    max_db = div(celertek, ertek)
    if darab == 0, do: max_db, else: min(darab, max_db)
  end


  # Maradékosztály sorozatának bejárása csúszó ablakkal, lepes számlál, ablak_osszeg = mozgó összeg.
  @spec maradeksorozat_bejaras(
          :array.array(),
          :array.array(),
          pos_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          integer()
        ) :: :array.array()
  # Kilépés: túlmentünk a célindexen.
  defp maradeksorozat_bejaras(
         _dp_regi,
         dp_aktualis,
         _ertek,
         _limit,
         _maradek,
         index,
         _lepes,
         celertek,
         _ablak_osszeg
       )
       when index > celertek,
       do: dp_aktualis

  # Fő lépés: új belépő a régiből, szükség esetén régi elem kiesik az ablakból, új dp-érték beírása.
  defp maradeksorozat_bejaras(
         dp_regi,
         dp_aktualis,
         ertek,
         limit,
         maradek,
         index,
         lepes,
         celertek,
         ablak_osszeg
       ) do
    belepo = :array.get(index, dp_regi)
    osszeg1 = ablak_osszeg + belepo

    osszeg2 =
      if lepes >= limit + 1 do
        kieso_index = index - (limit + 1) * ertek
        osszeg1 - :array.get(kieso_index, dp_regi)
      else
        osszeg1
      end

    dp_uj = :array.set(index, osszeg2, dp_aktualis)

    maradeksorozat_bejaras(
      dp_regi,
      dp_uj,
      ertek,
      limit,
      maradek,
      index + ertek,
      lepes + 1,
      celertek,
      osszeg2
    )
  end


  # Egy maradékosztály (r, r+v, r+2v, ...) feldolgozása csúszó ablakkal; dp_regi-ből olvas, dp_aktualis-ba ír.
  @spec maradekosztaly_feldolgozas(
          :array.array(),
          :array.array(),
          pos_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :array.array()
  # Ha a maradék nagyobb a célnál, nincs t ennél a maradéknál.
  defp maradekosztaly_feldolgozas(_dp_regi, dp_aktualis, _ertek, _limit, maradek, celertek)
       when maradek > celertek,
       do: dp_aktualis

  # Indítás: első index ezen a sorozaton a maradek, kezdeti ablakösszeg = 0, lépésszámláló = 0.
  defp maradekosztaly_feldolgozas(dp_regi, dp_aktualis, ertek, limit, maradek, celertek) do
    maradeksorozat_bejaras(
      dp_regi,
      dp_aktualis,
      ertek,
      limit,
      maradek,
      maradek,
      0,
      celertek,
      0
    )
  end


  # Csúszóablakos frissítés: r=0..v-1 maradékosztályokra bontva, ablakméret = limit+1.
  @spec csuszoablak_frissites(
          :array.array(),
          pos_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :array.array()
  # Ha a limit 0 (nem használható az érték), akkor az új dp azonos a régivel.
  defp csuszoablak_frissites(dp_regi, _ertek, 0, _celertek), do: dp_regi

  # Általános eset: maradékosztályon végigmegyünk és építjük az új dp-t.
  defp csuszoablak_frissites(dp_regi, ertek, limit, celertek) do
  # Új DP-tömb nullákkal; ebbe írjuk az éppen feldolgozott érték hatását.
    dp_uj0 = :array.new(size: celertek + 1, default: 0)

    Enum.reduce(
      0..min(ertek - 1, celertek),
      dp_uj0,
      fn maradek, dp_aktualis ->
        maradekosztaly_feldolgozas(dp_regi, dp_aktualis, ertek, limit, maradek, celertek)
      end)
  end


  # Egy érték érvényesítése: effektív limit számítás, majd csúszóablakos frissítés.
  @spec dp_egy_ertekkel(:array.array(), pos_integer(), non_neg_integer(), non_neg_integer()) :: :array.array()
  defp dp_egy_ertekkel(dp_regi, ertek, darab, celertek) do
    if ertek > celertek do
      dp_regi
    else
      limit = effektiv_limit(darab, ertek, celertek)
      csuszoablak_frissites(dp_regi, ertek, limit, celertek)
    end
  end


  # Összes érték feldolgozása a DP-n: csúszóablakos frissítés.
  @spec dp_frissit_minden_ertekkel(:array.array(), [{pos_integer(), non_neg_integer()}], non_neg_integer()) :: :array.array()
  defp dp_frissit_minden_ertekkel(dp0, parok, celertek) do
    Enum.reduce(
      parok,
      dp0,
      fn {ertek, darab}, dp_regi ->
        dp_egy_ertekkel(dp_regi, ertek, darab, celertek)
      end
    )
  end

end



defmodule Khf1Testcases do

  testcases = # {vals, target, count}]
    [
      {%{1 => 2, 3 => 3, 5 => 4},             20,       3}, #0
      {%{2 => 2, 1 => 10, 5 => 5},            28,       6}, #1
      {%{20 => 3, 10 => 7, 5 => 8},          110,      14}, #2
      {%{3 => 3, 2 => 10, 1 => 10},            5,       5}, #3
      {%{5 => 300, 2 => 100, 1 => 500},     1500,  10_121}, #4
      {%{10 => 0, 20 => 0, 50 => 0},      25_000, 313_501}, #5
      {%{10 => 3000, 50 => 0, 20 => 0},   30_000, 451_201}, #6
      {%{10 => 3000, 20 => 0, 50 => 600}, 33_000, 536_761}, #7
      {%{3 => 0, 1 => 100, 2 => 0},       49_000, 824_034}, #8
      {%{3 => 30000, 1 => 2, 2 => 1},    300_005,       0}, #9
    ]

  for {i, {vals, target, count}} <- Enum.zip(0..length(testcases)-1, testcases), res = Khf1.hanyfele(vals, target) do
    {"Teszteset #{i}", res == count}
    |> IO.inspect(label: "Várt eredmény " <> (res |> Integer.to_string() |> String.pad_leading(7, " ")))
  end

end
