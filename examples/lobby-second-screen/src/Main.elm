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
  { lobby : Lobby Msg Playing
  , playing : Playing
  }


type Playing =
  NotPlaying
  | ProfilePage RawProfileModel
  | InGame Profile


type alias Profile =
  { room : BGF.Room  -- Carried over from raw profile
  , name : String
  , team : Team
  }


-- Our model of the lobby is a composable-form model
type alias RawProfileModel =
  Form.View.Model RawProfile


type alias RawProfile =
  { room : BGF.Room  -- Carried over from lobby
  , name : String
  , team : String
  }


type Team = TeamA | TeamB


type Msg =
  ToLobby Lobby.Msg
  | RawProfileChanged RawProfileModel
  | EnteringGame Profile
  | Ignore


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  let
    (lobby, playing, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { lobby = lobby
    , playing = playing
    }
  , cmd
  )


initProfile : BGF.Room -> Playing
initProfile room =
  ProfilePage
  ( Form.View.idle
    { room = room
    , name = ""
    , team = "A"
    }
  )


-- If the room changes mid-game (by editing the browser's location bar)
-- we still want to preserve the player's name, team, and playing state.
changeRoom : BGF.Room -> Playing -> Playing
changeRoom room playing =
  case playing |> Debug.log "Old playing state was " of
    NotPlaying ->
      initProfile room

    ProfilePage rawProfileModel ->
      { room = room
      , name = rawProfileModel.values.name
      , team = rawProfileModel.values.team
      }
      |> Form.View.idle
      |> ProfilePage

    InGame profile ->
      { room = room
      , name = profile.name
      , team = profile.team
      }
      |> InGame


lobbyConfig : Lobby.Config Msg Playing
lobbyConfig =
  { initBase = NotPlaying
  , initGame = initProfile
  , change = changeRoom
  , openCmd = openCmd
  , msgWrapper = ToLobby
  }


-- Form for the second screen


form : BGF.Room -> Form RawProfile Profile
form room =
  let
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
  Form.succeed
  (\name team ->
    Profile room name team
  )
  |> Form.append nameField
  |> Form.append teamField


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
  let
    m = msg |> Debug.log "update: Msg"
    x = model.playing |> Debug.log "update: Old playing"
  in
  case msg of
    ToLobby subMsg ->
      let
        (lobby, playing, cmd) =
          Lobby.update subMsg model.playing model.lobby
      in
      ( { model
        | lobby = lobby
        , playing = playing
        }
      , cmd
      )

    RawProfileChanged rawProfileModel ->
      ( { model
        | playing = ProfilePage rawProfileModel
        }
      , Cmd.none
      )

    EnteringGame profile ->
      ( { model
        | playing = InGame profile
        }
      , Cmd.none
      )

    Ignore ->
      (model, Cmd.none)


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Lobby with second screen"
  , body =
    case model.playing of
      NotPlaying ->
        [ Lobby.view
          { label = "Room:"
          , placeholder = "Room"
          , button = "Go"
          }
          model.lobby
        ]

      ProfilePage rawProfileModel ->
        viewProfileForm rawProfileModel

      InGame profile ->
        viewGame profile
  }


viewProfileForm : RawProfileModel -> List (Html Msg)
viewProfileForm rawProfileModel =
  [ Form.View.asHtml
    { onChange = RawProfileChanged
    , action = "Enter"
    , loading = "Entering..."
    , validation = Form.View.ValidateOnBlur
    }
    (Form.map EnteringGame (form rawProfileModel.values.room))
    rawProfileModel
  ]


viewGame : Profile -> List (Html Msg)
viewGame profile =
  let
    teamToString team =
      case team of
        TeamA ->
          "Team A"

        TeamB ->
          "Team B"
  in
  [ Html.p [] [ Html.text <| "Room is " ++ (BGF.fromRoom profile.room) ]
  , Html.p [] [ Html.text <| "Your name is " ++ profile.name ]
  , Html.p [] [ Html.text <| "Your team is " ++ (teamToString profile.team) ]
  ]
