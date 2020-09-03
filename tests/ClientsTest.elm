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


updateTest : Test
updateTest =
  describe "updateTest"
  [ test "Updating Just -> Nothing should delete the client" <|
    \_ ->
      let
        fn =
          always Nothing
      in
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.insert { id = "999.999", points = 40 }
      |> Clients.update "123.456" fn
      |> Dict.size
      |> Expect.equal 2

  , test "Updating Nothing -> Just should insert a client" <|
    \_ ->
      let
        fn =
          always <| Just { id = "999.999", points = 40 }
      in
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.update "999.999" fn
      |> Dict.size
      |> Expect.equal 3

  , describe "Updating something to have a different id will replace the old" <|
    let
      fn =
        always <| Just { id = "999.999", points = 40 }
      clients2 =
        Clients.empty
        |> Clients.insert { id = "123.456", points = 20 }
        |> Clients.insert { id = "654.321", points = 40 }
        |> Clients.update "123.456" fn
    in
    [ test "A" <|
      \_ -> Expect.equal True <| Dict.member "999.999" clients2

    , test "B" <|
      \_ -> Expect.equal False <| Dict.member "123.456" clients2

    , test "C" <|
      \_ -> Expect.equal 2 <| Dict.size clients2
    ]

  ]