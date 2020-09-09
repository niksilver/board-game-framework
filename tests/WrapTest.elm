module WrapTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF
import BoardGameFramework.Wrap as Wrap


type Body =
  Card String
  | Chips (List Int)


encodeCard : String -> Enc.Value
encodeCard text =
  Enc.string text
  |> Wrap.encode "card"


encodeChips : List Int -> Enc.Value
encodeChips chips =
  Enc.list Enc.int chips
  |> Wrap.encode "chips"


cardDecoder : Dec.Decoder String
cardDecoder =
  Dec.string


chipsDecoder : Dec.Decoder (List Int)
chipsDecoder =
  Dec.list Dec.int


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  Wrap.decoder
  [ ("card", Dec.map Card cardDecoder)
  , ("chips", Dec.map Chips chipsDecoder)
  ]


jsonTest : Test
jsonTest =
  describe "Wrapping Body"
  [ test "Encode-decode a die face should yield the die face" <|
    \_ ->
      "Tell us a secret"
      |> encodeCard
      |> Enc.encode 0
      |> Dec.decodeString bodyDecoder
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val (Card "Tell us a secret")

          Err decError ->
            "Bad decoder result: " ++ (Dec.errorToString decError)
            |> Expect.fail

  , test "Encode-decode chips should yield the chips" <|
    \_ ->
      [100, 150, 0]
      |> encodeChips
      |> Enc.encode 0
      |> Dec.decodeString bodyDecoder
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val (Chips [100, 150, 0])

          Err decError ->
            "Bad decoder result: " ++ (Dec.errorToString decError)
            |> Expect.fail
  ]
