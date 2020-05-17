module Parsing exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)

import Url

import BoardGameFramework exposing (..)


isGoodGameIDTest : Test
isGoodGameIDTest =
  describe "isGoodGameID"
  [ test "good alpha" <|
    \_ ->
      Expect.equal True <| isGoodGameID "aBCDeFG"

  , test "good digits" <|
    \_ ->
      Expect.equal True <| isGoodGameID "01234567"

  , test "good with dashes and dots" <|
    \_ ->
      Expect.equal True <| isGoodGameID "0-1-23.a"

  , test "too short" <|
    \_ ->
      Expect.equal False <| isGoodGameID "0123"

  , test "bad characters 1" <|
    \_ ->
      Expect.equal False <| isGoodGameID "01 234 abc"

  , test "bad characters 2" <|
    \_ ->
      Expect.equal False <| isGoodGameID "01-234#abc"

  ]

isGoodGameIDTestMaybe : Test
isGoodGameIDTestMaybe =
  describe "isGoodGameIDMaybe"
  [ test "good alpha" <|
    \_ ->
      Expect.equal True <| isGoodGameIDMaybe (Just "aBCDeFG")

  , test "good digits" <|
    \_ ->
      Expect.equal True <| isGoodGameIDMaybe (Just "01234567")

  , test "good with dashes and dots" <|
    \_ ->
      Expect.equal True <| isGoodGameIDMaybe (Just "0-1-23.a")

  , test "too short" <|
    \_ ->
      Expect.equal False <| isGoodGameIDMaybe (Just "0123")

  , test "bad characters 1" <|
    \_ ->
      Expect.equal False <| isGoodGameIDMaybe (Just "01 234 abc")

  , test "bad characters 2" <|
    \_ ->
      Expect.equal False <| isGoodGameIDMaybe (Just "01-234#abc")

  , test "Nothing" <|
    \_ ->
      Expect.equal False <| isGoodGameIDMaybe Nothing

  ]
