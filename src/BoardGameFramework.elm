-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  idGenerator, isGoodGameID, isGoodGameIDMaybe, goodGameID, goodGameIDMaybe
  , Envelope(..), Request(..), encode, decodeEnvelope
  )

{-| Types and functions help create remote multiplayer board games
using the related framework. See
[https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)
for detailed documentation and example code.

# Lobby
Enable players to gather and find a unique game ID
in preparation for starting a game.
@docs idGenerator, isGoodGameID, isGoodGameIDMaybe, goodGameID, goodGameIDMaybe

# Communication
Sending to and receiving from other players.
@docs Envelope, Request, encode
-}


import String
import Random
import Json.Encode as Enc
import Json.Decode as Dec
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


isGoodGameIDMaybe : Maybe String -> Bool
isGoodGameIDMaybe mID =
  case mID of
    Nothing -> False

    Just id -> isGoodGameID id


isGoodGameID : String -> Bool
isGoodGameID id =
  (String.length id >= 5) &&
    String.all (\c -> Char.isAlphaNum c || c == '-' || c == '.') id


goodGameID : String -> Maybe String
goodGameID id =
  if isGoodGameID id then
    Just id
  else
    Nothing


goodGameIDMaybe : Maybe String -> Maybe String
goodGameIDMaybe mID =
  case mID of
    Just id -> goodGameID id

    Nothing -> Nothing


type Envelope =
  Welcome {me: String, others: List String, time: Int}


meDecoder : Dec.Decoder String
meDecoder = Dec.field "To" Dec.string


decodeEnvelope : Enc.Value -> Result String Envelope
decodeEnvelope v =
  case Dec.decodeValue (Dec.field "Intent" Dec.string) v of
    Ok "Welcome" ->
      Ok <| Welcome {me = "", others = [], time = 0}

    _ ->
      Err "Didn't find Welcome intent"


type Request =
  Open String
--  | Send Body
--  | Close


encode : Request -> Enc.Value
encode req =
  case req of
    Open url ->
      Enc.object
        [ ("instruction", Enc.string "Open")
        , ("url", url |> Enc.string)
        ]

{-    Send body ->
      Enc.object
        [ ("instruction", Enc.string "Send")
        , ("body"
          , Enc.object
            [ ("words", Enc.string body.draftWords)
            , ("truth", Enc.bool body.draftTruth)
            , ("wholenumber", Enc.int body.draftWholeNumber)
            ]
          )
        ]

    Close ->
      Enc.object
        [ ("instruction", Enc.string "Close")
        ]
-}
