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


-- Types and initialisation


type alias Model =
  { lobby : Lobby Msg (Maybe BGF.Room)
  , game : Maybe BGF.Room
  }


type Msg =
  ToLobby Lobby.Msg
  | Ignore


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  let
    (lobby, game, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { lobby = lobby
    , game = game
    }
  , cmd
  )


lobbyConfig : Lobby.Config Msg (Maybe BGF.Room)
lobbyConfig =
  { initBase = Nothing
  , initGame = \room -> Just room
  , change = \room _ -> Just room
  , openCmd = openCmd
  , msgWrapper = ToLobby
  }


-- Game connectivity


server : BGF.Server
server = BGF.wssServer "bgf.pigsaw.org"


openCmd : BGF.Room -> Cmd Msg
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
        (lobby, maybeRoom, cmd) = Lobby.update subMsg model.game model.lobby
      in
      ( { model
        | lobby = lobby
        , game = maybeRoom
        }
      , cmd
      )

    Ignore ->
      (model, Cmd.none)


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Simple lobby example"
  , body =
    case model.game of
      Nothing ->
        viewLobby model.lobby

      Just room ->
        viewGame room
  }


viewLobby : Lobby Msg (Maybe BGF.Room) -> List (Html Msg)
viewLobby lobby =
  [ Lobby.view
    { label = "Room:"
    , placeholder = "Room"
    , button = "Go"
    }
    lobby
  ]


viewGame : BGF.Room -> List (Html Msg)
viewGame room =
  [ Html.text <| "Room is " ++ (BGF.fromRoom room)
  ]
