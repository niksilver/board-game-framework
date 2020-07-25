module Players exposing (..)

import Expect exposing (Expectation)
import Test exposing (..)

import Main exposing (..)
import Dict exposing (Dict)
import Url

import BoardGameFramework as BGF exposing (ClientId)


playersTest : Test
playersTest =
  describe "players"
  [ test "New players" <|
    \_ ->
      let
        partModel =
          { myId = "111"
          , players = Dict.empty
          , connectivity = BGF.Opened
          }
        peer =
          makePeer
            "222"
            ["111", "333"]
            [("111", ""), ("222", "Bob"), ("333", "Carol")]
      in
      partModel
      |> updateWithEnvelope peer
      |> Tuple.first
      |> expectEqualDict
          [("111", ""), ("222", "Bob"), ("333", "Carol")]

  ]


makePeer : ClientId -> List ClientId -> List (ClientId, String) -> Envelope
makePeer from to players =
  BGF.Peer
    { from = from
    , to = to
    , num = 88
    , time = 987654321
    , body = { players = Dict.fromList players }
    }


expectEqualDict : List (ClientId, String) -> EnvModel a -> Expectation
expectEqualDict pairs eModel =
  let
    expected = Dict.fromList pairs
    actual = eModel.players
  in
  Expect.equalDicts actual expected
