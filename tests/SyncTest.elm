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
        myDecoder = Sync.decoder Dec.string
        myEncode = Sync.encode Enc.string
        mySyncedValue = Sync.zero "My value"
      in
        mySyncedValue
        |> myEncode
        |> Enc.encode 0
        |> Dec.decodeString myDecoder
        |> \result ->
          case result of
            Ok syncedVal ->
              syncedVal
              |> Sync.value
              |> Expect.equal "My value"

            Err decError ->
              Expect.fail <| "Bad decoder result: " ++ (Dec.errorToString decError)


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
  [ "Early num + early time vs late num + late time"
    |> try (earlyNum, earlyTime) (lateNum, lateTime) LT

  ]

env : Int -> Int -> BGF.Envelope ()
env num time =
  BGF.Peer
    { from = "dummy.client.id"
    , to = ["c1", "c2", "c3"]
    , num = num
    , time = time
    , body = ()
    }
