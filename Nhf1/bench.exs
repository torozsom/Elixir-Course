Mix.install([
  {:benchee, "~> 1.3"}
])

# Silence test output from nhf1.ex when requiring the file (it prints testcase results).
prev_gl = Process.group_leader()
{:ok, io_dev} = StringIO.open("")
Process.group_leader(self(), io_dev)
Code.require_file("nhf1.ex", __DIR__)
Process.group_leader(self(), prev_gl)
StringIO.close(io_dev)

all_inputs = %{
  "tc0  3x3 m=2" => {3, 2, []},
  "tc1  4x4 m=2" => {4, 2, [{{1,1}, 1}, {{1,4}, 2}]},
  "tc2  4x4 m=1" => {4, 1, [{{1,1}, 1}]},
  "tc3  4x4 m=3" => {4, 3, []},
  "tc4  5x5 m=3" => {5, 3, [{{1,3}, 1}, {{2,2}, 2}]},
  "tc5  6x6 m=3" => {6, 3, [{{1,5}, 2}, {{2,2}, 1}, {{4,6}, 1}]},
  "tc6  6x6 m=3" => {6, 3, [{{1,5}, 2}, {{2,2}, 1}, {{4,6}, 1}]},
  "tc7  6x6 m=3" => {6, 3, [{{2,4}, 3}, {{3,3}, 1}, {{3,6}, 2}, {{6,1}, 3}]},
  "tc8  7x7 m=3" => {7, 3, [{{1,1}, 1}, {{2,4}, 3}, {{3,4}, 1}, {{4,3}, 3}, {{6,6}, 2}, {{7,7}, 3}]},
  "tc9  8x8 m=3" => {8, 3, [{{1,4}, 1}, {{1,7}, 3}, {{2,3}, 2}, {{2,4}, 3}, {{3,2}, 1}, {{4,7}, 1}, {{7,7}, 2}]},
  "tc10 8x8 m=4" => {8, 4, [{{2,3}, 4}, {{3,3}, 2}, {{6,1}, 1}, {{7,6}, 3}]},
  "tc11 9x9 m=3" => {9, 3, [{{1,7}, 3}, {{3,1}, 1}, {{6,1}, 3}, {{6,2}, 2}, {{6,6}, 1}, {{8,4}, 3}, {{9,2}, 1}]}
}

# Optional filter: set BENCH_FILTER to a substring/regex to select inputs
filter = System.get_env("BENCH_FILTER")
inputs =
  case filter do
    nil -> all_inputs
    "" -> all_inputs
    f ->
      regex = Regex.compile!(f)
      all_inputs
      |> Enum.filter(fn {name, _} -> Regex.match?(regex, name) end)
      |> Map.new()
  end

Benchee.run(
  %{
    "Nhf1.helix" => fn {n, m, cons} -> Nhf1.helix({n, m, cons}) end
  },
  inputs: inputs,
  time: 2,
  memory_time: 0.5,
  warmup: 1,
  parallel: 1,
  before_scenario: fn input -> :erlang.garbage_collect(self()); input end,
  after_scenario: fn _input -> :erlang.garbage_collect(self()); :ok end,
  formatters: [Benchee.Formatters.Console]
)
