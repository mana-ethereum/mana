Terminals '(' ')' '[' ']' ',' '->' typename letters digits 'expecting selector' 'expecting type'.
Nonterminals dispatch selector nontrivial_selector comma_delimited_types type_with_subscripts array_subscripts tuple array_subscript identifier  identifier_parts identifier_part type typespec.
Rootsymbol dispatch.

dispatch -> 'expecting type' type_with_subscripts : {type, '$2'}.
dispatch -> 'expecting selector' selector : {selector, '$2'}.
dispatch -> tuple : {selector, #{function => nil, types => ['$1'], returns => nil}}.
dispatch -> nontrivial_selector : {selector, '$1'}.

selector -> typespec : #{function => nil, types => '$1', returns => nil}.
selector -> nontrivial_selector : '$1'.

nontrivial_selector -> typespec '->' type : #{function => nil, types => '$1', returns => '$3'}.
nontrivial_selector -> identifier typespec : #{function => '$1', types => '$2', returns => nil}.
nontrivial_selector -> identifier typespec '->' type : #{function => '$1', types => '$2', returns => '$4'}.

typespec -> '(' ')' : [].
typespec -> '(' comma_delimited_types ')' : '$2'.

tuple -> '(' ')' : {tuple, []}.
tuple -> '(' comma_delimited_types ')' : {tuple, '$2'}.

comma_delimited_types -> type_with_subscripts : ['$1'].
comma_delimited_types -> type_with_subscripts ',' comma_delimited_types : ['$1' | '$3'].

identifier -> identifier_parts : iolist_to_binary('$1').

identifier_parts -> identifier_part : ['$1'].
identifier_parts -> identifier_part identifier_parts : ['$1' | '$2'].

identifier_part -> typename : v('$1').
identifier_part -> letters : v('$1').
identifier_part -> digits : v('$1').

type_with_subscripts -> type : '$1'.
type_with_subscripts -> type array_subscripts : with_subscripts('$1', '$2').

array_subscripts -> array_subscript : ['$1'].
array_subscripts -> array_subscript array_subscripts : ['$1' | '$2'].

array_subscript -> '[' ']' : variable.
array_subscript -> '[' digits ']' : list_to_integer(v('$2')).

type -> typename :
  plain_type(list_to_atom(v('$1'))).
type -> typename digits :
  juxt_type(list_to_atom(v('$1')), list_to_integer(v('$2'))).
type -> typename digits letters digits :
  double_juxt_type(list_to_atom(v('$1')), v('$3'), list_to_integer(v('$2')), list_to_integer(v('$4'))).
type -> tuple : '$1'.


Erlang code.

v({_Token, _Line, Value}) -> Value.

plain_type(address) -> address;
plain_type(bool) -> bool;
plain_type(function) -> function;
plain_type(string) -> string;
plain_type(bytes) -> bytes;
plain_type(int) -> juxt_type(int, 256);
plain_type(uint) -> juxt_type(uint, 256);
plain_type(fixed) -> double_juxt_type(fixed, "x", 128, 19);
plain_type(ufixed) -> double_juxt_type(ufixed, "x", 128, 19).

with_subscripts(Type, []) -> Type;
with_subscripts(Type, [H | T]) -> with_subscripts(with_subscript(Type, H), T).

with_subscript(Type, variable) -> {array, Type};
with_subscript(Type, N) when is_integer(N), N >= 0 -> {array, Type, N}.

juxt_type(int, M) when M > 0, M =< 256, (M rem 8) =:= 0 -> {int, M};
juxt_type(uint, M) when M > 0, M =< 256, (M rem 8) =:= 0 -> {uint, M};
juxt_type(bytes, M) when M > 0, M =< 32 -> {bytes, M}.

double_juxt_type(fixed, 'x', M, N) when M >= 0, M =< 256, (M rem 8) =:= 0, N > 0, N =< 80 -> {fixed, M, N};
double_juxt_type(ufixed, 'x', M, N) when M >= 0, M =< 256, (M rem 8) =:= 0, N > 0, N =< 80 -> {ufixed, M, N}.
