-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Sync exposing
  -- Basics
  ( Sync, zero, assume, value
  -- Transforming
  , mapToNext, resolve
  -- Encoding and decoding
  , encode, decoder
  -- Utilities
  , envCompare
  )


import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF


-- Basics


type Timing =
  SomeTiming { num : Int, time : Int }
  | NoTiming


type Sync a =
  Sync
    { step : Int
    , timing : Timing
    , value : a
    }


-- Zero a sync point
zero : a -> Sync a
zero val =
  Sync
    { step = 0
    , timing = NoTiming
    , value = val
    }


-- Assume a new data value as the next step, but recognise that this is yet
-- to be confirmed.
assume : a -> Sync a -> Sync a
assume val (Sync rec) =
  Sync
    { step = rec.step + 1
    , timing = NoTiming
    , value = val
    }


-- Return just the data value from the synchronisation point
value : Sync a -> a
value (Sync rec) =
  rec.value


-- Transforming


-- Set the next step of the data value with a mapping function.
-- The new value will not yet be verified.
mapToNext : (a -> a) -> Sync a -> Sync a
mapToNext fn (Sync rec) =
  Sync
    { step = rec.step + 1
    , timing = NoTiming
    , value = fn rec.value
    }


{-| Resolve which of two values should be considered the correct one.
-}
resolve : BGF.Envelope b -> Sync a -> Sync a -> Sync a
resolve env (Sync recNew) (Sync recOrig) =
  let
    recNew2 = { recNew | timing = timing env }
  in
  (Sync recOrig) |> Debug.log "TO be implemented!"


-- Encoding and decoding


{-| Encode a synced data value for sending to another client.
You need to supply an encoder for the data value.
-}
encode : (a -> Enc.Value) -> Sync a -> Enc.Value
encode enc (Sync rec) =
  Enc.object
    [ ( "step", Enc.int rec.step )
    , ( "timing", encodeTiming rec.timing )
    , ( "data", enc rec.value)
    ]


encodeTiming : Timing -> Enc.Value
encodeTiming t =
  case t of
    SomeTiming rec ->
      Enc.list Enc.int [ rec.num, rec.time ]

    NoTiming ->
      Enc.list Enc.int []


{-| Decode a synced data value received from another client
You need to supply an decoder for the data value.
-}
decoder : (Dec.Decoder a) -> Dec.Decoder (Sync a)
decoder dec =
  Dec.map3
    (\mn en val ->
      Sync { step = mn, timing = en, value = val}
    )
    (Dec.field "step" Dec.int)
    (Dec.field "timing" timingDecoder)
    (Dec.field "data" dec)


timingDecoder : Dec.Decoder Timing
timingDecoder =
  let
    listHelp list =
      case list of
        [] ->
          Dec.succeed NoTiming

        _ :: [] ->
          Dec.fail "Timing encoded as one list item only"

        num :: time :: [] ->
          Dec.succeed (SomeTiming { num = num, time = time })

        _ ->
          Dec.fail "Timing encoded as list with more than two items"
  in
  Dec.list Dec.int
  |> Dec.andThen listHelp


{-- -- Encodes Nothing to [], and Just x to [x]
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
  |> Dec.andThen innerDec--}


-- Utilities


timing : BGF.Envelope b -> Timing
timing env =
  case env of
    BGF.Welcome rec ->
      SomeTiming { num = rec.num, time = rec.time }

    BGF.Joiner rec ->
      SomeTiming { num = rec.num, time = rec.time }

    BGF.Receipt rec ->
      SomeTiming { num = rec.num, time = rec.time }

    BGF.Peer rec ->
      SomeTiming { num = rec.num, time = rec.time }

    BGF.Leaver rec ->
      SomeTiming { num = rec.num, time = rec.time }

    BGF.Connection _ ->
      NoTiming


{-| Compare the order of two envelopes. A `Connection`
envelope has no order information, so is considered as late as possible.
So if one envelope is a `Connection` envelope then the other is considered
"before" it... unless they're both `Connection` envelopes, in which case
they're equal.
-}
envCompare : BGF.Envelope b -> BGF.Envelope b -> Order
envCompare env1 env2 =
  let
    timing1 = timing env1
    timing2 = timing env2
  in
  case (timing1, timing2) of
    (NoTiming, NoTiming) ->
      EQ

    (NoTiming, SomeTiming _) ->
      GT

    (SomeTiming _, NoTiming) ->
      LT

    (SomeTiming rec1, SomeTiming rec2) ->
      case compare rec1.time rec2.time of
        EQ ->
          compare rec1.num rec2.num

        nonEqual ->
          nonEqual
