-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework exposing (idGenerator)


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


-- A random name generator for game IDs
idGenerator : Random.Generator String
idGenerator =
  case words of
    head :: tail ->
      Random.uniform head tail
      |> Random.list 3
      |> Random.map (\w -> String.join "-" w)

    _ ->
      Random.constant "xxx"
