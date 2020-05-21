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


type Envelope =
  Welcome {me: String, others: List String, time: Int}


-- Singleton list decoder part 1
-- Confirms if a list is a singleton
singleton : List a -> Maybe a
singleton lst =
  case List.head lst of
    Just elt ->
      if List.length lst == 1 then
        Just elt
      else
        Nothing

    Nothing ->
      Nothing


-- Singleton list decoder part 2
-- Takes a list and produces a just-singleton
maybeSingletonDecoder : Dec.Decoder (Maybe String)
maybeSingletonDecoder =
  Dec.map singleton (Dec.list Dec.string)


-- Singleton list decoder part 3
-- Produce a decoder that outputs a string, if it's a Just string
justStringDecoder : Maybe String -> Dec.Decoder String
justStringDecoder ms =
  case ms of
    Just s -> Dec.succeed s
    Nothing -> Dec.fail "Not a singleton string list"


-- Singleton list decoder part 4 and final
-- Expect a singleton string list, and output the value
singletonStringDecoder : Dec.Decoder String
singletonStringDecoder =
  maybeSingletonDecoder
  |> Dec.andThen justStringDecoder


decodeEnvelope : Enc.Value -> Result String Envelope
decodeEnvelope v =
  let
    toRes = Dec.decodeValue (Dec.field "To" singletonStringDecoder) v
    fromRes = Dec.decodeValue (Dec.field "From" (Dec.list Dec.string)) v
    timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
    intentRes = Dec.decodeValue (Dec.field "Intent" Dec.string) v
  in
  case intentRes of
    Ok "Welcome" ->
      let
        make to from time =
          Welcome
          { me = to
          , others = from
          , time = time
          }
      in
        Result.map3 make toRes fromRes timeRes
        |> Result.mapError Dec.errorToString

    _ ->
      Err "Didn't find Welcome intent"


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
