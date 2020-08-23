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


-- Main type definitions


type alias Model =
  { lobby : Lobby Msg BGF.GameId
  , game : Maybe BGF.GameId
  }


type Msg =
  ToLobby Lobby.Msg
  | Ignore


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  let
    (lobby, maybeGameId, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { lobby = lobby
    , game = maybeGameId
    }
  , cmd
  )


lobbyConfig : Lobby.Config Msg BGF.GameId
lobbyConfig =
  { stateMaker = identity
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
        , game = maybeGameId
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

      Just gameId ->
        viewGame gameId
  }


viewLobby : Lobby Msg BGF.GameId -> List (Html Msg)
viewLobby lobby =
  [ Html.text "Enter game ID: "
  , Html.input
    [ Events.onInput (Lobby.newDraft ToLobby)
    , Attr.value (Lobby.draft lobby)
    ]
    []
  , Html.text " "
  , Html.button
    [ Events.onClick (Lobby.confirm ToLobby)
    , Attr.disabled (not <| Lobby.okDraft lobby)
    ]
    [ Html.text "Go"
    ]
  ]


viewGame : BGF.GameId -> List (Html Msg)
viewGame id =
  [ Html.text <| "Game ID is " ++ (BGF.fromGameId id)
  ]
