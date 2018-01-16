Definitions.

INT        = [0-9]+
LETTERS    = [a-zA-Z_]+
WHITESPACE = [\s\t\n\r]
TYPES      = uint|int|address|bool|fixed|uint|ufixed|bytes|function|string

Rules.

{TYPES}       : {token, {typename,   TokenLine, TokenChars}}.
{INT}         : {token, {digits,     TokenLine, TokenChars}}.
{LETTERS}     : {token, {letters,    TokenLine, TokenChars}}.
\[            : {token, {'[',        TokenLine}}.
\]            : {token, {']',        TokenLine}}.
\(            : {token, {'(',        TokenLine}}.
\)            : {token, {')',        TokenLine}}.
,             : {token, {',',        TokenLine}}.
->            : {token, {'->',       TokenLine}}.
{WHITESPACE}+ : skip_token.

Erlang code.
