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
import Json.Decode as Dec
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
  , name : Maybe String
  , players : Sync PlayerList
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
  | NewDraftName String
  | ConfirmedName
  | Ignore


-- Synchronisation


type Sync a =
  Sync { moveNumber : Int, envNum : Maybe Int } a


-- Zero a sync point
zero : a -> Sync a
zero val =
  Sync
    { moveNumber = 0
    , envNum = Nothing
    }
    val


-- Assume a new data value as the next step, but recognise that this is yet
-- to be confirmed.
assume : a -> Sync a -> Sync a
assume dat (Sync code _) =
  Sync
    { moveNumber = code.moveNumber + 1
    , envNum = Nothing
    }
    dat


-- Return just the data value from the synchronisation point
data : Sync a -> a
data (Sync _ dat) =
  dat


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
    , name = Nothing
    , players =
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


-- JSON encoders and decoders


clientEncoder : Client -> Enc.Value
clientEncoder cl =
  Enc.object
    [ ( "id", Enc.string cl.id )
    , ( "name", Enc.string cl.name )
    ]


clientListEncoder : List Client -> Enc.Value
clientListEncoder cs =
  Enc.list clientEncoder cs


playerListEncoder : PlayerList -> Enc.Value
playerListEncoder pl =
  let
    clients =
      case pl of
        NoPlayers os ->
          [[], os]

        OnePlayer a os ->
          [[a], os]

        TwoPlayers a b os ->
          [[a, b], os]
  in
  Enc.list
    clientListEncoder
    clients


playerListWrapperEncoder : PlayerList -> Enc.Value
playerListWrapperEncoder pl =
  Enc.object
    [ ( "players", playerListEncoder pl)
    ]


clientDecoder : Dec.Decoder Client
clientDecoder =
  Dec.map2 Client
    (Dec.field "id" Dec.string)
    (Dec.field "id" Dec.string)


clientListDecoder : Dec.Decoder (List Client)
clientListDecoder =
  Dec.list clientDecoder


noPlayersDecoder : Dec.Decoder PlayerList
noPlayersDecoder =
  Dec.map NoPlayers
    (Dec.index 1 clientListDecoder)


onePlayerDecoder : Dec.Decoder PlayerList
onePlayerDecoder =
  Dec.map2 OnePlayer
    (Dec.index 0 (Dec.index 0 clientDecoder))
    (Dec.index 1 clientListDecoder)


twoPlayersDecoder : Dec.Decoder PlayerList
twoPlayersDecoder =
  Dec.map3 TwoPlayers
    (Dec.index 0 (Dec.index 0 clientDecoder))
    (Dec.index 0 (Dec.index 1 clientDecoder))
    (Dec.index 1 clientListDecoder)


playerListDecoder : Dec.Decoder PlayerList
playerListDecoder =
  let
    nPlayersDecoder ps =
      case List.length ps of
        0 ->
          noPlayersDecoder

        1 ->
          onePlayerDecoder

        2 ->
          twoPlayersDecoder

        n ->
          Dec.fail
          <| "JSON for PlayerList has " ++ (String.fromInt n) ++ " players"
  in
  Dec.list clientListDecoder
  |> Dec.andThen nPlayersDecoder


playerListWrapperDecoder : Dec.Decoder PlayerList
playerListWrapperDecoder =
  Dec.field "players" playerListDecoder

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

    NewDraftName draft ->
      ( { model | draftName = draft }
      , Cmd.none
      )

    ConfirmedName ->
      if okName model.draftName then
        let
          name = model.draftName
          me = Client model.myId name
          playerList = OnePlayer me []
        in
        ( { model
          | name = Just name
          , players =
              model.players
              |> assume playerList
          }
        , Cmd.none
        )
      else
        (model, Cmd.none)

    Ignore ->
      (model, Cmd.none)


okName : String -> Bool
okName draft =
  (String.length draft >= 3)
  && (String.length draft <= 20)


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Paper, scissors, rock"
  , body =
    case model.gameId of
      Nothing ->
        viewLobby model.lobby

      Just gameId ->
        case model.name of
          Nothing ->
            viewNameForm model

          Just name ->
            viewGame model
  }


viewLobby : Lobby Msg BGF.GameId -> List (Html Msg)
viewLobby lobby =
  [ Lobby.view
    { label = "Enter game ID:"
    , placeholder = "Game ID"
    , button = "Next"
    }
    lobby
  ]


viewNameForm : Model -> List (Html Msg)
viewNameForm model =
  [ Html.label [] [ Html.text "Your name" ]
  , Html.input
    [ Events.onInput NewDraftName
    , Attr.value model.draftName
    ]
    []
  , Html.button
    [ Events.onClick ConfirmedName
    , Attr.disabled (not <| okName model.draftName)
    ]
    [ Html.label [] [ Html.text "Go" ]
    ]
  ]


viewGame : Model -> List (Html Msg)
viewGame model =
  let
    ps =
      model.players
      |> data
      |> extract
  in
  [ Html.div []
    [ Html.p []
      [ Html.text "Players: "
      , if List.length ps.players == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " ps.players
      ]
    , Html.p []
      [ Html.text "Observers: "
      , if List.length ps.observers == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " ps.observers
      ]
    ]
  ]


-- Handy functions for viewing the PlayerList


extract : PlayerList -> { players : List String, observers : List String }
extract players =
  case players of
    NoPlayers os ->
      { players = []
      , observers = List.map .name os
      }

    OnePlayer p1 os ->
      { players = [ p1.name ]
      , observers = List.map .name os
      }

    TwoPlayers p1 p2 os ->
      { players = [ p1.name, p2.name ]
      , observers = List.map .name os
      }
