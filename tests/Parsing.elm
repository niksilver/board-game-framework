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

addGameIDTest : Test
addGameIDTest =
  describe "Adding an id to a Url"
  [ test "For lengthy URL with no / at end" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/abc"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          addGameID u "dd-ee" |> Url.toString |>
          Expect.equal "http://example.com/abc/dd-ee"

  , test "For lengthy URL with / at end" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/abc/"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          addGameID u "dd-ee" |> Url.toString |>
          Expect.equal "http://example.com/abc/dd-ee"

  , test "For base URL" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          addGameID u "dd-ee" |> Url.toString |>
          Expect.equal "http://example.com/dd-ee"

  ]


lastSegmentTest : Test
lastSegmentTest =
  describe "Extracting a game ID from a URL"
  [ test "Ordinary long URL without / at end" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/aa/bb/cc"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          lastSegment u |> Expect.equal (Just "cc")
  , test "Ordinary long URL with / at end" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/aa/bb/cc/"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          lastSegment u |> Expect.equal Nothing

  , test "Just top level URL" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          lastSegment u |> Expect.equal Nothing

  , test "Single-segment URL without / at end" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/aa"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          lastSegment u |> Expect.equal (Just "aa")

  , test "URL with fragment and query string" <|
    \_ ->
      let
        url = Url.fromString "http://example.com/aa/bb#cc?dd=ee"
      in
      case url of
        Nothing ->
          Expect.fail "Didn't even start with a correct Url"

        Just u ->
          lastSegment u |> Expect.equal (Just "bb")

  ]
