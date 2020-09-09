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
  [ test "Encode-decode a card should yield the card" <|
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


-- Setup (including dummy functions) and tests for receive


type Msg =
  Received (Result Dec.Error (BGF.Envelope Body))


-- Dummy Model
type Model = DummyModel


-- Dummy incoming function. Should be
-- port incoming : ...
incoming : (Enc.Value -> msg) -> Sub msg
incoming _ =
  Sub.none


-- Dummy subscriptions function
subscriptions : Model -> Sub Msg
subscriptions _ =
  incoming receive


receive : Enc.Value -> Msg
receive =
  Wrap.receive
  Received
  [ ("card", Dec.map Card cardDecoder)
  , ("chips", Dec.map Chips chipsDecoder)
  ]


receiveAlt : Enc.Value -> Msg
receiveAlt v =
  BGF.decode bodyDecoder v
  |> Received


receiveTest : Test
receiveTest =
  describe "receiveTest"
  [ test "Receiving a card" <|
    \_ ->
      let
        envValue =
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", encodeCard "Tell us a secret" )
          ]
      in
      case receive envValue of
        Received (Ok env) ->
          case env of
            BGF.Peer rec ->
              Expect.equal rec.body <| Card "Tell us a secret"

            other ->
              Expect.fail <| "Not a Peer envelope: " ++ (Debug.toString other)

        Received (Err err) ->
          Expect.fail (Debug.toString err)

  , test "Receiving chips" <|
    \_ ->
      let
        envValue =
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", encodeChips [100, 0, 150] )
          ]
      in
      case receive envValue of
        Received (Ok env) ->
          case env of
            BGF.Peer rec ->
              Expect.equal rec.body <| Chips [100, 0, 150]

            other ->
              Expect.fail <| "Not a Peer envelope: " ++ (Debug.toString other)

        Received (Err err) ->
          Expect.fail (Debug.toString err)


  ]


receiveAltTest : Test
receiveAltTest =
  describe "receiveAltTest"
  [ test "Receiving a card" <|
    \_ ->
      let
        envValue =
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", encodeCard "Tell us a secret" )
          ]
      in
      case receiveAlt envValue of
        Received (Ok env) ->
          case env of
            BGF.Peer rec ->
              Expect.equal rec.body <| Card "Tell us a secret"

            other ->
              Expect.fail <| "Not a Peer envelope: " ++ (Debug.toString other)

        Received (Err err) ->
          Expect.fail (Debug.toString err)

  , test "Receiving chips" <|
    \_ ->
      let
        envValue =
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", encodeChips [100, 0, 150] )
          ]
      in
      case receiveAlt envValue of
        Received (Ok env) ->
          case env of
            BGF.Peer rec ->
              Expect.equal rec.body <| Chips [100, 0, 150]

            other ->
              Expect.fail <| "Not a Peer envelope: " ++ (Debug.toString other)

        Received (Err err) ->
          Expect.fail (Debug.toString err)

  ]
