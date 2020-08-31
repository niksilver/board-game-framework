module SyncTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import BoardGameFramework.Sync as Sync exposing (Sync)


type GameState =
  FromOriginal
  | FromNew


resolveTest : Test
resolveTest =
  describe "Sync.resolve"
  [ describe "Original's envNum is assumed (Nothing)"
    [ describe "New's step is earlier"
      [ test "Should resolve to original" <|
        \_ ->
          makeSync 20 Nothing FromOriginal
          |> Sync.resolve 1 (makeSync 19 (Just 1) FromNew)
          |> Sync.value
          |> Expect.equal FromOriginal
      ]
    , describe "New's step is later"
      [ test "Should resolve to new" <|
        \_ ->
          makeSync 20 Nothing FromOriginal
          |> Sync.resolve 1 (makeSync 21 (Just 1) FromNew)
          |> Sync.value
          |> Expect.equal FromNew
      ]
    , describe "New's step is the same"
      [ test "Should resolve to original" <|
        \_ ->
          makeSync 20 Nothing FromOriginal
          |> Sync.resolve 1 (makeSync 20 (Just 1) FromNew)
          |> Sync.value
          |> Expect.equal FromNew
      ]
    ]

  , describe "Original's envNum is Just 11"
    [ describe "New's step is earlier"
      [ describe "New's envNum is earlier"
        [ test "Should resolve to original" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 10 (makeSync 19 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromOriginal
        ]
      , describe "New's envNum is later"
        [ test "Should resolve to original" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 12 (makeSync 19 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromOriginal
        ]
      , describe "New's envNum is the same"
        [ test "Should resolve to original" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 11 (makeSync 19 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromOriginal
        ]
      ]
    , describe "New's step is later"
      [ describe "New's envNum is earlier"
        [ test "Should resolve to new" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 10 (makeSync 21 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromNew
        ]
      , describe "New's envNum is later"
        [ test "Should resolve to new" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 12 (makeSync 21 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromNew
        ]
      , describe "New's envNum is the same"
        [ test "Should resolve to new" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 12 (makeSync 21 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromNew
        ]
      ]

    , describe "New's step is the same"
      [ describe "New's envNum is earlier"
        [ test "Should resolve to new" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 10 (makeSync 20 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromNew
        ]
      , describe "New's envNum is later"
        [ test "Should resolve to new" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 12 (makeSync 20 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromOriginal
        ]
      , describe "New's envNum is the same"
        [ test "Should resolve to original" <|
          \_ ->
            makeSync 20 (Just 11) FromOriginal
            |> Sync.resolve 11 (makeSync 20 (Just 1) FromNew)
            |> Sync.value
            |> Expect.equal FromOriginal
        ]
      ]
    ]
  ]


makeSync : Int -> Maybe Int -> GameState -> Sync GameState
makeSync step mEnvNum val =
  let
    sync0 = Sync.zero val
    incStep state s1 =
      Sync.mapToNext identity s1
    syncWithStep =
      List.foldl incStep sync0 (List.repeat step val)
    syncWithEnvNum =
      case mEnvNum of
        Nothing ->
          syncWithStep

        Just envNum ->
          syncWithStep
          |> Sync.resolve envNum syncWithStep
  in
  syncWithEnvNum
