module ClientsTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Dict exposing (Dict)
import Json.Encode as Enc
import Json.Decode as Dec

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


mapOneTest : Test
mapOneTest =
  describe "mapOneTest"
  [ test "Mapping one that's there should change it" <|
    \_ ->
      let
        fn entry =
          { entry | points = 21 }
      in
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.insert { id = "999.999", points = 40 }
      |> Clients.mapOne "123.456" fn
      |> Clients.toDict
      |> Dict.get "123.456"
      |> Expect.equal (Just { id = "123.456", points = 21 } )

  , describe "Mapping one that's not there should change nothing" <|
    let
      fn entry =
        { entry | points = 21 }
      clients2 =
        Clients.empty
        |> Clients.insert { id = "123.456", points = 20 }
        |> Clients.insert { id = "654.321", points = 40 }
        |> Clients.insert { id = "999.999", points = 40 }
        |> Clients.mapOne "333.333" fn
    in
    [ test "A" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.get "333.333"
        |> Expect.equal Nothing

    , test "B" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.get "123.456"
        |> Expect.equal (Just { id = "123.456", points = 20 } )

    , test "C" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.size
        |> Expect.equal 3

    ]

  , describe "Mapping one that's changes the ID should remove the old one" <|
    let
      fn entry =
        { id = "123.!!!", points = 21 }
      clients2 =
        Clients.empty
        |> Clients.insert { id = "123.456", points = 20 }
        |> Clients.insert { id = "654.321", points = 40 }
        |> Clients.insert { id = "999.999", points = 40 }
        |> Clients.mapOne "123.456" fn
    in
    [ test "A" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.get "123.456"
        |> Expect.equal Nothing

    , test "B" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.get "123.!!!"
        |> Expect.equal (Just { id = "123.!!!", points = 21 } )

    , test "C" <|
      \_ ->
        clients2
        |> Clients.toDict
        |> Dict.size
        |> Expect.equal 3

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


lengthTest : Test
lengthTest =
  describe "lengthTest"
  [ test "Empty list should have length 0" <|
    \_ ->
      Expect.equal 0 (Clients.length Clients.empty)

  , test "Three-strong list should have length 3" <|
    \_ ->
      let
        clients =
          Clients.empty
          |> Clients.insert { id = "123.456", points = 20 }
          |> Clients.insert { id = "654.321", points = 40 }
          |> Clients.insert { id = "999.999", points = 40 }
      in
      Expect.equal 3 (Clients.length clients)
  ]


filterLengthTest : Test
filterLengthTest =
  test "filterLengthTest - count those with a high score" <|
  \_ ->
    let
      clients =
        Clients.empty
        |> Clients.insert { id = "123.456", points = 20 }
        |> Clients.insert { id = "654.321", points = 40 }
        |> Clients.insert { id = "999.999", points = 100 }
    in
    clients
    |> Clients.filterLength (\c -> c.points >= 100)
    |> Expect.equal 1


allTest : Test
allTest =
  describe "allTest" <|
  let
    clients =
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.insert { id = "999.999", points = 40 }
  in
  [ test "If all pass a test, should be true" <|
    \_ ->
      clients
      |> Clients.all (\c -> c.points > 0)
      |> Expect.equal True

  , test "If only some pass a test, should be false" <|
    \_ ->
      clients
      |> Clients.all (\c -> c.points == 40)
      |> Expect.equal False

  , test "If none pass a test, should be false" <|
    \_ ->
      clients
      |> Clients.all (\c -> c.points == 999)
      |> Expect.equal False

  , test "If list is empty, should be true" <|
    \_ ->
      Clients.empty
      |> Clients.all (\c -> c.points == 999)
      |> Expect.equal True

  ]


anyTest : Test
anyTest =
  describe "anyTest" <|
  let
    clients =
      Clients.empty
      |> Clients.insert { id = "123.456", points = 20 }
      |> Clients.insert { id = "654.321", points = 40 }
      |> Clients.insert { id = "999.999", points = 40 }
  in
  [ test "If only some pass a test, should be true" <|
    \_ ->
      clients
      |> Clients.any (\c -> c.points == 40)
      |> Expect.equal True

  , test "If all pass a test, should be true" <|
    \_ ->
      clients
      |> Clients.any (\c -> c.points > 0)
      |> Expect.equal True

  , test "If none pass a test, should be false" <|
    \_ ->
      clients
      |> Clients.any (\c -> c.points == 999)
      |> Expect.equal False

  , test "If empty, should be false" <|
    \_ ->
      Clients.empty
      |> Clients.any (\c -> c.points == 999)
      |> Expect.equal False

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
      |> Clients.length
      |> Expect.equal 3

  , test "Converting from empty list should yield an empty Clients" <|
    \_ ->
      []
      |> Clients.fromList
      |> Clients.length
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
      |> Clients.length
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
      \_ -> Expect.equal 3 (Clients.length clientsSimple)

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
      \_ -> Expect.equal 1 (Clients.length clientsClash)

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
      \_ -> Expect.equal 3 (Clients.length clientsDifferent)

    , test "Should contain a new kind of element" <|
      \_ ->
        Clients.get "123.456" clientsDifferent
        |> Expect.equal (Just { id = "123.456", tally = 2 })
    ]
  ]


foldTest : Test
foldTest =
  test "foldTest - sum all points" <|
  \_ ->
    let
      fn c a = c.points + a
      clients =
        Clients.empty
        |> Clients.insert { id = "123.456", points = 20 }
        |> Clients.insert { id = "654.321", points = 40 }
        |> Clients.insert { id = "999.999", points = 40 }
    in
    Clients.fold fn 1 clients
    |> Expect.equal 101


filterTest : Test
filterTest =
  test "filterTest - get only those with a high score" <|
  \_ ->
    let
      clients =
        Clients.empty
        |> Clients.insert { id = "123.456", points = 20 }
        |> Clients.insert { id = "654.321", points = 40 }
        |> Clients.insert { id = "999.999", points = 100 }
    in
    clients
    |> Clients.filter (\c -> c.points >= 100)
    |> Clients.length
    |> Expect.equal 1


-- filterMap test, including types and code for use in documentation


type Role =
  Observer
  | Player PlayerType

type PlayerType =
  Attacker
  | Defender

type alias ParticipantRecord =
  { role : Role
  }

type alias PlayerRecord =
  { playerType : PlayerType
  }


filterMapTest : Test
filterMapTest =
  describe "filterMapTest - create a list of those who have scored 100 or more" <|
  let
    clients : Clients ParticipantRecord
    clients =
      Clients.empty
      |> Clients.insert { id = "123.456", role = Observer }
      |> Clients.insert { id = "654.321", role = Player Attacker }
      |> Clients.insert { id = "999.999", role = Player Defender }

    player : Client ParticipantRecord -> Maybe (Client PlayerRecord)
    player c =
      case c.role of
        Player pType ->
          Just
            { id = c.id
            , playerType = pType
            }

        Observer ->
          Nothing

    onlyPlayers : Clients PlayerRecord
    onlyPlayers =
      Clients.filterMap player clients
  in
  [ test "Should have removed an under-scorer" <|
    \_ ->
      Clients.length onlyPlayers
      |> Expect.equal 2

  , test "Should have the first centurian" <|
    \_ ->
      Clients.get "654.321" onlyPlayers
      |> Expect.equal (Just { id = "654.321", playerType = Attacker })

  , test "Should have the second centurian" <|
    \_ ->
      Clients.get "999.999" onlyPlayers
      |> Expect.equal (Just { id = "999.999", playerType = Defender })

  ]


-- partition and beyond

partitionTest : Test
partitionTest =
  describe "partitionTest - split players from observers" <|
  let
    clients =
      Clients.empty
      |> Clients.insert { id = "123.111", player = True }
      |> Clients.insert { id = "123.222", player = True }
      |> Clients.insert { id = "123.333", player = True }
      |> Clients.insert { id = "999.444", player = False }
      |> Clients.insert { id = "999.555", player = False }
    (players, observers) = Clients.partition .player clients
  in
  [ test "Should be 3 players" <|
    \_ -> Expect.equal 3 (Clients.length players)

  , test "Should be 2 observers" <|
    \_ -> Expect.equal 2 (Clients.length observers)

  ]


unionTest : Test
unionTest =
  describe "unionTest" <|
  let
    clients1 =
      Clients.empty
      |> Clients.insert { id = "123.111", player = True }
      |> Clients.insert { id = "123.222", player = True }
      |> Clients.insert { id = "123.333", player = True }
    clients2 =
      Clients.empty
      |> Clients.insert { id = "123.222", player = False } -- Clash
      |> Clients.insert { id = "123.333", player = False } -- Clash
      |> Clients.insert { id = "123.444", player = False }
    clientsAll =
      Clients.union clients1 clients2
  in
  [ test "Count should be correct" <|
    \_ ->
      Clients.length clientsAll
      |> Expect.equal 4

  , test "First client should be present" <|
    \_ ->
      Clients.get "123.111" clientsAll
      |> Expect.equal (Just { id = "123.111", player = True })

  , test "First of the first clash should be present" <|
    \_ ->
      Clients.get "123.222" clientsAll
      |> Expect.equal (Just { id = "123.222", player = True })

  , test "First of the second clash should be present" <|
    \_ ->
      Clients.get "123.333" clientsAll
      |> Expect.equal (Just { id = "123.333", player = True })

  , test "Last client should be present" <|
    \_ ->
      Clients.get "123.444" clientsAll
      |> Expect.equal (Just { id = "123.444", player = False })

  ]


intersectTest : Test
intersectTest =
  describe "intersectTest" <|
  let
    clients1 =
      Clients.empty
      |> Clients.insert { id = "123.111", player = True }
      |> Clients.insert { id = "123.222", player = True }
      |> Clients.insert { id = "123.333", player = True }
    clients2 =
      Clients.empty
      |> Clients.insert { id = "123.222", player = False } -- Duplicate
      |> Clients.insert { id = "123.333", player = False } -- Duplicate
      |> Clients.insert { id = "123.444", player = False }
    clientsBoth =
      Clients.intersect clients1 clients2
  in
  [ test "Count should be correct" <|
    \_ ->
      Clients.length clientsBoth
      |> Expect.equal 2

  , test "First duplicate should be present" <|
    \_ ->
      Clients.get "123.222" clientsBoth
      |> Expect.equal (Just { id = "123.222", player = True })

  , test "Second duplicate should be present" <|
    \_ ->
      Clients.get "123.333" clientsBoth
      |> Expect.equal (Just { id = "123.333", player = True })

  ]


diffTest : Test
diffTest =
  describe "diffTest" <|
  let
    clients1 =
      Clients.empty
      |> Clients.insert { id = "123.111", player = True } -- Only in first list
      |> Clients.insert { id = "123.222", player = True }
      |> Clients.insert { id = "123.333", player = True }
    clients2 =
      Clients.empty
      |> Clients.insert { id = "123.222", player = False }
      |> Clients.insert { id = "123.333", player = False }
      |> Clients.insert { id = "123.444", player = False }
    clientsDiff =
      Clients.diff clients1 clients2
  in
  [ test "Count should be correct" <|
    \_ ->
      Clients.length clientsDiff
      |> Expect.equal 1

  , test "Correct client should be present" <|
    \_ ->
      Clients.get "123.111" clientsDiff
      |> Expect.equal (Just { id = "123.111", player = True })

  ]


type alias JsonClient =
  { name : String
  , player : Bool
  }


jsonTest : Test
jsonTest =
  let
    clients =
      Clients.empty
      |> Clients.insert { id = "123.111", name = "Aaa", player = True }
      |> Clients.insert { id = "123.222", name = "Bbb", player = True }
      |> Clients.insert { id = "123.333", name = "Ccc", player = False }
  in
  test "Decoding should undo encoding" <|
    \_ ->
      clients
      |> encodeDecode
      |> \result ->
        case result of
          Ok val ->
            Expect.equal val clients

          Err decError ->
            "Bad decoder result: " ++ (Dec.errorToString decError)
            |> Expect.fail


encodeDecode : Clients JsonClient -> Result Dec.Error (Clients JsonClient)
encodeDecode cs =
  let
    encodeClients =
      Clients.encode
      [ ("name", .name >> Enc.string)
      , ("player", .player >> Enc.bool)
      ]

    singleClientDecoder : Dec.Decoder (Client JsonClient)
    singleClientDecoder =
      Dec.map3
      (\id name player -> { id = id, name = name, player = player })
      (Dec.field "id" Dec.string)
      (Dec.field "name" Dec.string)
      (Dec.field "player" Dec.bool)

    -- Just to check the type and make sure our documentation is correct,
    -- not for this test:
    clientsDecoder : Dec.Decoder (Clients JsonClient)
    clientsDecoder =
      Clients.decoder singleClientDecoder
  in
  cs
  |> encodeClients
  |> Enc.encode 0
  |> Dec.decodeString (Clients.decoder singleClientDecoder)
