module WrapTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF
import BoardGameFramework.Wrap as Wrap


type Body =
  DieFace Int
  | Chips (List Int)


encodeDieFace : Int -> Enc.Value
encodeDieFace n =
  Enc.int n
  |> Wrap.encode "dieFace"


encodeChips : List Int -> Enc.Value
encodeChips chips =
  Enc.list Enc.int chips
  |> Wrap.encode "chips"


dieFaceDecoder : Dec.Decoder Int
dieFaceDecoder =
  Dec.int


chipsDecoder : Dec.Decoder (List Int)
chipsDecoder =
  Dec.list Dec.int


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  Wrap.decoder
  [ ("dieFace", Dec.map DieFace dieFaceDecoder)
  , ("chips", Dec.map Chips chipsDecoder)
  ]


jsonTest : Test
jsonTest =
  describe "Wrapping Body"
  [ test "Encode-decode a die face should yield the die face" <|
    \_ ->
      6
      |> encodeDieFace
      |> Enc.encode 0
      |> Dec.decodeString bodyDecoder
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val (DieFace 6)

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
