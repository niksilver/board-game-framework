-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework.Lobby exposing (
  Lobby, Config, Msg, newDraftGameId, urlChanged, lobby
  , update
  , urlString, draftGameId, okGameId
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
    { stateMaker : BGF.GameId -> s
    , openCmd : BGF.GameId -> Cmd msg
    , msgWrapper : Msg -> msg
    , url : Url.Url
    , key : Nav.Key
    , draftGameId : String
    }


{-| How the lobby interoperates with the main app. We need:
* A way to generate an initial game state, given a game ID;
* A function to generate the `Open` command to the server, given a game ID;
* How to wrap a lobby msg into an application-specific message (which
  we can catch at the top level of our application and then pass into the
  lobby).
-}
type alias Config msg s =
  { stateMaker : BGF.GameId -> s
  , openCmd : BGF.GameId -> Cmd msg
  , msgWrapper : Msg -> msg
  }


{-| A message to update the model of the lobby.
-}
type Msg =
  Init
  | UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraftGameId String


newDraftGameId : Lobby msg s -> String -> msg
newDraftGameId (Lobby lob) draft =
  lob.msgWrapper <| NewDraftGameId draft


urlChanged : (Msg -> msg) -> Url.Url -> msg
urlChanged msgWrapper url =
  msgWrapper <| UrlChanged url


{-| Create a lobby.
-}
lobby : Config msg s -> Url.Url -> Nav.Key -> (Lobby msg s, Maybe s, Cmd msg)
lobby config url key =
  Lobby
    { stateMaker = config.stateMaker
    , openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    , url = url
    , key = key
    , draftGameId = ""
    }
  |> update Init


update : Msg -> Lobby msg s -> (Lobby msg s, Maybe s, Cmd msg)
update msg (Lobby lob) =
  case msg of
    Init ->
      case lob.url.fragment of
        Nothing ->
          ( Lobby lob
          , Nothing
          , Random.generate GeneratedGameId BGF.idGenerator
            |> Cmd.map lob.msgWrapper
          )

        Just frag ->
          case BGF.gameId frag of
            Ok gameId ->
              ( Lobby lob
              , Just <| lob.stateMaker gameId
              , lob.openCmd gameId
              )

            Err _ ->
              ( Lobby { lob | draftGameId = frag }
              , Nothing
              , Cmd.none
              )

    UrlChanged url ->
      Lobby { lob | url = url }
      |> update Init

    GeneratedGameId gameId ->
      ( Lobby
          { lob
          | draftGameId = gameId |> BGF.fromGameId
          }
      , Nothing
      , Cmd.none
      )

    NewDraftGameId draft ->
      ( Lobby
          { lob
          | draftGameId = draft
          }
      , Nothing
      , Cmd.none
      )


urlString : Lobby msg s -> String
urlString (Lobby lob) =
  lob.url |> Url.toString


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
