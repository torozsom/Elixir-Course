% Runner to execute hibas_teszteset/3 from tesztek.txt against tekercsekk/2
:- ['khf4.pl'].
:- ['tesztek.txt'].

main :-
    findall(A-E-S, hibas_teszteset(A,E,S), L),
    (   L = []
    ->  writeln('no failures')
    ;   forall(member(X, L), writeln(X))
    ),
    halt.