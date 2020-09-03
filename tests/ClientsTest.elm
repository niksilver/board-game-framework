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


removeTest : Test
removeTest =
  test "Removing one should yield one less" <|
  \_ ->
    Clients.empty
    |> Clients.insert { id = "123.456", points = 20 }
    |> Clients.insert { id = "654.321", points = 40 }
    |> Clients.insert { id = "999.999", points = 40 }
    |> Clients.remove "654.321"
    |> Dict.size
    |> Expect.equal 2


memberTest : Test
memberTest =
  describe "memberTest" <|
  let
    clients =
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.insert { id = "999.999", points = 40 }
  in
  [ test "Member should be a member" <|
    \_ -> Expect.equal True (Clients.member "999.999" clients)

  , test "Non-member should not be a member" <|
    \_ -> Expect.equal False (Clients.member "xxx.xxx" clients)
  ]


getTest : Test
getTest =
  describe "getTest" <|
  let
    clients =
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.insert { id = "999.999", points = 40 }
  in
  [ test "Getting a member should be Just it" <|
    \_ ->
      ( Clients.get "654.321" clients
        |> Expect.equal (Just { id = "654.321", points = 40 })
      )

  , test "Getting a non-member should be Nothing" <|
    \_ ->
      ( Clients.get "xxx.xxx" clients
        |> Expect.equal Nothing
      )
  ]


sizeTest : Test
sizeTest =
  describe "sizeTest"
  [ test "Empty list should have size 0" <|
    \_ ->
      Expect.equal 0 (Clients.size Clients.empty)

  , test "Three-strong list should have size 3" <|
    \_ ->
      let
        clients =
          Clients.empty
          |> Clients.insert { id = "123.456", points = 20 }
          |> Clients.insert { id = "654.321", points = 40 }
          |> Clients.insert { id = "999.999", points = 40 }
      in
      Expect.equal 3 (Clients.size clients)
  ]
