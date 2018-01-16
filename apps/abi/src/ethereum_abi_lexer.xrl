Definitions.

INT        = [0-9]+
LETTERS    = [a-z_]+
WHITESPACE = [\s\t\n\r]
TYPES      = uint|int|address|bool|fixed|uint|ufixed|bytes|function|string

Rules.

{TYPES}       : {token, {atom,       TokenLine, list_to_atom(TokenChars)}}.
{INT}         : {token, {int,        TokenLine, list_to_integer(TokenChars)}}.
{LETTERS}     : {token, {binary,     TokenLine, list_to_binary(TokenChars)}}.
\[            : {token, {'[',        TokenLine}}.
\]            : {token, {']',        TokenLine}}.
\(            : {token, {'(',        TokenLine}}.
\)            : {token, {')',        TokenLine}}.
,             : {token, {',',        TokenLine}}.
->            : {token, {'->',       TokenLine}}.
{WHITESPACE}+ : skip_token.

Erlang code.
