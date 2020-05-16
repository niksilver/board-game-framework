-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (idGenerator)

{-| Types and functions help create remote multiplayer board games
using the related framework. See
[https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)
for detailed documentation and example code.

# Lobby
Functions for enabling players gather in a unique lobby in preparation
for starting a game.
@docs idGenerator
-}


import String
import Random


-- Words for the game ID
words : List String
words =
  [ "aarvark"
  , "abbey"
  , "battle"
  , "cucumber"
  , "zebra"
  ]


{-| A random name generator for game IDs, which will be of the form
"_word_-_word_-_word_".
-}
idGenerator : Random.Generator String
idGenerator =
  case words of
    head :: tail ->
      Random.uniform head tail
      |> Random.list 3
      |> Random.map (\w -> String.join "-" w)

    _ ->
      Random.constant "xxx"
