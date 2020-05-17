module Parsing exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)

import Url

import BoardGameFramework exposing (..)


suite : Test
suite =
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
