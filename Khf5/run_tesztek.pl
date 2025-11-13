% Runner for Khf5: executes teszteset/2 from tesztek.txt and compares to eredmeny/2
:- ['khf5.pl'].
:- ['tesztek.txt'].

main :-
    current_prolog_flag(argv, Argv),
    ( Argv = [IdAtom|Rest] -> atom_number(IdAtom, Id), (member(verbose, Rest) -> Verbose = true ; Verbose = false), run_one(Id, Verbose)
    ; run_all).

run_all :-
    findall(Id-Status,
            ( teszteset(Id, CE), eredmeny(Id, Expected), eval_case(CE, Actual),
              ( same_result(Expected, Actual) -> Status = ok ; Status = fail(Expected, Actual) ) ),
            Results),
    include(failing, Results, FailingList),
    length(FailingList, FailCount),
    writeln(failures(FailCount)),
    ( FailCount =:= 0 -> true
    ; forall(member(Id-_, FailingList), writeln(fail(Id)))
    ),
    halt.

run_one(Id, Verbose) :-
    ( teszteset(Id, CE), eredmeny(Id, Expected) -> true ; writeln(error(no_such_test(Id))), halt ),
    eval_case(CE, Actual),
    ( same_result(Expected, Actual) -> writeln(ok(Id))
    ; writeln(fail(Id)), ( Verbose == true -> writeln(expected(Expected)), writeln(actual(Actual)) ; true )
    ),
    halt.

failing(_-fail(_, _)).
failing(_-fail). % safety in case variant

% Evaluate a case term of the form Vars^Goal
eval_case(Vars^Goal, Actual) :-
    ( is_list(Vars) -> true ; Vars = [] ),
    ( call(Goal) -> ( Vars = [] -> Actual = true ; Actual = Vars )
    ; Actual = false
    ).

% Compare expected vs actual allowing strict term equality
same_result(Expected, Actual) :- Expected == Actual.
