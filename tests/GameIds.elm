module GameIds exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)

import Url

import BoardGameFramework exposing (..)


isGoodGameIdTest : Test
isGoodGameIdTest =
  describe "isGoodGameId"
  [ test "good alpha" <|
    \_ ->
      Expect.equal True <| isGoodGameId "aBCDeFG"

  , test "good digits" <|
    \_ ->
      Expect.equal True <| isGoodGameId "01234567"

  , test "good with dashes and dots" <|
    \_ ->
      Expect.equal True <| isGoodGameId "0-1-23.a"

  , test "too short" <|
    \_ ->
      Expect.equal False <| isGoodGameId "0123"

  , test "bad characters 1" <|
    \_ ->
      Expect.equal False <| isGoodGameId "01 234 abc"

  , test "bad characters 2" <|
    \_ ->
      Expect.equal False <| isGoodGameId "01-234#abc"

  ]

isGoodGameIdTestMaybe : Test
isGoodGameIdTestMaybe =
  describe "isGoodGameIdMaybe"
  [ test "good alpha" <|
    \_ ->
      Expect.equal True <| isGoodGameIdMaybe (Just "aBCDeFG")

  , test "good digits" <|
    \_ ->
      Expect.equal True <| isGoodGameIdMaybe (Just "01234567")

  , test "good with dashes and dots" <|
    \_ ->
      Expect.equal True <| isGoodGameIdMaybe (Just "0-1-23.a")

  , test "too short" <|
    \_ ->
      Expect.equal False <| isGoodGameIdMaybe (Just "0123")

  , test "bad characters 1" <|
    \_ ->
      Expect.equal False <| isGoodGameIdMaybe (Just "01 234 abc")

  , test "bad characters 2" <|
    \_ ->
      Expect.equal False <| isGoodGameIdMaybe (Just "01-234#abc")

  , test "Nothing" <|
    \_ ->
      Expect.equal False <| isGoodGameIdMaybe Nothing

  ]
