-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Encode as Enc
import Url

import BoardGameFramework as BGF
import BoardGameFramework.Lobby as Lobby exposing (Lobby)


-- Basic setup


main : Program BGF.ClientId Model Msg
main =
  Browser.application
  { init = init
  , update = update
  , subscriptions = subscriptions
  , onUrlRequest = Lobby.urlRequested ToLobby
  , onUrlChange = Lobby.urlChanged ToLobby
  , view = view
  }


-- Main types


type alias Model =
  { myId : BGF.ClientId
  , lobby : Lobby Msg BGF.GameId
  , gameId : Maybe BGF.GameId
  , draftName : String
  , clients : Sync PlayerList
  }


-- Any client who has got into the game will have a name
type alias Client =
  { id : BGF.ClientId
  , name : String
  }


-- A player list is 0, 1 or 2 players plus a number of client-observers.
type PlayerList =
  NoPlayers (List Client)
  | OnePlayer Client (List Client)
  | TwoPlayers Client Client (List Client)


type Msg =
  ToLobby Lobby.Msg
  | Ignore


-- Synchronisation


type Sync a =
  Sync { moveNumber : Int, envNum : Maybe Int } a


-- Zero a sync point
zero : a -> Sync a
zero data =
  Sync
    { moveNumber = 0
    , envNum = Nothing
    }
    data


-- Initialisation functions


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init clientId url key =
  let
    (lobby, maybeGameId, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { myId = clientId
    , lobby = lobby
    , gameId = maybeGameId
    , draftName = ""
    , clients =
        NoPlayers []
        |> zero
    }
  , cmd
  )


lobbyConfig : Lobby.Config Msg BGF.GameId
lobbyConfig =
  { init = identity
  , openCmd = openCmd
  , msgWrapper = ToLobby
  }


-- Game connectivity


server : BGF.Server
server = BGF.wssServer "bgf.pigsaw.org"


openCmd : BGF.GameId -> Cmd Msg
openCmd =
  BGF.open outgoing server


-- Peer-to-peer messages


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming ignoreMessage


ignoreMessage : Enc.Value -> Msg
ignoreMessage v =
  Ignore


-- Updating the model


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    ToLobby subMsg ->
      let
        (lobby, maybeGameId, cmd) = Lobby.update subMsg model.lobby
      in
      ( { model
        | lobby = lobby
        , gameId = maybeGameId
        }
      , cmd
      )

    Ignore ->
      (model, Cmd.none)


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Paper, scissors, rock"
  , body =
    case model.gameId of
      Nothing ->
        viewLobby model.lobby

      Just gameId ->
        viewGame model gameId
  }


viewLobby : Lobby Msg BGF.GameId -> List (Html Msg)
viewLobby lobby =
  [ Lobby.view
    { label = "Enter game ID:"
    , placeholder = "Game ID"
    , button = "Go"
    }
    lobby
  ]


viewGame : Model -> BGF.GameId -> List (Html Msg)
viewGame model id =
  [ Html.text <| "Game ID is " ++ (BGF.fromGameId id)
  ]
