module RoomTest exposing (..)

import Expect exposing (Expectation)
import Test exposing (..)

import Url

import BoardGameFramework exposing (..)


roomTest : Test
roomTest =
  describe "room"
  [ test "good alpha" <|
    \_ ->
      Expect.ok <| room "aBCDeFG"

  , test "good digits" <|
    \_ ->
      Expect.ok <| room "01234567"

  , test "good with dashes and dots" <|
    \_ ->
      Expect.ok <| room "0-1-23.a"

  , test "good with slashes" <|
    \_ ->
      Expect.ok <| room "oxox/part-many-ton"

  , test "too short" <|
    \_ ->
      errContains "too short" <| room "0123"

  , test "Max length" <|
    \_ ->
      Expect.ok <| room "123456789012345678901234567890"

  , test "Too long" <|
    \_ ->
      errContains "too long" <| room "1234567890123456789012345678901"

  , test "bad characters 1" <|
    \_ ->
      errContains "Bad characters" <| room "01 234 abc"

  , test "bad characters 2" <|
    \_ ->
      errContains "Bad characters" <| room "01-234#abc"

  ]


errContains : String -> Result String a -> Expect.Expectation
errContains subs res =
  case res of
    Ok _ ->
      Expect.fail ("Got Ok, but expected error containing '" ++ subs ++ "'")

    Err msg ->
      if String.contains subs msg then
        Expect.pass
      else
        Expect.fail ("'" ++ msg ++ "' did not contain '" ++ subs ++ "'")
