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


singletonTest : Test
singletonTest =
  describe "singletonTest"
  [ test "singleton client list should have size one" <|
    \_ ->
      Clients.singleton { id = "123.456" }
      |> Dict.size
      |> Expect.equal 1
  ]


insertTest : Test
insertTest =
  describe "insertTest"
  [ test "inserting new should add 1 to size" <|
    \_ ->
      Clients.empty
      |> Clients.insert { id = "123.456" }
      |> Dict.size
      |> Expect.equal 1

  , test "inserting existing client with new data should retain size" <|
    \_ ->
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "123.456", points = 40 }
      |> Dict.size
      |> Expect.equal 1

  , test "inserting two clients should add 2 to size" <|
    \_ ->
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Dict.size
      |> Expect.equal 2
  ]
