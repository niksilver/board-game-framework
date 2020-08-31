module SyncTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Json.Encode as Enc
import Json.Decode as Dec

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
