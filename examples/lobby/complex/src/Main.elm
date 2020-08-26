-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Form exposing (Form)
import Form.View
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
  { lobby : LobbyModel
  , game : Maybe Game
  }


-- Our model of the lobby is a composable-form model
type alias LobbyModel =
  Form.View.Model Input


type alias Input =
  { idLobby : Lobby Msg
  , name : String
  , team : String
  }


type alias Game =
  { gameId : BGF.GameId
  , name : String
  , team : Team
  }


type Team = TeamA | TeamB


type Msg =
  ToLobby Lobby.Msg
  | FormChanged LobbyModel
  | ExitingLobby Game
  | Ignore


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  let
    (lobby, maybeGameId, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { lobby =
        Form.View.idle
        { idLobby = lobby
        , name = ""
        , team = "A"
        }
    , game = Nothing
    }
  , cmd
  )


lobbyConfig : Lobby.Config Msg
lobbyConfig =
  { openCmd = openCmd
  , msgWrapper = ToLobby
  }


-- The lobby form


form : Form Input Game
form =
  let
    gameIdField =
      Form.textField
        { parser = BGF.gameId
        , value = \input -> Lobby.draft input.idLobby
        , update = updateDraft
        , error = always Nothing
        , attributes =
            { label = "Game ID"
            , placeholder = "Game ID"
            }
        }
    nameField =
      Form.textField
        { parser = nameParser
        , value = .name
        , update = \name input -> { input | name = name }
        , error = always Nothing
        , attributes =
            { label = "Your name"
            , placeholder = "Name"
            }
        }
    teamField =
      Form.radioField
        { parser = teamParser
        , value = .team
        , update = \team input -> { input | team = team }
        , error = always Nothing
        , attributes =
            { label = "Choose which team you will play on"
            , options = [("A", "Team A"), ("B", "Team B")]
            }
        }
  in
  Form.succeed Game
  |> Form.append gameIdField
  |> Form.append nameField
  |> Form.append teamField


updateDraft : String -> Input -> Input
updateDraft draft input =
  { input
  | idLobby = Lobby.newDraft draft input.idLobby
  }


nameParser : String -> Result String String
nameParser name =
  if String.length name >= 3 then
    Ok name
  else
    Err "Too short"


teamParser : String -> Result String Team
teamParser code =
  case code of
    "A" ->
      Ok TeamA

    "B" ->
      Ok TeamB

    _ ->
      Err "Unrecognised team"


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
        _ = subMsg |> Debug.log "ToLobby"
      in
      (model, Cmd.none)

    FormChanged input ->
      ( { model | lobby = input }
      , Cmd.none
      )

    ExitingLobby game ->
      ( { model | game = Just game }
      , Cmd.none
      )

    Ignore ->
      (model, Cmd.none)


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Complex lobby example"
  , body =
    case model.game of
      Nothing ->
        viewLobby model.lobby

      Just game ->
        viewGame game
  }


viewLobby : LobbyModel -> List (Html Msg)
viewLobby lobbyModel =
  [ Form.View.asHtml
    { onChange = FormChanged
    , action = "Enter"
    , loading = "Entering..."
    , validation = Form.View.ValidateOnBlur
    }
    (Form.map ExitingLobby form)
    lobbyModel
  ]


viewGame : Game -> List (Html Msg)
viewGame game =
  let
    teamToString team =
      case team of
        TeamA ->
          "Team A"

        TeamB ->
          "Team B"
  in
  [ Html.text <| "Game ID is " ++ (BGF.fromGameId game.gameId)
  , Html.text <| "Your name is " ++ game.name
  , Html.text <| "Your team is " ++ (teamToString game.team)
  ]
