-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework.Lobby exposing (
  Lobby, Config, Msg, lobby
  , urlRequested, urlChanged, newDraftGameId, confirm
  , update
  , urlString, draftGameId, okGameId
  )


{-| Managing the lobby - selecting the game ID and the player name.
-}


import Browser
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
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraftGameId String
  | Confirm


{-| Default handler for links being clicked. External links are loaded,
internal links are ignored.
-}
urlRequested : (Msg -> msg) -> Browser.UrlRequest -> msg
urlRequested msgWrapper request =
  msgWrapper <| UrlRequested request


urlChanged : (Msg -> msg) -> Url.Url -> msg
urlChanged msgWrapper url =
  msgWrapper <| UrlChanged url


newDraftGameId : (Msg -> msg) -> String -> msg
newDraftGameId msgWrapper draft =
  msgWrapper <| NewDraftGameId draft


confirm : (Msg -> msg) -> msg
confirm msgWrapper =
  msgWrapper <| Confirm


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

    UrlRequested req ->
      case req of
        Browser.Internal url ->
          ( Lobby lob
          , Nothing
          , Cmd.none
          )

        Browser.External str ->
          ( Lobby lob
          , Nothing
          , Nav.load str
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

    Confirm ->
      ( Lobby lob
      , Nothing
      , lob.draftGameId
        |> setFragment lob.url
        |> Url.toString
        |> Nav.pushUrl lob.key
      )


setFragment : Url.Url -> String -> Url.Url
setFragment url fragment =
  { url | fragment = Just fragment }



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
