-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  idGenerator, isGoodGameId, isGoodGameIdMaybe, goodGameId, goodGameIdMaybe
  , Envelope(..), Request(..), encode, decodeEnvelope
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
@docs Envelope, Request, encode
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
  Welcome {me: String, others: List String, time: Int}
  | Peer {from: String, to: List String, time: Int, body: a}
  | Joiner {joiner: String, to: List String, time: Int}


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


decodeEnvelope : Dec.Decoder a -> Enc.Value -> Result String (Envelope a)
decodeEnvelope bodyDecoder v =
  let
    timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
    intentRes = Dec.decodeValue (Dec.field "Intent" Dec.string) v
  in
  case intentRes of
    Ok "Welcome" ->
      let
        toRes = Dec.decodeValue (Dec.field "To" singletonStringDecoder) v
        fromRes = Dec.decodeValue (Dec.field "From" (Dec.list Dec.string)) v
        make to from time =
          Welcome
          { me = to
          , others = from
          , time = time
          }
      in
        Result.map3 make toRes fromRes timeRes
        |> Result.mapError Dec.errorToString

    Ok "Peer" ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        bodyRes = Dec.decodeValue (Dec.field "Body" bodyDecoder) v
        make to from time body =
          Peer
          { from = from
          , to = to
          , time = time
          , body = body
          }
      in
        Result.map4 make toRes fromRes timeRes bodyRes
        |> Result.mapError Dec.errorToString

    Ok "Joiner" ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        make to from time =
          Joiner
          { joiner = from
          , to = to
          , time = time
          }
      in
        Result.map3 make toRes fromRes timeRes
        |> Result.mapError Dec.errorToString

    Ok intent ->
      Err <| "Got unknown intent: '" ++ intent ++ "'"

    Err desc ->
      Err <| "Error decoding envelope: " ++ (Dec.errorToString desc)


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
