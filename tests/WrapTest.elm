module WrapTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF
import BoardGameFramework.Wrap as Wrap


type PersonInfo =
  Name String
  | Age Int


nameEncode : String -> Enc.Value
nameEncode =
  Enc.string


ageEncode : Int -> Enc.Value
ageEncode =
  Enc.int


personInfoEncode : PersonInfo -> Enc.Value
personInfoEncode pi =
  case pi of
    Name name ->
      Wrap.encode "name" (nameEncode name)

    Age age ->
      Wrap.encode "age" (ageEncode age)


nameDecoder : Dec.Decoder String
nameDecoder =
  Dec.string


ageDecoder : Dec.Decoder Int
ageDecoder =
  Dec.int


personInfoDecoder : Dec.Decoder PersonInfo
personInfoDecoder =
  Dec.oneOf
  [ Wrap.decoder "name" (Dec.map Name nameDecoder)
  , Wrap.decoder "age" (Dec.map Age ageDecoder)
  ]


jsonTest : Test
jsonTest =
  describe "Wrapping PersonInfo"
  [ test "Encode-decode a name should yield the name" <|
    \_ ->
      Name "Fred Bloggs"
      |> encodeDecode
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val (Name "Fred Bloggs")

          Err decError ->
            "Bad decoder result: " ++ (Dec.errorToString decError)
            |> Expect.fail

  , test "Encode-decode an age should yield the age" <|
    \_ ->
      Age 27
      |> encodeDecode
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val (Age 27)

          Err decError ->
            "Bad decoder result: " ++ (Dec.errorToString decError)
            |> Expect.fail
  ]

encodeDecode : PersonInfo -> Result Dec.Error PersonInfo
encodeDecode pi =
  pi
  |> personInfoEncode
  |> Enc.encode 0
  |> Dec.decodeString personInfoDecoder
