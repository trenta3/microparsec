# TODO: we need notation for doing stuff like the following:
#
# xml = do{ name <- openTag
#         ; content <- many xml
#         ; endTagname
#         ; pure (Node name content)
#         } <|> xmlText

import strutils
export toUpperAscii, toHex

import sugar
export `=>`, `->`

import streams
export newStringStream

import options
export Option, some, none

import results
export ok, err, `==`

func identity*[T](x: T): T =
  ## Identity function.
  x

func compose*[R,S,T](f: R -> S, g: S -> T): R -> T =
  ## Compose two functions.
  (x: R) => g(f(x))

type
  ParseError = tuple
    ## A `ParseError` contains both what was expected by the `Parser`, what
    ## was actually found by it (the unexpected `string`) and the `Stream`
    ## position.
    position: int
    unexpected: string
    expected: seq[string]

  ParseResult*[T] = Result[T,ParseError]
    ## A `ParseResult` of type `T` contains either a parsed object of that
    ## type or a `ParseError`.

  Parser[T] = Stream -> ParseResult[T]
    ## A `Parser` for a type `T` is a function that receives a `Stream` and
    ## gives back a `ParseResult` of the same type.

func `<?>`*[T](parser: Parser[T], expected: string): Parser[T] {.inline.} =
  return func(s: Stream): ParseResult[T] =
    let res = parser(s)
    if res.isOk:
      res
    else:
      ParseResult[T].err(
        (res.error.position, res.error.unexpected, @[expected])
      )

# TODO: does applying an empty error string does any good, since it never
# fails?
func pure*[T](x: T): Parser[T] {.inline.} =
  ## Create a `Parser` that always return `x`, but consumes nothing. As such,
  ## it never fails.
  ##
  ## This is required in both applicative and monadic parsers.
  return (func(_: Stream): ParseResult[T] =
    ParseResult[T].ok(x)
  ) <?> ""

func `>>=`*[S,T](parser0: Parser[S], f: S -> Parser[T]): Parser[T] {.inline.} =
  ## Pass the result of a `Parser` to a function that returns another `Parser`.
  ##
  ## This is required in monadic parsing.
  return proc(s: Stream): ParseResult[T] =
    let position = s.getPosition
    let result0 = parser0(s)
    if result0.isOk:
      let result1 = f(result0.get)(s)
      if result1.isErr:
        s.setPosition(position)
      result1
    else:
      ParseResult[T].err(result0.error)

# `satisfy` could be defined in terms of anyChar, but I find the following
# implementation simpler.
# TODO: we're going with the implementation in the first Parsec paper and not
# inserting any error message here. This makes some sense, as no message would
# be really useful.
func satisfy(predicate: char -> bool): Parser[char] {.inline.} =
  ## Create a `Parser` that consumes a single character if it satisfies a
  ## given predicate.
  ##
  ## This is used to build more complex `Parser`s.
  return proc(s: Stream): ParseResult[char] =
    if s.atEnd:
      ParseResult[char].err(
        (s.getPosition, "end of input", @[])
      )
    else:
      let c = s.readChar
      if predicate(c):
        ParseResult[char].ok(c)
      else:
        s.setPosition(s.getPosition - 1)
        ParseResult[char].err(
          (s.getPosition, $c, @[])
        )

# TODO: <|> has different semantics from Parsec's <|>. This might be
# either good or bad. But the current implementation is definitely useful.
func `<|>`*[T](parser0, parser1: Parser[T]): Parser[T] {.inline.} =
  ## Create a `Parser` as a choice combination between two other `Parser`s.
  return func(s: Stream): ParseResult[T] =
    let result0 = parser0(s)
    if result0.isOk:
      result0
    else:
      let result1 = parser1(s)
      if result1.isOk:
        result1
      else:
        assert result0.error.unexpected == result1.error.unexpected
        assert result0.error.expected != result1.error.expected  # ?
        assert result0.error.position == result1.error.position
        ParseResult[T].err(
          (result0.error.position, result0.error.unexpected, result0.error.expected & result1.error.expected)
        )

# TODO: by inverting the order of the parameters, we can use Nim do-blocks
# for defining mapping functions.
func fmap*[S,T](f: S -> T, parser: Parser[S]): Parser[T] {.inline.} =
  ## Apply a function to the result of a `Parser`.
  ##
  ## This is required in "functor" parsing.
  return proc(s: Stream): ParseResult[T] =
    let result0 = parser(s)
    if result0.isOk:
      ParseResult[T].ok(f(result0.get))
    else:
      ParseResult[T].err(result0.error)

# TODO: the parameter order might be swapped here. Take a look at arrow-style
# combinators.
func `<*>`*[S,T](parser0: Parser[S -> T], parser1: Parser[S]): Parser[T] {.inline.} =
  ## Apply the function parsed by a `Parser` to the result of another
  ## `Parser`.
  ##
  ## This is required in applicative parsing.
  return func(s: Stream): ParseResult[T] =
    let result0 = parser0(s)
    if result0.isOk:
      fmap(result0.get, parser1)(s)
    else:
      ParseResult[T].err(result0.error)

# TODO: maybe we should wrap characters in error messages in single quotes.
func ch*(c: char): Parser[char] {.inline.} =
  ## Create a `Parser` that consumes a specific single character if present.
  ##
  ## This function is called `char` in Parsec, but this conflicts with the
  ## type `char` in Nim.
  satisfy((d: char) => d == c) <?> $c

let letter*: Parser[char] =
  satisfy(isAlphaAscii) <?> "letter"
  ## A `Parser` that consumes any letter.

let digit*: Parser[char] =
  satisfy(isDigit) <?> "digit"
  ## A `Parser` that consumes any digit.

func `>>`*[S,T](parser0: Parser[S], parser1: Parser[T]): Parser[T] {.inline.} =
  parser0 >>= ((_: S) => parser1)

# TODO: this currently always returns an empty string if successful!
func str*(s: string): Parser[string] {.inline.} =
  ## Build a `Parser` that consumes a given string if present.
  ##
  ## This function is called `string` in Parsec, but this conflicts with the
  ## type `string` in Nim.
  (if s == "":
    pure(s)
  else:
    ch(s[0]) >> str(s[1..^1])
  ) <?> s

# TODO: we might specialize this for char and string in the future, as
# Haskell considers strings as sequences of characters. But this might not be
# necessary (except if for performance, I'm not sure), because the current
# implementation works out of the box already! (Which is amazing...)
# TODO: check error messages from Parsec and duplicate them here.
func many1*[T](parser: Parser[T]): Parser[seq[T]] {.inline.} =
  ## Build a `Parser` that applies another `Parser` one or more times.
  parser >>= proc(x: T): Parser[seq[T]] =
    (many1(parser) <|> pure(newSeq[T]())) >>= proc(xs: seq[T]): Parser[seq[T]] =
      pure(x & xs)

# TODO: this is apparently not part of the standard
let identifier*: Parser[seq[char]] =
  many1(letter <|> digit <|> ch('_'))
  ## A `Parser` that consumes a common identifier, made of letters, digits
  ## and underscores (`'_'`).

# TODO: attempt has different semantics from Parsec's try. This might be
# either good or bad. But the current implementation is definitely useful.
func attempt*[T](parser: Parser[T]): Parser[Option[T]] {.inline.} =
  ## Create a `Parser` that behaves exactly like the given one, but never
  ## fails. The failure state is modeled as an `Option` of type `T`.
  ##
  ## This function is called `try` in Parsec, but this conflicts with the
  ## `try` keyword in Nim.
  return func(s: Stream): ParseResult[Option[T]] =
    let res = parser(s)
    if res.isOk:
      ParseResult[Option[T]].ok(some(res.get))
    else:
      ParseResult[Option[T]].ok(none(T))


# Also known as `item`.
# TODO: an old definition explicitly checked for end of input. This is
# now done in satisfy. Check Parsec's current implementation.
let anyChar*: Parser[char] =
  satisfy((_: char) => true) <?> "any character"

# TODO: implement `many`, `between` and the probably others suggested in
# <http://theorangeduck.com/page/you-could-have-invented-parser-combinators>.

func `<$`*[S,T](x: T, parser: Parser[S]): Parser[T] =
  fmap((_: S) => x, parser)

func `*>`*[S,T](parser0: Parser[S], parser1: Parser[T]): Parser[T] =
  return func(s: Stream): ParseResult[T] =
    discard parser0(s)
    parser1(s)

func `<*`*[T,S](parser0: Parser[T], parser1: Parser[S]): Parser[T] =
  return func(s: Stream): ParseResult[T] =
    result = parser0(s)
    discard parser1(s)

func parse*[T](parser: Parser[T], s: Stream): ParseResult[T] =
  parser s

func parse*[T](parser: Parser[T], s: string): ParseResult[T] =
  parser newStringStream(s)

# TODO: define eof in function of ch or something else
# TODO: this function returns a null character if it succeeds. Check if
# that's what Parsec does or not (it might return an empty string instead, do
# what it does there).
proc eof*(s: Stream): ParseResult[char] =
  if s.atEnd:
    ParseResult[char].ok('\x00')
  else:
    ParseResult[char].err(
      (s.getPosition, $s.peekChar, @["end of input"])
    )
