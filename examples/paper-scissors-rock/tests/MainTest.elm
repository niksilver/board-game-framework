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
      Clients.singleton { id = "dummy", name = "Bob", role = Player Closed, score = 0 }
      |> playerCount
      |> Expect.equal 1
  ]


addClientTest : Test
addClientTest =
  describe "addClientTest"
  [ test "Adding first client should make it a player" <|
    \_ ->
      Clients.empty
      |> addClient { id = "111", name = "Alice" }
      |> Clients.get "111"
      |> Expect.equal (Just { id = "111", name = "Alice", role = Player Closed, score = 0 })

  , describe "Adding two clients should make them both players" <|
    let
      clients =
        Clients.empty
        |> addClient { id = "111", name = "Alice" }
        |> addClient { id = "222", name = "Bob" }
    in
    [ test "First should be a player" <|
      \_ ->
        clients
        |> Clients.get "111"
        |> Expect.equal (Just { id = "111", name = "Alice", role = Player Closed, score = 0 })

    , test "Second should be a player" <|
      \_ ->
        clients
        |> Clients.get "222"
        |> Expect.equal (Just { id = "222", name = "Bob", role = Player Closed, score = 0 })

    ]

  , describe "Adding three client should make only first two players" <|
    let
      clients =
        Clients.empty
        |> addClient { id = "111", name = "Alice" }
        |> addClient { id = "222", name = "Bob" }
        |> addClient { id = "333", name = "Chik" }
    in
    [ test "First should be a player" <|
      \_ ->
        clients
        |> Clients.get "111"
        |> Expect.equal (Just { id = "111", name = "Alice", role = Player Closed, score = 0 })

    , test "Second should be a player" <|
      \_ ->
        clients
        |> Clients.get "222"
        |> Expect.equal (Just { id = "222", name = "Bob", role = Player Closed, score = 0 })

    , test "Third should not be a player" <|
      \_ ->
        clients
        |> Clients.get "333"
        |> Expect.equal (Just { id = "333", name = "Chik", role = Observer, score = 0 })

    ]

  , describe "Adding second player twice should keep them a player" <|
    let
      clients =
        Clients.empty
        |> addClient { id = "111", name = "Alice" }
        |> addClient { id = "222", name = "Bob" }
        |> addClient { id = "222", name = "Bob" }
    in
    [ test "First should be a player" <|
      \_ ->
        clients
        |> Clients.get "111"
        |> Expect.equal (Just { id = "111", name = "Alice", role = Player Closed, score = 0 })

    , test "Second should be a player" <|
      \_ ->
        clients
        |> Clients.get "222"
        |> Expect.equal (Just { id = "222", name = "Bob", role = Player Closed, score = 0 })

    ]

  ]
