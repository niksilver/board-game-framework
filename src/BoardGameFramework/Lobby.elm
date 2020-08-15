-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework.Lobby exposing (
  Lobby, Msg, newDraftGameId, Entry(..), lobby
  , enter, update
  , draftGameId, okGameId
  )


{-| Managing the lobby - selecting the game ID and the player name.
-}


import Browser.Navigation as Nav
import Random
import Url

import BoardGameFramework as BGF


{-| The state of the lobby. We can leave the lobby when we have a valid
game ID, and (optionally) a valid player name.
-}
type Lobby msg s =
  Lobby
    { draftGameId : String
    , stateMaker : BGF.GameId -> s
    , openCmd : BGF.GameId -> Cmd msg
    , msgWrapper : Msg -> msg
    }


{-| A message to update the model of the lobby.
-}
type Msg =
  GeneratedGameId BGF.GameId
  | NewDraftGameId String


newDraftGameId : Lobby msg s -> String -> msg
newDraftGameId (Lobby lob) draft =
  lob.msgWrapper <| NewDraftGameId draft


{-| Whether we are in the lobby, or are just out of the lobby and starting
a new game.
-}
type Entry msg s =
  In (Lobby msg s)
  | Out s


{-| To manage a lobby we need:
* A way to generate an initial game state, given a game ID;
* A function to generate the `Open` command to the server, given a game ID;
* How to wrap a lobby msg into an application-specific message (which will
  then be passed into the lobby).
-}
lobby :
  { stateMaker : BGF.GameId -> s
  , openCmd : BGF.GameId -> Cmd msg
  , msgWrapper : Msg -> msg
  } -> Lobby msg s
lobby config =
  Lobby
    { draftGameId = ""
    , stateMaker = config.stateMaker
    , openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    }


enter : Lobby msg s -> Url.Url -> (Entry msg s, Cmd msg)
enter (Lobby lob) url =
  let
    frag = url.fragment |> Maybe.withDefault ""
  in
  case BGF.gameId frag of
    Ok gameId ->
      ( Out <| lob.stateMaker gameId
      , lob.openCmd gameId
      )

    Err _ ->
      case url.fragment of
        Just str ->
          ( In <| Lobby { lob | draftGameId = frag }
          , Cmd.none
          )

        Nothing ->
          ( In <| Lobby { lob | draftGameId = frag }
          , Random.generate GeneratedGameId BGF.idGenerator
            |> Cmd.map lob.msgWrapper
          )


update : Msg -> Lobby msg s -> (Lobby msg s, Cmd msg)
update msg (Lobby lob) =
  case msg of
    GeneratedGameId gameId ->
      ( Lobby
          { lob
          | draftGameId = gameId |> BGF.fromGameId
          }
      , Cmd.none
      )

    NewDraftGameId draft ->
      ( Lobby
          { lob
          | draftGameId = draft
          }
      , Cmd.none
      )


draftGameId : Lobby msg s -> String
draftGameId (Lobby lob) =
  lob.draftGameId


okGameId : Lobby msg s -> Bool
okGameId (Lobby lob) =
  case lob.draftGameId |> BGF.gameId of
    Ok _ ->
      True

    Err _ ->
      False
