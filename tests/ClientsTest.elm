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
      |> Clients.toDict
      |> Dict.size
      |> Expect.equal 0
  ]


singletonTest : Test
singletonTest =
  describe "singletonTest"
  [ test "singleton client list should have size one" <|
    \_ ->
      Clients.singleton { id = "123.456" }
      |> Clients.toDict
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
      |> Clients.toDict
      |> Dict.size
      |> Expect.equal 1

  , test "inserting existing client with new data should retain size" <|
    \_ ->
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "123.456", points = 40 }
      |> Clients.toDict
      |> Dict.size
      |> Expect.equal 1

  , test "inserting two clients should add 2 to size" <|
    \_ ->
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.toDict
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
      |> Clients.toDict
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
      |> Clients.toDict
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
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.member "999.999"
        |> Expect.equal True

    , test "B" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.member "123.456"
        |> Expect.equal False

    , test "C" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.size
        |> Expect.equal 2
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
    |> Clients.toDict
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


fromListTest : Test
fromListTest =
  describe "fromListTest"
  [ test "Converting from a simple non-empty list should be okay" <|
    \_ ->
      let
        list =
          [ { id = "123.456", points = 20 }
          , { id = "654.321", points = 40 }
          , { id = "999.999", points = 40 }
          ]
      in
      list
      |> Clients.fromList
      |> Clients.size
      |> Expect.equal 3

  , test "Converting from empty list should yield an empty Clients" <|
    \_ ->
      []
      |> Clients.fromList
      |> Clients.size
      |> Expect.equal 0

  , test "Converting from a duplicated-id list should remove dupes" <|
    \_ ->
      let
        list =
          [ { id = "123.456", points = 20 }
          , { id = "654.321", points = 40 }
          , { id = "654.321", points = 50 }  -- Duplicate
          , { id = "444.444", points = 60 }
          , { id = "999.999", points = 70 }
          , { id = "999.999", points = 80 }  -- Duplicate
          ]
      in
      list
      |> Clients.fromList
      |> Clients.size
      |> Expect.equal 4

  ]


mapTest : Test
mapTest =
  describe "mapTest" <|
  let
    clients =
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.insert { id = "999.999", points = 40 }
  in
  [ describe "With a simple map" <|
    let
      clientsSimple =
        Clients.map (\c -> { c | points = 0 }) clients
    in
    [ test "Should be of size 3" <|
      \_ -> Expect.equal 3 (Clients.size clientsSimple)

    , test "Should contain 123.456" <|
      \_ ->
        Clients.get "123.456" clientsSimple
        |> Expect.equal (Just { id = "123.456", points = 0 })
    ]

  , describe "With a map that reduces everything to one" <|
    let
      clientsClash =
        Clients.map (\c -> { c | id = "xxx.xxx" }) clients
    in
    [ test "Should be of size 1" <|
      \_ -> Expect.equal 1 (Clients.size clientsClash)

    , test "Should contain xxx.xxx" <|
      \_ ->
        Clients.get "xxx.xxx" clientsClash
        |> Maybe.map .id
        |> Expect.equal (Just "xxx.xxx")
    ]

  , describe "With a map that changes the type of client" <|
    let
      clientsDifferent =
        Clients.map (\c -> { id = c.id, tally = c.points // 10 }) clients
    in
    [ test "Should be of size 3" <|
      \_ -> Expect.equal 3 (Clients.size clientsDifferent)

    , test "Should contain a new kind of element" <|
      \_ ->
        Clients.get "123.456" clientsDifferent
        |> Expect.equal (Just { id = "123.456", tally = 2 })
    ]
  ]


foldTest : Test
foldTest =
  test "foldTest - sum all points" <|
    let
      fn c a = c.points + a
      clients =
        Clients.empty
        |> Clients.insert { id = "123.456", points = 20 }
        |> Clients.insert { id = "654.321", points = 40 }
        |> Clients.insert { id = "999.999", points = 40 }
    in
    \_ -> Expect.equal 101 <| Clients.fold fn 1 clients
