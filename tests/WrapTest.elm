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


dieFaceEncode : Int -> Enc.Value
dieFaceEncode =
  Enc.int


chipsEncode : List Int -> Enc.Value
chipsEncode =
  Enc.list Enc.int


encodeBody : Body -> Enc.Value
encodeBody pi =
  case pi of
    DieFace dieFace ->
      Wrap.encode "dieFace" (dieFaceEncode dieFace)

    Chips chips ->
      Wrap.encode "chips" (chipsEncode chips)


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
      DieFace 6
      |> encodeDecode
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val (DieFace 6)

          Err decError ->
            "Bad decoder result: " ++ (Dec.errorToString decError)
            |> Expect.fail

  , test "Encode-decode chips should yield the chips" <|
    \_ ->
      Chips [100, 150, 0]
      |> encodeDecode
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val (Chips [100, 150, 0])

          Err decError ->
            "Bad decoder result: " ++ (Dec.errorToString decError)
            |> Expect.fail
  ]

encodeDecode : Body -> Result Dec.Error Body
encodeDecode pi =
  pi
  |> encodeBody
  |> Enc.encode 0
  |> Dec.decodeString bodyDecoder
