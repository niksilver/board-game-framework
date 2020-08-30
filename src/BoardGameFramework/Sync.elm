-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Sync exposing
  -- Basics
  ( Sync, zero, assume, data
  -- Transforming
  , mapToNext
  -- Encoding and decoding
  , encoder, decoder
  )


import Json.Encode as Enc
import Json.Decode as Dec


-- Basics


type Sync a =
  Sync
    { moveNumber : Int
    , envNum : Maybe Int
    , value : a
    }


-- Zero a sync point
zero : a -> Sync a
zero val =
  Sync
    { moveNumber = 0
    , envNum = Nothing
    , value = val
    }


-- Assume a new data value as the next step, but recognise that this is yet
-- to be confirmed.
assume : a -> Sync a -> Sync a
assume val (Sync rec) =
  Sync
    { moveNumber = rec.moveNumber + 1
    , envNum = Nothing
    , value = val
    }


-- Return just the data value from the synchronisation point
data : Sync a -> a
data (Sync rec) =
  rec.value


-- Transforming


-- Set the next step of the data value with a mapping function.
-- The new value will not yet be verified.
mapToNext : (a -> a) -> Sync a -> Sync a
mapToNext fn (Sync rec) =
  Sync
    { moveNumber = rec.moveNumber +1
    , envNum = Nothing
    , value = fn rec.value
    }


-- Encoding and decoding


-- Encode a synced data value for sending to another client
encoder : (a -> Enc.Value) -> Sync a -> Enc.Value
encoder enc (Sync rec) =
  Enc.object
    [ ( "moveNumber", Enc.int rec.moveNumber )
    , ( "envNum", maybeEncoder Enc.int rec.envNum )
    , ( "data", enc rec.value)
    ]


-- Decode a synced data value received from another client
decoder : (Dec.Decoder a) -> Dec.Decoder (Sync a)
decoder dec =
  Dec.map3
    (\mn en val ->
      Sync { moveNumber = mn, envNum = en, value = val}
    )
    (Dec.field "moveNumber" Dec.int)
    (Dec.field "envNum" (maybeDecoder Dec.int))
    (Dec.field "data" dec)


-- Encodes Nothing to [], and Just x to [x]
maybeEncoder : (a -> Enc.Value) -> Maybe a -> Enc.Value
maybeEncoder enc ma =
  case ma of
    Nothing ->
      Enc.list enc []

    Just x ->
      Enc.list enc [x]


-- Decodes [] to Nothing and [x] to Just x
maybeDecoder : Dec.Decoder a -> Dec.Decoder (Maybe a)
maybeDecoder dec =
  let
    innerDec list =
      case list of
        [] ->
          Dec.succeed Nothing

        head :: _ ->
          Dec.succeed (Just head)
  in
  Dec.list dec
  |> Dec.andThen innerDec
