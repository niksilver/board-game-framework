-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  idGenerator, addGameID
  )

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
import Url exposing (Url)


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