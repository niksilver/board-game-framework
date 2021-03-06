-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Sync exposing
  -- Basics
  ( Sync, zero, value
  -- Modifying
  , set, mapToNext, resolve
  -- Encoding and decoding
  , encode, decoder
  -- Utilities
  , envCompare
  )


{-| Sometimes we don't just want to send values between peers, but
we also want to synchronise them.

The problem: Suppose we want to send the updated state of the board as a value
between peers, and our game allows any client to do this.
What happens when two clients send different updates simultaneously?
How do we know which value is the "correct" one?

The solution:
When we set our initial value (e.g. the initial state of the game)
we count that as "step 0". Each subsequent change is step 1, step 2,
etc. But whenever we set our own value we must recognised that it's
not yet verified. We must also send it to our peers via the server.
They will be doing the same thing. Whenever we receive a value
(as a Peer envelope sent by any other client or by us) we must
resolve it against what we currently hold. Whichever value came
through first from the server is verified as the accepted value for that step.

So the general procedure is:
create an initial value as our [`zero`](#zero) step,
calculate each subsequent step as the game progresses,
and always send to our peers any value we've calculated.
At the same time we receive values,
and [`resolve`](#resolve) any received value with our current value.

# Basics
@docs Sync, zero, value

# Modifying
@docs set, mapToNext, resolve

# Encoding and decoding
@docs encode, decoder

# Utilities
@docs envCompare
-}


import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF


-- Basics


type Timing =
  SomeTiming { num : Int, time : Int }
  | NoTiming


{-| Some value which can be synchronised, and resolved against other
values. This data structure carries not only the value itself, but
also extra information so it can be resolved against other values.
-}
type Sync a =
  Sync
    { step : Int
    , timing : Timing
    , value : a
    }


{-| Set an initial value with step `0`, which is known not to have come
via the server (i.e. not verified).

In a game of hangman, where we're trying to find a seven letter word,
we might set the initial value like this:

    initialWord : Sync String
    initialWord = Sync.zero "-------"
-}
zero : a -> Sync a
zero val =
  Sync
    { step = 0
    , timing = NoTiming
    , value = val
    }


{-| Get the value carried.
-}
value : Sync a -> a
value (Sync rec) =
  rec.value


-- Modifying


{-| Set a new value as the next step.
The new value is not yet verified.
-}
set : a -> Sync a -> Sync a
set val (Sync rec) =
  Sync
    { step = rec.step + 1
    , timing = NoTiming
    , value = val
    }


{-| Set a new value as the next step, using a mapping function.
The new value is not yet verified.

In a hangman game, if the state is a string, and the next
state is found by revealing one of its letters
using some function `reveal : Int -> String -> String`,
then we might have

    import BoardGameFramework.Sync as Sync exposing (Sync)

    next : Int -> Sync String -> Sync String
    next i state =
      Sync.mapToNext (reveal i) state
-}
mapToNext : (a -> a) -> Sync a -> Sync a
mapToNext fn (Sync rec) =
  Sync
    { step = rec.step + 1
    , timing = NoTiming
    , value = fn rec.value
    }


{-| Resolve which of two values should be considered the correct one.
The function takes the envelope that contained the new value, the new value,
and the current value.

    Sync.resolve newEnv newSyncedValue origSyncedValue

The result is whichever value is the later step; if they represent the
same step then the one from the earlier envelope is preferred; if that
is still the same then the original value is returned.
This way will always, get the latest step in the game, and if two clients
provided different values for the same step then we get whichever of
those was received first.
-}
resolve : BGF.Envelope b -> Sync a -> Sync a -> Sync a
resolve env (Sync recNew) (Sync recOrig) =
  let
    recNew2 = { recNew | timing = timing env }
  in
  case compare recOrig.step recNew2.step of
    LT ->
      Sync recNew2

    GT ->
      Sync recOrig

    EQ ->
      case timingCompare recOrig.timing recNew2.timing of
        LT ->
          Sync recOrig

        GT ->
          Sync recNew2

        EQ ->
          Sync recOrig


-- Encoding and decoding


{-| Encode a synced value for sending to other clients.
You need to supply an encoder for the value.

In a game of hangman, where we're trying to find a word (a `String`),
and we want to synchronise that,
we might create our encode function like this:

    import Json.Encode as Enc
    import BoardGameFramework.Sync as Sync

    encodeWord : Sync String -> Enc.Value
    encodeWord =
      Sync.encode Enc.string
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


{-| Create a decoder for a synced value received from another client.
You need to supply an decoder for the value.

In a game of hangman, where we're trying to find a word (a `String`),
and we want to synchronise that,
we might create our decoder like this:

    import Json.Decode as Dec
    import BoardGameFramework.Sync as Sync

    wordDecoder : Dec.Decoder (Sync String)
    wordDecoder =
      Sync.decoder Dec.string
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

    BGF.Peer rec ->
      SomeTiming { num = rec.num, time = rec.time }

    BGF.Leaver rec ->
      SomeTiming { num = rec.num, time = rec.time }

    BGF.Connection _ ->
      NoTiming

    BGF.Error _ ->
      NoTiming


{-| Compare the order of two envelopes. An earlier envelope is `LT`
a later envelope.

`Connection` and `Error` envelopes have no order information,
so these are considered as late as possible.

    env1 = ...            -- First Welcome envelope received
    env2 = ...            -- Some Receipt received after sending something
    envX = ...            -- Some Connection envelope
    envCompare env1 env2  -- LT
    envCompare env2 env1  -- GT
    envCompare env1 env1  -- EQ
    envCompare envX env1  -- GT
-}
envCompare : BGF.Envelope b -> BGF.Envelope b -> Order
envCompare env1 env2 =
  let
    timing1 = timing env1
    timing2 = timing env2
  in
  timingCompare timing1 timing2


timingCompare : Timing -> Timing -> Order
timingCompare timing1 timing2 =
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
