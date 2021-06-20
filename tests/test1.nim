# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import streams
import strutils

import petametre
import petametre/primitives
import petametre/types

suite "basic character parsers":
  test "anyChar":
    let p = anyChar
    check p.debugParse("foo") == $('f', 1, 0, 1)
    check p.debugParse("oo") == $('o', 1, 0, 1)
    check p.debugParse("f") == $('f', 1, 0, 1)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["any character"]), 0, 0, 0)

  test "letter":
    let p = letter
    check p.debugParse("ello") == $('e', 1, 0, 1)
    check p.debugParse("1hello") == $((unexpected: "1", expected: @["letter"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["letter"]), 0, 0, 0)

  test "digit":
    let p = digit
    check p.debugParse("1hello") == $('1', 1, 0, 1)
    check p.debugParse("ello") == $((unexpected: "e", expected: @["digit"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["digit"]), 0, 0, 0)

  # TODO: this always returns an empty string. This is in agreement with the
  # first Parsec paper, but it would be better to return the given string.
  test "str":
    let p = str("hello")
    # check p.debugParse("hello") == $("hello", 5, 0, 5)
    # check p.debugParse("hello world") == $("hello", 5, 0, 5)
    check p.debugParse("1hello") == $((unexpected: "1", expected: @["hello"]), 0, 0, 0)
    check p.debugParse("ello") == $((unexpected: "e", expected: @["hello"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["hello"]), 0, 0, 0)

  # TODO: insert more examples where the results are other than
  # string/characters.
  test "many":
    let p = many(ch('h'))
    # Both `seq[char]` and `string` work! Very useful! But structural matching
    # does not work (such as comparing tuples and one of the fields are
    # seq[char]/string! We need to specialize some functions to return string
    # instead of seq[char], and get rid of all "newSeq[char]" everywhere.
    check p.debugParse("hello") == $(@['h'], 1, 0, 1)
    check p.debugParse("hello") == $(@['h'], 1, 0, 1)
    check p.debugParse("hhello") == $(@['h', 'h'], 2, 0, 2)
    check p.debugParse("hhhello") == $(@['h', 'h', 'h'], 3, 0, 3)
    check p.debugParse("ello") == $(newSeq[char](), 0, 0, 0)
    check p.debugParse("") == $(newSeq[char](), 0, 0, 0)

  # TODO: insert more examples where the results are other than
  # string/characters.
  test "many1":
    let p = many1(ch('h'))
    # Both `seq[char]` and `string` work! Very useful! But structural matching
    # does not work (such as comparing tuples and one of the fields are
    # seq[char]/string! We need to specialize some functions to return string
    # instead of seq[char], and get rid of all "newSeq[char]" everywhere.
    check p.debugParse("hello") == $(@['h'], 1, 0, 1)
    check p.debugParse("hello") == $(@['h'], 1, 0, 1)
    check p.debugParse("hhello") == $(@['h', 'h'], 2, 0, 2)
    check p.debugParse("hhhello") == $(@['h', 'h', 'h'], 3, 0, 3)
    check p.debugParse("ello") == $((unexpected: "e", expected: @["h"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["h"]), 0, 0, 0)

  # TODO: identifier is apparently not part of the standard Parsec and may be deleted in the future.
  test "identifier":
    let p = identifier
    # Both `seq[char]` and `string` work! Very useful! But structural matching
    # does not work (such as comparing tuples and one of the fields are
    # seq[char]/string! We need to specialize some functions to return string
    # instead of seq[char], and get rid of all "newSeq[char]" everywhere.
    check p.debugParse("hello") == $(@['h', 'e', 'l', 'l', 'o'], 5, 0, 5)
    check p.debugParse("hello") == $(@['h', 'e', 'l', 'l', 'o'], 5, 0, 5)
    check p.debugParse("hello world") == $(@['h', 'e', 'l', 'l', 'o'], 5, 0, 5)
    check p.debugParse("123hello_ world") == $(@['1', '2', '3', 'h', 'e', 'l', 'l', 'o', '_'], 9, 0, 9)
    check p.debugParse("*123hello_ world") == $((unexpected: "*", expected: @["letter", "digit", "_"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["letter", "digit", "_"]), 0, 0, 0)

  test "attempt":
    let p = attempt(ch('h'))
    check p.debugParse("hello") == $(some('h'), 1, 0, 1)
    check p.debugParse("ello") == $(none(char), 0, 0, 0)
    check p.debugParse("") == $(none(char), 0, 0, 0)

    let q = attempt(ch('h') <|> ch('e'))
    check q.debugParse("hello") == $(some('h'), 1, 0, 1)
    check q.debugParse("ello") == $(some('e'), 1, 0, 1)
    check q.debugParse("") == $(none(char), 0, 0, 0)

  test "pure":
    let p = pure('x')
    check p.debugParse("hello") == $('x', 0, 0, 0)
    check p.debugParse("ello") == $('x', 0, 0, 0)
    check p.debugParse("") == $('x', 0, 0, 0)

  test "eof":
    let p = eof
    # Can't compare `ok`s due to a bug, see <https://github.com/arnetheduck/nim-result/issues/16>.
    check p.debugParse("") == $(0, 0, 0)
    check p.debugParse("hello") == $((unexpected: "h", expected: @["end of input"]), 0, 0, 0)

  test "ch":
    let p = ch('h')
    check p.debugParse("hello") == $('h', 1, 0, 1)
    check p.debugParse("ello") == $((unexpected: "e", expected: @["h"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["h"]), 0, 0, 0)

  test "between":
    # TODO: default errors for this combinator are not good enough.
    # Observe that the error message bypasses the possibility of more digits.
    # Think about the error messages as a set of tokens that would be required
    # to make the input valid.
    # TODO: the seq[char] thing is a real pain!
    let p = between(ch('{'), many(digit), ch('}'))
    check p.debugParse("{12}hello") == $(@['1', '2'], 4, 0, 4)
    check p.debugParse("{}hello") == $(newSeq[char](), 2, 0, 2)
    check p.debugParse("hello") == $((unexpected: "h", expected: @["{"]), 0, 0, 0)
    check p.debugParse("{hello") == $((unexpected: "h", expected: @["}"]), 1, 0, 1)
    check p.debugParse("{1hello") == $((unexpected: "h", expected: @["}"]), 2, 0, 2)
    check p.debugParse("{12hello") == $((unexpected: "h", expected: @["}"]), 3, 0, 3)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["{"]), 0, 0, 0)

    # Observe that the error message bypasses the possibility of more digits.
    # Think about the error messages as a set of tokens that would be required
    # to make the input valid.
    let q = between(ch('{'), many1(digit), ch('}'))
    check q.debugParse("{12}hello") == $(@['1', '2'], 4, 0, 4)
    check q.debugParse("{}hello") == $((unexpected: "}", expected: @["digit"]), 1, 0, 1)
    check q.debugParse("hello") == $((unexpected: "h", expected: @["{"]), 0, 0, 0)
    check q.debugParse("{hello") == $((unexpected: "h", expected: @["digit"]), 1, 0, 1)
    check q.debugParse("{1hello") == $((unexpected: "h", expected: @["}"]), 2, 0, 2)
    check q.debugParse("{12hello") == $((unexpected: "h", expected: @["}"]), 3, 0, 3)
    check q.debugParse("") == $((unexpected: "end of input", expected: @["{"]), 0, 0, 0)

  test "sepBy":
    let p = sepBy(many1(digit), ch(','))
    check p.debugParse("1,2,3,4") == $(@[@['1'], @['2'], @['3'], @['4']], 7, 0, 7)
    check p.debugParse("11,22") == $(@[@['1', '1'], @['2', '2']], 5, 0, 5)
    # Observe how forgiving is that. Also observe how greedy that is.
    check p.debugParse("11 ,22") == $(@[@['1', '1']], 2, 0, 2)
    check p.debugParse("11, 22") == $(@[@['1', '1']], 3, 0, 3)
    check p.debugParse("11,,22") == $(@[@['1', '1']], 3, 0, 3)
    check p.debugParse(",") == $(newSeq[seq[char]](), 0, 0, 0)
    check p.debugParse("") == $(newSeq[seq[char]](), 0, 0, 0)
    # TODO: seq[seq[char]] is impossible to scale well. Although it is OK to
    # have seq[char] in place of string in many situations, higher order
    # containers start to scale bad. Solution: ensure we get
    #
    #         `seq[T]` for `T`,
    #     but `string` for `char`.
    #
    # check p.debugParse("1,2,3,4") == $(@["1", "2", "3", "4"], 7, 0, 7)
    # check p.debugParse("") == $((unexpected: "end of input", expected: @["{"]), 0, 0, 0)


    # If you think sepBy should not be eager, think again: it should. See
    # <https://github.com/mrkkrp/megaparsec/issues/401#issue-572499736>,
    # whose example is reproduced below.
    func foo[R,S,T](p: Parser[R], sep: Parser[S], q: Parser[T]): Parser[void] =
      sepBy(p, sep) >> optional(sep >> q)
    check foo(str("a"), str(" "), str("b")).debugParse("a a b") == $(4, 0, 4)

  test "sepBy1":
    let p = sepBy1(many1(digit), ch(','))
    check p.debugParse("1,2,3,4") == $(@[@['1'], @['2'], @['3'], @['4']], 7, 0, 7)
    check p.debugParse("11,22") == $(@[@['1', '1'], @['2', '2']], 5, 0, 5)
    # Observe how forgiving is that. Also observe how greedy that is.
    check p.debugParse("11 ,22") == $(@[@['1', '1']], 2, 0, 2)
    check p.debugParse("11, 22") == $(@[@['1', '1']], 3, 0, 3)
    check p.debugParse("11,,22") == $(@[@['1', '1']], 3, 0, 3)
    check p.debugParse(",") == $((unexpected: ",", expected: @["digit"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["digit"]), 0, 0, 0)
    # TODO: seq[seq[char]] is impossible to scale well. Although it is OK to
    # have seq[char] in place of string in many situations, higher order
    # containers start to scale bad. Solution: ensure we get
    #
    #         `seq[T]` for `T`,
    #     but `string` for `char`.
    #
    # check p.debugParse("1,2,3,4") == $(@["1", "2", "3", "4"], 7, 0, 7)
    # check p.debugParse("") == $((unexpected: "end of input", expected: @["{"]), 0, 0, 0)

  test "optional":
    let p = optional(ch('h'))
    check p.debugParse("ello") == $(0, 0, 0)
    check p.debugParse("hello") == $(1, 0, 1)
    check p.debugParse("hhello") == $(1, 0, 1)
    check p.debugParse("") == $(0, 0, 0)

suite "parsing utilities":
  test "parse":
    let p = anyChar
    check p.debugParse("hello") == $('h', 1, 0, 1)
    check p.debugParse(newStringStream("hello")) == p.debugParse("hello")

    check p.parse("hello") == ParseResult[char].ok 'h'
    check p.parse(newStringStream("hello")) == p.parse("hello")

  test "position state":
    let p = anyChar >> anyChar >> anyChar >> anyChar >> anyChar
    check p.debugParse("foo") == $((unexpected: "end of input", expected: @["any character"]), 3, 0, 3)
    check p.debugParse("fooo") == $((unexpected: "end of input", expected: @["any character"]), 4, 0, 4)
    check p.debugParse("foooo") == $('o', 5, 0, 5)

    check p.debugParse("\nfoo") == $((unexpected: "end of input", expected: @["any character"]), 4, 1, 3)
    check p.debugParse("f\noo") == $((unexpected: "end of input", expected: @["any character"]), 4, 1, 2)
    check p.debugParse("fo\no") == $((unexpected: "end of input", expected: @["any character"]), 4, 1, 1)
    check p.debugParse("foo\n") == $((unexpected: "end of input", expected: @["any character"]), 4, 0, 4)

    check p.debugParse("\n\nfoo") == $('o', 5, 2, 3)
    check p.debugParse("\nf\noo") == $('o', 5, 2, 2)
    check p.debugParse("\nfo\no") == $('o', 5, 2, 1)
    check p.debugParse("\nfoo\n") == $('\n', 5, 1, 4)

    check p.debugParse("\nfooo") == $('o', 5, 1, 4)
    check p.debugParse("f\nooo") == $('o', 5, 1, 3)
    check p.debugParse("fo\noo") == $('o', 5, 1, 2)
    check p.debugParse("foo\no") == $('o', 5, 1, 1)
    check p.debugParse("fooo\n") == $('\n', 5, 0, 5)  # Newline belongs to previous line

    check p.debugParse("\n\nfooo") == $('o', 5, 2, 3)
    check p.debugParse("\nf\nooo") == $('o', 5, 2, 2)
    check p.debugParse("\nfo\noo") == $('o', 5, 2, 1)
    check p.debugParse("\nfoo\no") == $('\n', 5, 1, 4)
    check p.debugParse("\nfooo\n") == $('o', 5, 1, 4)

    check p.debugParse("\nfo\noo") == $('o', 5, 2, 1)
    check p.debugParse("f\no\noo") == $('o', 5, 2, 1)
    check p.debugParse("fo\n\noo") == $('o', 5, 2, 1)
    check p.debugParse("foo\n\no") == $('\n', 5, 1, 0)
    check p.debugParse("foo\no\n") == $('o', 5, 1, 1)

    check p.debugParse("") == $((unexpected: "end of input", expected: @["any character"]), 0, 0, 0)

  test "error messages":
    let p = anyChar >> anyChar >> anyChar >> anyChar >> anyChar
    check $p.parse("f\noo") == """1:2:(4):
  |
1 | oo
  |   ^
unexpected end of input
expecting any character"""

suite "parser algebra":
  test "functors":
    # TODO: I might want to change the parameter order in the future. See
    # what is most common in the Nim world.
    let p = anyChar
    let q = fmap((c: char) => toUpperAscii(c), p)
    check q.debugParse("foo") == $('F', 1, 0, 1)
    check q.debugParse("oo") == $('O', 1, 0, 1)
    check q.debugParse("f") == $('F', 1, 0, 1)
    check q.debugParse("") == $((unexpected: "end of input", expected: @["any character"]), 0, 0, 0)

    # First functor law
    check fmap(identity[char], p).debugParse("foo") == p.debugParse("foo")

    # Second functor law
    let f = (c: char) => toUpperAscii(c)
    let g = (c: char) => toHex($c)
    check fmap(compose(f, g), p).debugParse("foo") == fmap(g, fmap(f, p)).debugParse("foo")

  test "applicatives":
    let p = anyChar
    let f: char -> char = toUpperAscii
    let q = pure(f) <*> p
    check q.debugParse("foo") == $('F', 1, 0, 1)
    check q.debugParse("oo") == $('O', 1, 0, 1)
    check q.debugParse("f") == $('F', 1, 0, 1)
    check q.debugParse("") == $((unexpected: "end of input", expected: @["any character"]), 0, 0, 0)

    # Poor man's currying and a lot of help to the compiler
    # TODO: hey, something like true currying would make things like that much
    # nicer!
    # TODO: or we could use lift and varargs for greater good! Choose what is
    # simpler and nimbler!
    let selector: char -> (char -> (char -> (char, char))) = func(x: char): auto =
      return func(y: char): auto =
        return func(z: char): auto =
          (x, z)
    let dropMiddle = pure(selector) <*> anyChar <*> anyChar <*> anyChar
    check dropMiddle.debugParse("pumpkin") == $(('p', 'm'), 3, 0, 3)

  test "monads":
    let p = anyChar
    let q = p >>= ((c: char) => pure(toUpperAscii(c)))
    check q.debugParse("foo") == $('F', 1, 0, 1)
    check q.debugParse("oo") == $('O', 1, 0, 1)
    check q.debugParse("f") == $('F', 1, 0, 1)
    check q.debugParse("") == $((unexpected: "end of input", expected: @["any character"]), 0, 0, 0)

    # TODO: hey, something like Haskell's do-notation would make things like
    # that much nicer!
    let dropMiddle = anyChar >>= proc(x: char): auto =
      anyChar >>
        anyChar >>= func(z: char): auto =
          pure (x, z)
    check dropMiddle.debugParse("pumpkin") == $(('p', 'm'), 3, 0, 3)

suite "parser combinators":
  test "<|>":
    let p = ch('h') <|> ch('e')
    check p.debugParse("hello") == $('h', 1, 0, 1)
    check p.debugParse("ehllo") == $('e', 1, 0, 1)
    check p.debugParse("ello") == $('e', 1, 0, 1)
    check p.debugParse("hllo") == $('h', 1, 0, 1)
    check p.debugParse("llo") == $((unexpected: "l", expected: @["h", "e"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["h", "e"]), 0, 0, 0)

  test ">>":
    # TODO: default errors for this combinator are not good enough.
    let p = ch('h') >> ch('e')
    check p.debugParse("hello") == $('e', 2, 0, 2)
    check p.debugParse("ello") == $((unexpected: "e", expected: @["h"]), 0, 0, 0)
    check p.debugParse("hllo") == $((unexpected: "l", expected: @["e"]), 1, 0, 1)
    check p.debugParse("llo") == $((unexpected: "l", expected: @["h"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["h"]), 0, 0, 0)

  test "*>":
    # TODO: default errors for this combinator are not good enough.
    let p = (ch('h') >> ch('e')) *> ch('l') >> ch('l')
    check p.debugParse("hello") == $('l', 4, 0, 4)
    check p.debugParse("llo") == $('l', 2, 0, 2)
    check p.debugParse("heklo") == $((unexpected: "k", expected: @["l"]), 2, 0, 2)
    # check p.debugParse("ello") == $((unexpected: "e", expected: @["h", "l"]), 0, 0, 0)
    # check p.debugParse("hllo") == $((unexpected: "l", expected: @["e"]), 1, 0, 1)
    # check p.debugParse("") == $((unexpected: "end of input", expected: @["h", "l"]), 0, 0, 0)

  test "<*":
    let p = ch('a') <* ch('-')
    check p.debugParse("a-") == $('a', 2, 0, 2)
    check p.debugParse("aa-") == $('a', 1, 0, 1)
    check p.debugParse("b-") == $((unexpected: "b", expected: @["a"]), 0, 0, 0)
    check p.debugParse("-") == $((unexpected: "-", expected: @["a"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["a"]), 0, 0, 0)

  test "<$":
    # TODO: default errors for this combinator are not good enough.
    let p = true <$ (ch('h') >> ch('e'))
    check p.debugParse("hello") == $(true, 2, 0, 2)
    check p.debugParse("ello") == $((unexpected: "e", expected: @["h"]), 0, 0, 0)
    check p.debugParse("hllo") == $((unexpected: "l", expected: @["e"]), 1, 0, 1)
    check p.debugParse("llo") == $((unexpected: "l", expected: @["h"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["h"]), 0, 0, 0)

suite "custom error messages":
  test "<?>":
    let p = "if" <$ (ch('i') >> ch('f')) <?> "if statement"
    check p.debugParse("if 1 > 0") == $("if", 2, 0, 2)
    check p.debugParse("f 1 > 0") == $((unexpected: "f", expected: @["if statement"]), 0, 0, 0)
    check p.debugParse("") == $((unexpected: "end of input", expected: @["if statement"]), 0, 0, 0)
