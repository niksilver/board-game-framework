module MainTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Dict exposing (Dict)
import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF
import BoardGameFramework.Clients as Clients exposing (Client, Clients)

import Main exposing (..)


playerCountTest : Test
playerCountTest =
  describe "playerCountTest"
  [ test "If only client is only player, should be one player" <|
    \_ ->
      Clients.singleton { id = "dummy", name = "Bob", player = True }
      |> playerCount
      |> Expect.equal 1
  ]
