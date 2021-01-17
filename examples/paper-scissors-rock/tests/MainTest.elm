module MainTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Dict exposing (Dict)
import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF
import BoardGameFramework.Clients as Clients exposing (Client, Clients)

import Main exposing (..)


-- Client tests


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


-- JSON decode tests

handDecoderTest : Test
handDecoderTest =
  describe "handDecoder test"

  [ test "Should decode Closed" <|
    \_ ->
      Enc.string "Closed"
      |> Dec.decodeValue handDecoder
      |> Expect.equal (Ok Closed)

  , test "Should reject bad string" <|
    \_ ->
      Enc.string "bAD stRiNG"
      |> Dec.decodeValue handDecoder
      |> Expect.err

  , test "Should reject non-string" <|
    \_ ->
      Enc.int 999
      |> Dec.decodeValue handDecoder
      |> Expect.err

  ]


roleDecoderTest : Test
roleDecoderTest =
  describe "roleDecoder test"

  [ test "Should decode Player Showing Scissors" <|
    \_ ->
      Enc.list Enc.string ["Player", "ShowingScissors"]
      |> Dec.decodeValue roleDecoder
      |> Expect.equal (Ok (Player (Showing Scissors)))

  , test "Should reject player without any hand" <|
    \_ ->
      Enc.list Enc.string ["Player"]
      |> Dec.decodeValue roleDecoder
      |> Expect.err

  , test "Should reject player with nonsense hand" <|
    \_ ->
      Enc.list Enc.string ["Player", "Scooby Doo"]
      |> Dec.decodeValue roleDecoder
      |> Expect.err

  , test "Should decode Observer" <|
    \_ ->
      Enc.list Enc.string ["Observer"]
      |> Dec.decodeValue roleDecoder
      |> Expect.equal (Ok Observer)

  , test "Should reject Observer with extra bits" <|
    \_ ->
      Enc.list Enc.string ["Observer", "ShowingScissors"]
      |> Dec.decodeValue roleDecoder
      |> Expect.err

  , test "Should reject nonsense role" <|
    \_ ->
      Enc.list Enc.string ["Troublemaker"]
      |> Dec.decodeValue roleDecoder
      |> Expect.err

  , test "Should reject empty list" <|
    \_ ->
      Enc.list Enc.string []
      |> Dec.decodeValue roleDecoder
      |> Expect.err

  , test "Should reject non-string-list" <|
    \_ ->
      Enc.int 999
      |> Dec.decodeValue roleDecoder
      |> Expect.err

  ]


-- JSON encoding tests


encodeHandTest : Test
encodeHandTest =
  describe "encodeHand test"

  [ test "Should encode Closed" <|
    \_ ->
      encodeHand Closed
      |> Enc.encode 0
      |> Expect.equal "\"Closed\""

  ]


encodeRoleTest : Test
encodeRoleTest =
  describe "encodeRole test"

  [ test "Should encode Player Closed" <|
    \_ ->
      let
        expected =
          Enc.list Enc.string ["Player", "Closed"]
          |> Enc.encode 0
      in
      encodeRole (Player Closed)
      |> Enc.encode 0
      |> Expect.equal expected

  , test "Should encode Player showing scissors" <|
    \_ ->
      let
        expected =
          Enc.list Enc.string ["Player", "ShowingScissors"]
          |> Enc.encode 0
      in
      encodeRole (Player (Showing Scissors))
      |> Enc.encode 0
      |> Expect.equal expected

  , test "Should encode Observer" <|
    \_ ->
      let
        expected =
          Enc.list Enc.string ["Observer"]
          |> Enc.encode 0
      in
      encodeRole Observer
      |> Enc.encode 0
      |> Expect.equal expected

  ]


encodeHandForClientTest : Test
encodeHandForClientTest =
  describe "encodeHandForClient test"

  [ test "Should encode Client 987, showing Scissors" <|
    \_ ->
      let
        expected =
          Enc.object
            [ ("id", Enc.string "987")
            , ("hand", Enc.string "ShowingScissors")
            ]
          |> Enc.encode 0
      in
      encodeHandForClient { id = "987", hand = Showing Scissors }
      |> Enc.encode 0
      |> Expect.equal expected

  ]
