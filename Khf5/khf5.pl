% ------------------------------------------------------------
% Khf5 – Számtekercs: kezdő tábla és ismert szűkítés
%
% @author "Toronyi Zsombor <toronyizsombor@edu.bme.hu> [S8F7DV]"
% @date   "2025-11-13" 
% ------------------------------------------------------------



:- use_module(library(lists)).  % ensures availability of nth1/4 and related list predicates



% kezdotabla(+FLeiro, -Mx)
% FLeiro = szt(N, M, Givens), ahol Givens listája i(R,C,E) strukturák.
% Az Mx mátrix N x N, minden cella domainje:
%  - ha adott: [E]
%  - különben: [0..M], ha N > M; vagy [1..M], ha N = M

kezdotabla(szt(N, M, Givens), Mx) :-
	base_domain(N, M, Dom),
	make_matrix(N, N, Dom, Mx0),
	apply_givens(Givens, Mx0, Mx).



% ismert_szukites(+FLeiro, +Mx0, -Mx)
% Ismert (egyelemű lista) értékekből induló sor/oszlop-alapú szűkítések
% ismétlése mindaddig, amíg létezik egyelemű lista. Ha nem történik
% szűkítés, az eljárás meghiúsul. Ha ellentmondás adódik, Mx = [].

ismert_szukites(szt(N, M, _), Mx0, Mx) :-
	zero_quota(N, M, Z),
	propagate_until_fixpoint(Mx0, N, M, Z, Mx1, DidChange),
	( Mx1 == [] -> Mx = []
	; DidChange == true -> Mx = Mx1
	; % nem volt egyelemű tartomány, vagy nem történt szűkítés
	  fail
	).



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Segédeljárások – kezdotabla


base_domain(N, M, Dom) :-
	( N > M -> range_list(0, M, Dom)
	; N =:= M -> range_list(1, M, Dom)
	).


range_list(Lo, Hi, L) :-
	Lo =< Hi,
	range_list_(Lo, Hi, L).


range_list_(I, Hi, [I|Rest]) :-
	I < Hi, !,
	I1 is I + 1,
	range_list_(I1, Hi, Rest).
range_list_(Hi, Hi, [Hi]).


make_matrix(0, _Cols, _Elem, []).
make_matrix(Rows, Cols, Elem, [Row|Rest]) :-
	Rows > 0,
	make_row(Cols, Elem, Row),
	R1 is Rows - 1,
	make_matrix(R1, Cols, Elem, Rest).


make_row(0, _Elem, []).
make_row(N, Elem, [Elem|Rest]) :-
	N > 0,
	N1 is N - 1,
	make_row(N1, Elem, Rest).


apply_givens([], Mx, Mx).
apply_givens([i(R,C,E)|Gs], Mx0, Mx) :-
	set_cell(Mx0, R, C, [E], Mx1),
	apply_givens(Gs, Mx1, Mx).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Segédeljárások – ismert_szukites


% Z = n - m – a 0-k száma egy sorban/oszlopban
zero_quota(N, M, Z) :- Z is N - M.


% propagate_until_fixpoint(+Mx0, +N, +M, +Z, -Mx, -DidChange)
% Iteratív szűkítés: mindig kiválasztunk egy egyelemű listát és propagálunk.
% Ha nincs több egyelemű lista, visszaadjuk a jelenlegi mátrixot.
propagate_until_fixpoint(Mx0, N, M, Z, Mx, DidChange) :-
	find_singleton_cell(Mx0, R, C, E), !,
	( E > 0 ->
		propagate_fixed_positive(Mx0, R, C, E, Mx1)
	  ; % E == 0
		propagate_fixed_zero(Mx0, N, M, Z, R, C, Mx1)
	),
	( Mx1 == [] ->
		Mx = [], DidChange = true
	;
		propagate_until_fixpoint(Mx1, N, M, Z, Mx, _),
		DidChange = true
	).
propagate_until_fixpoint(Mx, _N, _M, _Z, Mx, false).


% Egyelemű lista keresése (balról-jobbra, fentről-lefelé)
find_singleton_cell(Mx, R, C, E) :-
	get_row_at_index(Mx, 1, R, Row),
	find_singleton_in_row(Row, 1, C, E).
find_singleton_cell([_|Rs], R, C, E) :-
	find_singleton_cell(Rs, R1, C, E),
	R is R1 + 1.


get_row_at_index([Row|_], R, R, Row).
get_row_at_index([_|Rs], I, R, Row) :- I1 is I + 1, get_row_at_index(Rs, I1, R, Row).


find_singleton_in_row([X|_], C, C, E) :- is_singleton_list(X, E), !.
find_singleton_in_row([_|Xs], I, C, E) :- I1 is I + 1, find_singleton_in_row(Xs, I1, C, E).


is_singleton_list([E], E) :- integer(E).


% Nem nulla egyelemű propagáció
propagate_fixed_positive(Mx0, R, C, E, Mx) :-
	% 1) Sor szűkítés (R. sor, kivéve (R,C) cella)
	nth1(R, Mx0, RowR, RestRows),
	remove_value_from_row_except_index(RowR, C, E, NewRowR, FlagR),
	( FlagR = contradiction -> Mx = [] ;
	  % 2) Ideiglenes mátrix összeállítása az új sorral
	  set_matrix_row_at_index(RestRows, R, NewRowR, TempMx),
	  % 3) Oszlop szűkítés (C. oszlop minden sorban, kivéve R)
	  remove_value_from_column_except_row(TempMx, R, C, E, MxCol, FlagC),
	  ( FlagC = contradiction -> Mx = [] ;
		% 4) [E] -> E az (R,C) cellában
		set_cell(MxCol, R, C, E, Mx)
	  )
	).


% 0 egyelemű propagáció
propagate_fixed_zero(Mx0, _N, _M, Z, R, C, Mx) :-
	% 1) Az R. sorban és C. oszlopban minden [0] -> 0
	nth1(R, Mx0, RowR, RestRows1),
	collapse_zero_singleton_in_row(RowR, RowR1),
	collapse_zero_singleton_in_column(RestRows1, C, RestRows2),
	set_matrix_row_at_index(RestRows2, R, RowR1, M1),
	% 2) Sor-ellenőrzés és esetleges 0 elhagyás az R. sorban
	count_zeros_in_list(RowR1, ZRow),
	( ZRow > Z -> Mx = []
	; ZRow =:= Z ->
		remove_zero_from_row_domain_lists(RowR1, RowR2, FlagR),
		( FlagR = contradiction -> Mx = []
		; set_matrix_row_at_index(RestRows2, R, RowR2, M2a)
		)
	; % ZRow < Z, nincs teendő
	  M2a = M1
	),
	( M2a == [] -> Mx = []
	;  % 3) Oszlop-ellenőrzés
	  get_column_at_index(M2a, C, Col0),
	  count_zeros_in_list(Col0, ZCol0),
	  ( ZCol0 > Z -> Mx = []
	  ; ZCol0 =:= Z ->
		  remove_zero_from_column_domain_lists(M2a, C, M2b, FlagC0),
		  ( FlagC0 = contradiction -> Mx = []
		  ; get_column_at_index(M2b, C, Col1),
		    count_zeros_in_list(Col1, ZCol1),
		    ( ZCol1 =:= Z -> % teljes redukció a C oszlopban is
			  Mx = M2b
		      ; Mx = M2b )
		  )
	  ; Mx = M2a
	  )
	).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Sor/oszlop műveletek és domain-kezelés


% remove_value_from_row_except_index(+Row0, +SkipC, +E, -Row, -Flag)
% SkipC: annak az oszlopnak az indexe (1-alapú), amelyet nem szűkítünk.
remove_value_from_row_except_index(Row0, SkipC, E, Row, Flag) :-
    remove_value_from_row_except_index_(Row0, 1, SkipC, E, [], Rev, ok, Flag),
    reverse(Rev, Row).

remove_value_from_row_except_index_([], _Idx, _Skip, _E, Acc, Acc, Flag, Flag).
remove_value_from_row_except_index_([Cell|Rest], Idx, Skip, E, Acc, Out, _FlagIn, FlagOut) :-
	( Idx =:= Skip -> % skip this position
		Acc1 = [Cell|Acc], Flag1 = ok
	; remove_value_from_cell_domain(Cell, E, Cell1, Flag1),
	  ( Flag1 = contradiction -> FlagOut = contradiction, Out = [Cell|Rest] % early exit, keep remaining tail as-is
	  ; Acc1 = [Cell1|Acc]
	  )
	),
	( Flag1 = contradiction -> true
	; Idx1 is Idx + 1,
	  remove_value_from_row_except_index_(Rest, Idx1, Skip, E, Acc1, Out, ok, FlagOut)
	).


% remove_value_from_column(+Rows0, +SkipR, +C, +E, -Rows, -Flag)
% SkipR: annak a sornak az indexe (1-alapú), amelyet nem szűkítünk.
% Új oszlop-szűkítés teljes mátrixon: eredeti sorszám alapján kihagyja SkipR-t
remove_value_from_column_except_row(Mx0, SkipR, C, E, Mx, Flag) :-
    remove_value_from_column_except_row_(Mx0, 1, SkipR, C, E, [], Rev, ok, Flag),
    reverse(Rev, Mx).

remove_value_from_column_except_row_([], _Cur, _SkipR, _C, _E, Acc, Acc, Flag, Flag).
remove_value_from_column_except_row_([Row|Rs], Cur, SkipR, C, E, Acc, Out, _Fin, FlagOut) :-
	( Cur =:= SkipR -> % hagyjuk ezt a sort
		Row1 = Row, Flag1 = ok
	; remove_value_in_row_at_column(Row, C, E, Row1, Flag1)
	),
	( Flag1 = contradiction -> FlagOut = contradiction, Out = [Row|Rs]
	; Acc1 = [Row1|Acc], Cur1 is Cur + 1,
	  remove_value_from_column_except_row_(Rs, Cur1, SkipR, C, E, Acc1, Out, ok, FlagOut)
	).


% remove_value_in_row_at_column(+Row0, +C, +E, -Row, -Flag)
remove_value_in_row_at_column(Row0, C, E, Row, Flag) :-
        remove_value_in_row_at_column_(Row0, 1, C, E, [], Rev, ok, Flag),
        reverse(Rev, Row).

remove_value_in_row_at_column_([], _Idx, _C, _E, Acc, Acc, Flag, Flag).
remove_value_in_row_at_column_([Cell|Rest], Idx, C, E, Acc, Out, _FlagIn, FlagOut) :-
		( Idx =:= C ->
				remove_value_from_cell_domain(Cell, E, Cell1, Flag1),
				( Flag1 = contradiction -> FlagOut = contradiction, Out = [Cell|Rest] ; Acc1 = [Cell1|Acc] )
		; Acc1 = [Cell|Acc], Flag1 = ok
		),
		( Flag1 = contradiction -> true
		; Idx1 is Idx + 1,
			remove_value_in_row_at_column_(Rest, Idx1, C, E, Acc1, Out, ok, FlagOut)
		).


% remove_value_from_cell_domain(+Cell0, +E, -Cell, -Flag)
% Cell0 lehet egész vagy lista. Ha egész==E és el kellene hagyni E-t,
% az ellentmondás. Ha lista, E eltávolítása, üressé válás -> ellentmondás.
remove_value_from_cell_domain(Cell0, E, _Cell, contradiction) :- integer(Cell0), Cell0 =:= E, !.
remove_value_from_cell_domain(Cell0, _E, Cell, ok) :- integer(Cell0), !,
	Cell = Cell0.
remove_value_from_cell_domain([X], E, [], contradiction) :- X =:= E, !.
remove_value_from_cell_domain([X], E, [X], ok) :- X =\= E, !.
remove_value_from_cell_domain(List0, E, List, ok) :-
	is_list(List0),
	remove_all_occurrences(List0, E, List),
	List \= [], !.
remove_value_from_cell_domain(_List0, _E, [], contradiction).


remove_all_occurrences([], _E, []).
remove_all_occurrences([E|Xs], E, Ys) :- !, remove_all_occurrences(Xs, E, Ys).
remove_all_occurrences([X|Xs], E, [X|Ys]) :- remove_all_occurrences(Xs, E, Ys).


% [0] -> 0 a sorban
collapse_zero_singleton_in_row([], []).
collapse_zero_singleton_in_row([[0]|Xs], [0|Ys]) :- !, collapse_zero_singleton_in_row(Xs, Ys).
collapse_zero_singleton_in_row([X|Xs], [X|Ys]) :- collapse_zero_singleton_in_row(Xs, Ys).


% [0] -> 0 az oszlopban (minden sor C. eleme)
collapse_zero_singleton_in_column([], _C, []).
collapse_zero_singleton_in_column([Row|Rs], C, [Row1|Rs1]) :-
	nth1(C, Row, Cell),
	( Cell = [0] -> Cell1 = 0 ; Cell1 = Cell ),
	set_nth1(Row, C, Cell1, Row1),
	collapse_zero_singleton_in_column(Rs, C, Rs1).


% 0-k száma egy sorban/oszlopban
count_zeros_in_list(List, Count) :- count_zeros_in_list_(List, 0, Count).
count_zeros_in_list_([], Acc, Acc).
count_zeros_in_list_([0|Xs], Acc, C) :- !, Acc1 is Acc + 1, count_zeros_in_list_(Xs, Acc1, C).
count_zeros_in_list_([X|Xs], Acc, C) :-
	( is_list(X) -> count_zeros_in_list_(Xs, Acc, C)
	; count_zeros_in_list_(Xs, Acc, C)
	).


% Ha a sorban elérte a 0-k száma a Z értéket, a NEM 0 elemekből
% (listákból) elhagyjuk a 0-t. 0 értékű egészeket nem bántjuk.
remove_zero_from_row_domain_lists([], [], ok).
remove_zero_from_row_domain_lists([0|Xs], [0|Ys], Flag) :- !,
	remove_zero_from_row_domain_lists(Xs, Ys, Flag).
remove_zero_from_row_domain_lists([Cell|Xs], [Cell1|Ys], Flag) :-
	( integer(Cell) -> Cell1 = Cell, remove_zero_from_row_domain_lists(Xs, Ys, Flag)
	; remove_value_from_cell_domain(Cell, 0, Cell1, Flag1),
	  ( Flag1 = contradiction -> Flag = contradiction, Ys = Xs
	  ; remove_zero_from_row_domain_lists(Xs, Ys, Flag)
	  )
	).


% Oszlop megfelelője a fenti sorműveletnek
remove_zero_from_column_domain_lists(Mx0, C, Mx, Flag) :-
	remove_zero_from_column_domain_lists_(Mx0, C, [], RevRows, ok, Flag),
	reverse(RevRows, Mx).


remove_zero_from_column_domain_lists_([], _C, Acc, Acc, Flag, Flag).
remove_zero_from_column_domain_lists_([Row|Rs], C, Acc, Out, _FlagIn, FlagOut) :-
	remove_zero_in_row_at_column(Row, C, NewRow, Flag1),
	( Flag1 = contradiction -> FlagOut = contradiction, Out = [Row|Rs]
	; remove_zero_from_column_domain_lists_(Rs, C, [NewRow|Acc], Out, ok, FlagOut)
	).


% remove_zero_in_row_at_column(+Row0,+C,-Row,-Flag) removes 0 from list at column C if present.
remove_zero_in_row_at_column(Row0, C, Row, Flag) :-
    remove_zero_in_row_at_column_(Row0, 1, C, [], Rev, ok, Flag),
    reverse(Rev, Row).

remove_zero_in_row_at_column_([], _Idx, _C, Acc, Acc, Flag, Flag).
remove_zero_in_row_at_column_([Cell|Rest], Idx, C, Acc, Out, _FlagIn, FlagOut) :-
	( Idx =:= C ->
		( Cell = 0 -> Cell1 = 0, Flag1 = ok
		; integer(Cell) -> Cell1 = Cell, Flag1 = ok
		; remove_value_from_cell_domain(Cell, 0, Cell1, Flag1)
		),
		( Flag1 = contradiction -> FlagOut = contradiction, Out = [Cell|Rest]
		; Acc1 = [Cell1|Acc]
		)
	; Acc1 = [Cell|Acc], Flag1 = ok
	),
	( Flag1 = contradiction -> true
	; Idx1 is Idx + 1,
	  remove_zero_in_row_at_column_(Rest, Idx1, C, Acc1, Out, ok, FlagOut)
	).


% Mátrix oszlopának kiolvasása
get_column_at_index([], _C, []).
get_column_at_index([Row|Rs], C, [X|Xs]) :- nth1(C, Row, X), get_column_at_index(Rs, C, Xs).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Általános listakezelő segédek

% nth1/set_nth1 – 1-alapú indexelés beépített predikátumokra támaszkodva, de
% itt biztosítunk set_nth1-nek egy tiszta definíciót.
set_nth1([_|Xs], 1, E, [E|Xs]).
set_nth1([X|Xs], I, E, [X|Ys]) :- I > 1, I1 is I - 1, set_nth1(Xs, I1, E, Ys).


% Mátrix sor „visszahelyezés” (1-alapú beillesztés) egy olyan listába,
% amelyből az adott sor korábban ki lett véve (RestRows hossza N-1).
set_matrix_row_at_index(Rs, 1, Row, [Row|Rs]).
set_matrix_row_at_index([R0|Rs], I, Row, [R0|Rs1]) :- I > 1, I1 is I - 1, set_matrix_row_at_index(Rs, I1, Row, Rs1).


% Mátrix cellabeállítás (1-alapú): (R,C) pozícióra Value
set_cell(Mx0, R, C, Value, Mx) :-
	nth1(R, Mx0, Row, RestRows),
	set_nth1(Row, C, Value, NewRow),
	set_matrix_row_at_index(RestRows, R, NewRow, Mx).
