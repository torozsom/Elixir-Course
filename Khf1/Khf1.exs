defmodule Khf1 do
  @moduledoc """
  Hányféle módon állítható elő a célérték

  @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"

  @date   "2025-09-27"
  """


  @type ertek() :: integer() # az összeg előállítására felhasználható érték (0 < ertek)
  @type darab() :: integer() # az értékből rendelkezésre álló maximális darabszám (0 ≤ darabszám)
  @type ertekek() :: %{ertek() => darab()}



  @doc """
  Visszaadja, hány **különböző módon** állítható elő a `celertek` a megadott multihalmazból.
  A darab=0 azt jelenti, hogy az adott értékből **korlátlan** mennyiség használható.
  Az összeadandók sorrendje és a zárójelezés nem számít (kombinációk).
  """
  @spec hanyfele(ertekek :: ertekek(), celertek :: integer()) :: integer()
  # Negatív célérték: nincs megoldás.
  def hanyfele(_ertekek, celertek) when celertek < 0, do: 0
  # Nulla célérték: az üres összeadás az egyetlen megoldás.
  def hanyfele(_ertekek, 0), do: 1

  # Fő ág: ellenőrzés, normalizálás, GCD-pruning, rendezés, majd DP (map alapú).
  def hanyfele(ertekek, celertek) when is_map(ertekek) and is_integer(celertek) do
    # Csak releváns (pozitív és beférő) értékek megtartása.
    parok =
      ertekek
      |> Enum.filter(fn {ertek, darab} ->
        is_integer(ertek) and ertek > 0 and is_integer(darab) and ertek <= celertek
      end)
      |> Enum.map(fn {ertek, darab} -> {ertek, darab} end)

    # Ha nincs használható érték és cél > 0: nincs megoldás.
    if parok == [] do
      0
    else
      # GCD-pruning: ha a cél nem osztható az összes érték LNKO-jával, nincs megoldás.
      ertek_lista = Enum.map(parok, &elem(&1, 0))
      lnko = lnko_lista(ertek_lista)

      if rem(celertek, lnko) != 0 do
        0
      else
        # Skálázás LNKO-val (gyorsítás).
        {parok, celertek} =
          if lnko > 1 do
            {Enum.map(parok, fn {e, d} -> {div(e, lnko), d} end), div(celertek, lnko)}
          else
            {parok, celertek}
          end

        # Rendezzük érték szerint (kombinációk helyes számlálása).
        parok = Enum.sort_by(parok, &elem(&1, 0))

        # DP kezdőállapot: csak dp[0] = 1, minden más 0 (nincs kulcs → 0).
        dp0 = %{0 => 1}

        # Érménként frissítünk: korlátlan (darab=0) → nagy limit, különben a tényleges limit.
        dp_vegso =
          Enum.reduce(parok, dp0, fn {ertek, darab}, dp_regi ->
            # Ha az érték nagyobb a célnál, nem számít.
            if ertek > celertek do
              dp_regi
            else
              # Effektív limit: korlátlan esetben a legnagyobb beférő darabszámot vesszük.
              eff_limit =
                if darab == 0 do
                  div(celertek, ertek)
                else
                  min(darab, div(celertek, ertek))
                end

              korlatos_csuszoablak_frissites_map(dp_regi, ertek, eff_limit, celertek)
            end
          end)

        # Eredmény: dp[cél] (ha nincs kulcs, 0).
        Map.get(dp_vegso, celertek, 0)
      end
    end
  end

  @doc """
  Korlátos (és a korlátlan esetre is alkalmas) frissítés **map-alapú** DP-hez.
  Maradékosztályonként (r = 0..ertek-1) haladunk, a sorozat: t = r, r+ertek, r+2*ertek, ...
  Minden ilyen sorozatra csúszó ablakos összegzést (ablakméret = limit + 1) végzünk:
    new[t] = Σ_{k=0..min(limit, floor(t/ertek))} old[t - k*ertek]
  """
  @spec korlatos_csuszoablak_frissites_map(
          %{non_neg_integer() => non_neg_integer()},
          pos_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: %{non_neg_integer() => non_neg_integer()}
  # Ha a limit 0 (nem használható az érték), akkor az új dp azonos a régivel.
  defp korlatos_csuszoablak_frissites_map(dp_regi, _ertek, 0, _celertek), do: dp_regi

  # Általános eset: residue-okon végigmegyünk és építjük az új dp-t.
  defp korlatos_csuszoablak_frissites_map(dp_regi, ertek, limit, celertek) do
    # Kezdünk a régi dp másolatával; fokozatosan írjuk bele az új eredményeket.
    # (Funkcionális, per-lépés új map jön létre, de csak a szükséges kulcsokra.)
    Enum.reduce(0..min(ertek - 1, celertek), dp_regi, fn maradek, dp_aktualis ->
      # Végigszkenneljük az adott maradékosztály indexeit és építjük az új dp-t.
      processzal_maradekosztaly(dp_regi, dp_aktualis, ertek, limit, maradek, celertek)
    end)
  end

  @doc """
  Egy maradékosztály feldolgozása: t = maradek, maradek+ertek, ... indexekre csúszó ablakot tartunk fenn.
  `dp_regi`-ből olvasunk, `dp_aktualis`-ba írunk.
  """
  @spec processzal_maradekosztaly(
          %{non_neg_integer() => non_neg_integer()},
          %{non_neg_integer() => non_neg_integer()},
          pos_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: %{non_neg_integer() => non_neg_integer()}
  # Ha a maradék nagyobb a célnál, nincs t ennél a maradéknál.
  defp processzal_maradekosztaly(_dp_regi, dp_aktualis, _ertek, _limit, maradek, celertek)
       when maradek > celertek,
       do: dp_aktualis

  # Indítás: első index ezen a sorozaton a maradek, kezdeti ablakösszeg = 0, lépésszámláló = 0.
  defp processzal_maradekosztaly(dp_regi, dp_aktualis, ertek, limit, maradek, celertek) do
    bejar_maradek_sorozat(
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

  @doc """
  A maradékosztály sorozatának végigjárása csúszó ablakkal.
  `lepes` számolja, hányadik elemnél járunk a sorozatban (0-alapú),
  `ablak_osszeg` az aktuális csúszó összeg.
  """
  @spec bejar_maradek_sorozat(
          %{non_neg_integer() => non_neg_integer()},
          %{non_neg_integer() => non_neg_integer()},
          pos_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          integer()
        ) :: %{non_neg_integer() => non_neg_integer()}
  # Kilépés: túlmentünk a célindexen.
  defp bejar_maradek_sorozat(
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

  # Fő lépés: új belépő a régiből, szükség esetén régi elem kiesik az ablakból; új dp-érték beírása.
  defp bejar_maradek_sorozat(
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
    belepo = Map.get(dp_regi, index, 0)
    osszeg1 = ablak_osszeg + belepo

    osszeg2 =
      if lepes >= limit + 1 do
        kieso_index = index - (limit + 1) * ertek
        osszeg1 - Map.get(dp_regi, kieso_index, 0)
      else
        osszeg1
      end

    dp_uj = Map.put(dp_aktualis, index, osszeg2)

    bejar_maradek_sorozat(
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

  @doc """
  Több pozitív egész legnagyobb közös osztója (LNKO).
  """
  @spec lnko_lista([pos_integer()]) :: pos_integer()
  # Egyelemű lista LNKO-ja önmaga.
  defp lnko_lista([x]), do: x
  # Páronkénti redukció, amíg egy szám marad.
  defp lnko_lista([x, y | tobbi]), do: lnko_lista([Integer.gcd(x, y) | tobbi])

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
