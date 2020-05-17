-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  idGenerator, addGameID, lastSegment, isGoodGameID, isGoodGameIDMaybe
  )

{-| Types and functions help create remote multiplayer board games
using the related framework. See
[https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)
for detailed documentation and example code.

# Lobby
Functions for enabling players to gather and find a unique game ID
in preparation for starting a game.
@docs idGenerator, addGameID, lastSegment
-}


import String
import Random
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


{-| Given a Url, return the same Url but with the given game ID appended.

    -- For Url u "http://example.com/mygame"
    addGameID u "aa-bb-cc"    ==>    "http://example.com/mygame/aa-bb-cc"

    -- For Url u "http://example.com/mygame/"
    addGameID u "aa-bb-cc"    ==>    "http://example.com/mygame/aa-bb-cc"

    -- For Url u "http://example.com/"
    addGameID u "aa-bb-cc"    ==>    "http://example.com/aa-bb-cc"
-}
addGameID : Url -> String -> Url
addGameID url id =
  let
    extra =
      if String.endsWith "/" url.path || String.isEmpty url.path then
        id
      else
        "/" ++ id
  in
    { url | path = url.path ++ extra }


{-| Get the last segment of a Url path. Useful if that contains the game ID.
Will return the last string of the path up to and excluding a `/`.

    -- For Url u "http://example.com/mygame/something"
    lastSegment u    ==>    Just "something"

    -- For Url u "http://example.com/mygame/something#else"
    lastSegment u    ==>    Just "something"

    -- For Url u "http://example.com/mygame"
    lastSegment u    ==>    Just "mygame"

    -- For Url u "http://example.com/mygame/"
    lastSegment u    ==>    Nothing

    -- For Url u "http://example.com/"
    lastSegment u    ==>    Nothing
-}
lastSegment : Url -> Maybe String
lastSegment url =
  let
    is = String.indexes "/" url.path
    mIdx = List.reverse is |> List.head
  in
  case mIdx of
    Nothing ->
      Nothing

    Just idx ->
      let
        id = String.dropLeft (idx+1) url.path
      in
        if id == "" then
          Nothing
        else
         Just id
 

isGoodGameIDMaybe : Maybe String -> Bool
isGoodGameIDMaybe mID =
  case mID of
    Nothing -> False

    Just id -> isGoodGameID id


isGoodGameID : String -> Bool
isGoodGameID id =
  (String.length id >= 5) &&
    String.all (\c -> Char.isAlphaNum c || c == '-' || c == '.') id

