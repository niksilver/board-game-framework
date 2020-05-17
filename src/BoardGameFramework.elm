-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  idGenerator, isGoodGameID, isGoodGameIDMaybe
  )

{-| Types and functions help create remote multiplayer board games
using the related framework. See
[https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)
for detailed documentation and example code.

# Game IDs
Functions for enabling players to gather and find a unique game ID
in preparation for starting a game.
@docs idGenerator, isGoodGameID, isGoodGameIDMaybe
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


isGoodGameIDMaybe : Maybe String -> Bool
isGoodGameIDMaybe mID =
  case mID of
    Nothing -> False

    Just id -> isGoodGameID id


isGoodGameID : String -> Bool
isGoodGameID id =
  (String.length id >= 5) &&
    String.all (\c -> Char.isAlphaNum c || c == '-' || c == '.') id

