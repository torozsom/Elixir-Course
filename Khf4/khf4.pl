% ------------------------------------------------------------
% KHF4
% @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"
% @date   "2025-11-06" 
% ------------------------------------------------------------



% tekercsekk(M, Mx): Mx egy listák listájaként ábrázolt, 0 és M
% közötti egészekből álló mátrix, ahol a 0 érték jelöli az üres
% pozíciókat.
% Az eljárás akkor és csak akkor fut le sikeresen, ha Mx egy 
% számtekercs feladvány helyes megoldását írja le.
tekercsekk(M, Matrix) :-
        matrix_meret(Matrix, N),
        N >= M,
        sorok_helyesek(M, N, Matrix),
        transzponal(Matrix, Oszlopok),
        sorok_helyesek(M, N, Oszlopok),
        tekercs_szekvencia_helyes(M, Matrix).



reverse(Lista, Forditott) :- reverse_acc(Lista, [], Forditott).
reverse_acc([], Acc, Acc).
reverse_acc([H|T], Acc, R) :- reverse_acc(T, [H|Acc], R).


% ------------------------------------------------------------
% 1. feltétel: sor- és oszlop-ellenőrzés
% Egy sor helyes, ha:
%  - hossza N;
%  - a pozitív elemek száma M és ezek rendezve épp az 1..M sorozatot adják.
% Ekkor a 0-k száma automatikusan N-M (Z), és az 1..M mindegyike pontosan egyszer szerepel.
% ------------------------------------------------------------

sorok_helyesek(_, _, []).
sorok_helyesek(M, N, [Sor|TovabbiSorok]) :-
        sor_helyes(M, N, Sor),
        sorok_helyesek(M, N, TovabbiSorok).


sor_helyes(M, N, Sor) :-
        length(Sor, N), !,
        nemnulla_elemek(Sor, Pozitivak),
        length(Pozitivak, M), !,
        zeros_szam(Sor, Z0), Z is N - M, Z0 =:= Z, !,
        pontosan_egyszer_1tolM(Pozitivak, M).

% pontosan_egyszer_1tolM(Lista, M): az 1..M mindegyike pontosan egyszer szerepel a listában
pontosan_egyszer_1tolM(Lista, M) :-
        pontosan_egyszer_1tolM(Lista, 1, M).

pontosan_egyszer_1tolM(_, K, M) :- K > M, !.
pontosan_egyszer_1tolM(Lista, K, M) :-
        elofordulas_szam(Lista, K, C),
        C =:= 1,
        K1 is K + 1,
        pontosan_egyszer_1tolM(Lista, K1, M).

% elofordulas_szam(Lista, Elem, Darab): megszámolja Elem előfordulásait
elofordulas_szam([], _, 0).
elofordulas_szam([X|Xs], E, C) :-
        (   X =:= E -> elofordulas_szam(Xs, E, C1), C is C1 + 1
        ;   elofordulas_szam(Xs, E, C)
        ).


nemnulla_elemek([], []).
nemnulla_elemek([0|T], R) :- !, nemnulla_elemek(T, R).
nemnulla_elemek([H|T], [H|R]) :- H =\= 0, nemnulla_elemek(T, R).


% ------------------------------------------------------------
% Mátrix-méret és transzponálás
% ------------------------------------------------------------

matrix_meret(Matrix, N) :-
        length(Matrix, N),
        minden_sor_hossza(Matrix, N).

% minden_sor_hossza(Mx, N): igaz, ha Mx minden sora N hosszú
minden_sor_hossza([], _).
minden_sor_hossza([Sor|T], N) :- length(Sor, N), minden_sor_hossza(T, N).


transzponal([], []) :- !.
transzponal([[]|_], []) :- !.
transzponal(M, [Sor|Sorok]) :-
        fejek(M, Sor),
        farkak(M, M1),
        transzponal(M1, Sorok).


fejek([], []).
fejek([[H|_]|Ls], [H|Hs]) :- fejek(Ls, Hs).

farkak([], []).
farkak([[ _]|Ls], [[]|Rs]) :- farkak(Ls, Rs).
farkak([[_|T]|Ls], [T|Rs]) :- farkak(Ls, Rs).


% ------------------------------------------------------------
% 2. feltétel: spirál bejárás ellenőrzése
% ------------------------------------------------------------

tekercs_szekvencia_helyes(M, Matrix) :-
        matrix_meret(Matrix, N), !,
        tekercs_bejaras(Matrix, Bejart), !,
        nemnulla_elemek(Bejart, NonZero),
        ExpectedLen is N * M,
        length(NonZero, ExpectedLen), !,
        check_repeating_cycle(NonZero, M).


% Spirál-bejárás
%  - felső sor balról jobbra
%  - jobb szélső oszlop felülről lefelé 
%  - alsó sor jobbról balra
%  - bal szélső oszlop alulról felfelé 
%  - rekurzívan belül folytatva

tekercs_bejaras([], []).
tekercs_bejaras([[]|_], []).
tekercs_bejaras([FelsoSor|TobbiSor], Eredmeny) :-
        (   TobbiSor = []
        ->  Eredmeny = FelsoSor
        ;   szetvalaszt_utolsot(TobbiSor, KozepsoSorok, AlsoSor),
                szetbont_utolso_oszlop(KozepsoSorok, KozepsoSorokNelkulUtolso, JobbOszlop),
                reverse(AlsoSor, AlsoSorVissza),
                szetbont_elso_oszlop(KozepsoSorokNelkulUtolso, BelsoSorok, BalOszlop),
                reverse(BalOszlop, BalOszlopVissza),
                tekercs_bejaras(BelsoSorok, Belso),
                hozzafuz(FelsoSor, JobbOszlop, T1),
                hozzafuz(T1, AlsoSorVissza, T2),
                hozzafuz(T2, BalOszlopVissza, T3),
                hozzafuz(T3, Belso, Eredmeny)
        ).


% split_last(List, Init, Last): List = Init ++ [Last]
szetvalaszt_utolsot([X], [], X) :- !.
szetvalaszt_utolsot([H|T], [H|Elozmeny], Utolso) :- T \= [], szetvalaszt_utolsot(T, Elozmeny, Utolso).


% strip_last(Rows, RowsNoLast, LastCol):
% minden sor utolsó eleme a LastCol-ba kerül, a maradék a RowsNoLast-ba
szetbont_utolso_oszlop([], [], []).
szetbont_utolso_oszlop([Sor|Sorok], [Eleje|Elek], [Utolso|UtolsoOszt]) :-
        szetvalaszt_utolsot(Sor, Eleje, Utolso),
        szetbont_utolso_oszlop(Sorok, Elek, UtolsoOszt).


% strip_first(Rows, RowsNoFirst, FirstCol):
% minden sor első eleme a FirstCol-ba, a maradék a RowsNoFirst-ba
szetbont_elso_oszlop([], [], []).
% Speciális eset: a sor már üres (szélesség 0-ra csökkent). Ekkor nincs első elem.
szetbont_elso_oszlop([[]|Sorok], [[]|TSorok], ElsoElemek) :-
        szetbont_elso_oszlop(Sorok, TSorok, ElsoElemek).
szetbont_elso_oszlop([[H|T]|Sorok], [T|TSorok], [H|ElsoElemek]) :-
        szetbont_elso_oszlop(Sorok, TSorok, ElsoElemek).


hozzafuz([], Ys, Ys).
hozzafuz([X|Xs], Ys, [X|Zs]) :- hozzafuz(Xs, Ys, Zs).


% zeros_szam(Sor, Darab): megszámolja a 0 érték előfordulásait
zeros_szam([], 0).
zeros_szam([0|T], C) :- zeros_szam(T, C1), C is C1 + 1.
zeros_szam([X|T], C) :- X =\= 0, zeros_szam(T, C).


% check_repeating_cycle(List, M): List = [1,2,..,M,1,2,..,M,...]
check_repeating_cycle([], _) :- !.
check_repeating_cycle(List, M) :-
        check_cycle_elements(List, M, 1).

check_cycle_elements([], _, _) :- !.
check_cycle_elements([X|Xs], M, Expected) :-
        X =:= Expected, !,
        (   Expected =:= M -> NextExpected = 1
        ;   NextExpected is Expected + 1
        ),
        check_cycle_elements(Xs, M, NextExpected).