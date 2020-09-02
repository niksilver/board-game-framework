module ClientsTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Dict exposing (Dict)

import BoardGameFramework as BGF
import BoardGameFramework.Clients as Clients exposing (Client, Clients)


emptyTest : Test
emptyTest =
  describe "emptyTest"
  [ test "empty client list should have zero size" <|
    \_ ->
      Clients.empty
      |> Dict.size
      |> Expect.equal 0
  ]
