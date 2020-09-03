module SyncTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF
import BoardGameFramework.Sync as Sync exposing (Sync)


jsonTest : Test
jsonTest =
  test "Decoding should undo encoding" <|
    \_ ->
      let
        mySyncedValue = Sync.zero "My value"
      in
        mySyncedValue
        |> encodeDecode
        |> \result ->
          case result of
            Ok syncedVal ->
              syncedVal
              |> Sync.value
              |> Expect.equal "My value"

            Err decError ->
              Expect.fail <| "Bad decoder result: " ++ (Dec.errorToString decError)


resolveTest : Test
resolveTest =
  describe "resolveTest"
  [ test "Comparing with a later step should yield that (one way round)" <|
    \_ ->
      let
        v0 = syncWithStep "zero" 0
        v9 = syncWithStep "nine" 9
        vResolved = Sync.resolve (env 100 10000) v9 v0
      in
      Expect.equal "nine" <| Sync.value vResolved

  , test "Comparing with a later step should yield that (other way round)" <|
    \_ ->
      let
        v0 = syncWithStep "zero" 0
        v9 = syncWithStep "nine" 9
        vResolved = Sync.resolve (env 100 10000) v0 v9
      in
      Expect.equal "nine" <| Sync.value vResolved

  , test "Resolving the same step from an envelope should result in that" <|
    \_ ->
      let
        vA = syncWithStep "Original value...." 9
        vB = syncWithStep "Value from network" 9
        vResolved = Sync.resolve (env 100 10000) vB vA
      in
      Expect.equal "Value from network" <| Sync.value vResolved

  , test "Resolving the same step at the same time should yield the lower num (one way round" <|
    \_ ->
      let
        v0 = syncWithStep "Original value......." 0
        vB1 = syncWithStep "Value 1 from network" 9
        vB2 = syncWithStep "Value 2 from network" 9
        vB1WithEnv = Sync.resolve (env 100 10000) vB1 v0
        vResolved = Sync.resolve (env 101 10000) vB2 vB1WithEnv
      in
      Expect.equal "Value 1 from network" <| Sync.value vResolved

  , test "Resolving the same step at the same time should yield the lower num (other way round" <|
    \_ ->
      let
        v0 = syncWithStep "Original value......." 0
        vB1 = syncWithStep "Value 1 from network" 9
        vB2 = syncWithStep "Value 2 from network" 9
        vB2WithEnv = Sync.resolve (env 101 10000) vB2 v0
        vResolved = Sync.resolve (env 100 10000) vB1 vB2WithEnv
      in
      Expect.equal "Value 1 from network" <| Sync.value vResolved

  , test "Resolving the same everything should yield original" <|
    \_ ->
      let
        v0 = syncWithStep "Original value......." 0
        vB1 = syncWithStep "Value 1 from network" 9
        vB2 = syncWithStep "Value 2 from network" 9
        vB1WithEnv = Sync.resolve (env 100 10000) vB1 v0
        vResolved = Sync.resolve (env 100 10000) vB2 vB1WithEnv
      in
      Expect.equal "Value 1 from network" <| Sync.value vResolved

  ]


encodeDecode : Sync String -> Result Dec.Error (Sync String)
encodeDecode ss =
  ss
  |> Sync.encode Enc.string
  |> Enc.encode 0
  |> Dec.decodeString (Sync.decoder Dec.string)


envCompareTest : Test
envCompareTest =
  let
    earlyNum = 100
    sameNum = 150
    lateNum = 200
    earlyTime = 10000
    sameTime = 15000
    lateTime = 20000
    try (num1, time1) (num2, time2) expected description =
      test description <|
        \_ ->
          Sync.envCompare (env num1 time1) (env num2 time2)
          |> Expect.equal expected
  in
  describe "envCompare test"
  -- For these three, it's early time vs late time
  [ "Early num + early time vs late num + late time"
    |> try (earlyNum, earlyTime) (lateNum, lateTime) LT

  , "Late num + early time vs early num + late time"
    |> try (lateNum, earlyTime) (earlyNum, lateTime) LT

  , "Same num + early time vs Same num + late time"
    |> try (sameNum, earlyTime) (sameNum, lateTime) LT

  -- For these three, it's late time vs early time
  , "Early num + late time vs late num + early time"
    |> try (earlyNum, lateTime) (lateNum, earlyTime) GT

  , "Late num + late time vs early num + early time"
    |> try (lateNum, lateTime) (earlyNum, earlyTime) GT

  , "Same num + late time vs Same num + early time"
    |> try (sameNum, lateTime) (sameNum, earlyTime) GT


  -- For these three, it's same time vs same time
  , "Early num + same time vs late num + same time"
    |> try (earlyNum, sameTime) (lateNum, sameTime) LT

  , "Late num + same time vs early num + same time"
    |> try (lateNum, sameTime) (earlyNum, sameTime) GT

  , "Same num + same time vs Same num + same time"
    |> try (sameNum, sameTime) (sameNum, sameTime) EQ

  ]


-- Create an envelope with a given env num and a time.
env : Int -> Int -> BGF.Envelope ()
env num time =
  BGF.Peer
    { from = "dummy.client.id"
    , to = ["c1", "c2", "c3"]
    , num = num
    , time = time
    , body = ()
    }


syncWithStep : a -> Int -> Sync a
syncWithStep val step =
  let
    sync0 = Sync.zero val
    incStep state s1 =
      Sync.mapToNext identity s1
  in
  List.foldl incStep sync0 (List.repeat step val)
