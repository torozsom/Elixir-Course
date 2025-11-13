% Simple runner to list failing tests
:- ['khf4.pl'].
:- ['tesztek.txt'].

main :-
    findall(A-E-S, hibas_teszteset(A,E,S), L),
    (   L = []
    ->  writeln('no failures')
    ;   forall(member(X, L), writeln(X))
    ),
    halt.