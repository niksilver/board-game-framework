-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  idGenerator, isGoodGameId, isGoodGameIdMaybe, goodGameId, goodGameIdMaybe
  , Envelope(..), Connectivity(..), Error(..), Request(..)
  , encode, decodeEnvelope
  )

{-| Types and functions help create remote multiplayer board games
using the related framework. See
[https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)
for detailed documentation and example code.

# Lobby
Enable players to gather and find a unique game ID
in preparation for starting a game.
@docs idGenerator, isGoodGameId, isGoodGameIdMaybe, goodGameId, goodGameIdMaybe

# Communication
Sending to and receiving from other players.
@docs Envelope, Connectivity, Error, Request, encode, decodeEnvelope
-}


import String
import Random
import Json.Encode as Enc
import Json.Decode as Dec
import Result
import Url exposing (Url)

import Words


{-| A random name generator for game IDs, which will be of the form
"_word_-_word_-_word_".
-}
idGenerator : Random.Generator String
idGenerator =
  case Words.words of
    head :: tail ->
      Random.uniform head tail
      |> Random.list 3
      |> Random.map (\w -> String.join "-" w)

    _ ->
      Random.constant "xxx"


isGoodGameIdMaybe : Maybe String -> Bool
isGoodGameIdMaybe mId =
  case mId of
    Nothing -> False

    Just id -> isGoodGameId id


isGoodGameId : String -> Bool
isGoodGameId id =
  (String.length id >= 5) &&
    String.all (\c -> Char.isAlphaNum c || c == '-' || c == '.') id


goodGameId : String -> Maybe String
goodGameId id =
  if isGoodGameId id then
    Just id
  else
    Nothing


goodGameIdMaybe : Maybe String -> Maybe String
goodGameIdMaybe mId =
  case mId of
    Just id -> goodGameId id

    Nothing -> Nothing


type Envelope a =
  Welcome {me: String, others: List String, num: Int, time: Int}
  | Peer {from: String, to: List String, num: Int, time: Int, body: a}
  | Receipt {from: String, to: List String, num: Int, time: Int, body: a}
  | Joiner {joiner: String, to: List String, num: Int, time: Int}
  | Leaver {leaver: String, to: List String, num: Int, time: Int}
  | Connection Connectivity


type Connectivity =
  Opened
  | Connecting
  | Closed


{-| Errors reading the incoming envelope. If an error bubbles up from
the connection library, or if the envelope intent is something unexpected,
that's a `LowLevel` error. If we can't decode
the JSON with the given decoder, that's a `Json` error, with the
specific error coming from the `Json.Decode` package.
-}
type Error =
  LowLevel String
  | Json Dec.Error


-- Singleton string list decoder.
-- Expect a singleton string list, and output the value
singletonStringDecoder : Dec.Decoder String
singletonStringDecoder =
  let
    singleDecoder list = case list of
      [elt] -> Dec.succeed elt
      _ -> Dec.fail "Didn't get string singleton"
  in
  Dec.list Dec.string
  |> Dec.andThen singleDecoder


{-| Decode an incoming envelope.

In this example we expect our envelope body to be a JSON object
containing a `"players"` field (which is a map of strings to strings)
and an `"entered"` field (which is a boolean).

    import Dict exposing (Dict)
    import Json.Decode as Dec
    import Json.Encode as Enc
    import BoardGameFramework as BGF


    type alias Body =
      { players : Dict String String
      , entered : Bool
      }


    type alias Envelope = BGF.Envelope Body


    bodyDecoder : Dec.Decoder Body
    bodyDecoder =
      let
        playersDec =
          Dec.field "players" (Dec.dict Dec.string)
        enteredDec =
          Dec.field "entered" Dec.bool
      in
        Dec.map2 Body
          playersDec
          enteredDec


    result : Enc.value -> Result BGF.Error Envelope
    result v =
      BGF.decodeEnvelope bodyDecoder v
-}
decodeEnvelope : Dec.Decoder a -> Enc.Value -> Result Error (Envelope a)
decodeEnvelope bodyDecoder v =
  let
    stringFieldDec field =
      Dec.field field Dec.string
      |> Dec.map (\val -> (field, val))
    intentDec = stringFieldDec "Intent"
    connectionDec = stringFieldDec "connection"
    errorDec = stringFieldDec "error"
    purposeDec = Dec.oneOf [intentDec, connectionDec, errorDec]
    purpose = Dec.decodeValue purposeDec v
  in
  case purpose of
    Ok ("Intent", "Welcome") ->
      let
        toRes = Dec.decodeValue (Dec.field "To" singletonStringDecoder) v
        fromRes = Dec.decodeValue (Dec.field "From" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        make to from num time =
          Welcome
          { me = to
          , others = from
          , num = num
          , time = time
          }
      in
        Result.map4 make toRes fromRes numRes timeRes
        |> Result.mapError Json

    Ok ("Intent", "Peer") ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        bodyRes = Dec.decodeValue (Dec.field "Body" bodyDecoder) v
        make to from num time body =
          Peer
          { from = from
          , to = to
          , num = num
          , time = time
          , body = body
          }
      in
        Result.map5 make toRes fromRes numRes timeRes bodyRes
        |> Result.mapError Json

    Ok ("Intent", "Receipt") ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        bodyRes = Dec.decodeValue (Dec.field "Body" bodyDecoder) v
        make to from num time body =
          Receipt
          { from = from
          , to = to
          , num = num
          , time = time
          , body = body
          }
      in
        Result.map5 make toRes fromRes numRes timeRes bodyRes
        |> Result.mapError Json

    Ok ("Intent", "Joiner") ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        make to from num time =
          Joiner
          { joiner = from
          , to = to
          , num = num
          , time = time
          }
      in
        Result.map4 make toRes fromRes numRes timeRes
        |> Result.mapError Json

    Ok ("Intent", "Leaver") ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        make to from num time =
          Leaver
          { leaver = from
          , to = to
          , num = num
          , time = time
          }
      in
        Result.map4 make toRes fromRes numRes timeRes
        |> Result.mapError Json

    Ok ("connection", "opened") ->
      Ok (Connection Opened)

    Ok ("connection", "connecting") ->
      Ok (Connection Connecting)

    Ok ("connection", "closed") ->
      Ok (Connection Closed)

    Ok ("error", str) ->
      Err (LowLevel str)

    Ok (field, val) ->
      Err (LowLevel <| "Unrecognised " ++ field ++ ": '" ++ val ++ "'")

    Err desc ->
      Err (Json desc)


{-| Request to be sent through a port.
Open a connection to a game, send a message, or close the connection.
-}
type Request a =
  Open String
  | Send a
--  | Close


encode : (a -> Enc.Value) -> Request a -> Enc.Value
encode encoder req =
  case req of
    Open url ->
      Enc.object
        [ ("instruction", Enc.string "Open")
        , ("url", url |> Enc.string)
        ]

    Send body ->
      Enc.object
        [ ("instruction", Enc.string "Send")
        , ("body", encoder body )
        ]

{-    Close ->
      Enc.object
        [ ("instruction", Enc.string "Close")
        ]
-}
