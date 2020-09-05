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
import BoardGameFramework.Clients as Clients exposing (Clients)
import BoardGameFramework.Lobby as Lobby exposing (Lobby)
import BoardGameFramework.Sync as Sync exposing (Sync)


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
  , clients : Sync ClientList
  }


-- Any client who has got into the game will have a name
type alias Client =
  { id : BGF.ClientId
  , name : String
  }


-- A client list is 0, 1 or 2 players plus a number of observers.
type ClientList =
  NoPlayers (List Client)
  | OnePlayer Client (List Client)
  | TwoPlayers Client Client (List Client)


-- How much progress have we made into the game?
type Progress =
  InLobby
  | ChoosingName
  | InGame


progress : Model -> Progress
progress model =
  case model.gameId of
    Nothing ->
      InLobby

    Just gameId ->
      case model.name of
        Nothing ->
          ChoosingName

        Just name ->
          InGame


-- Message types


type Msg =
  ToLobby Lobby.Msg
  | NewDraftName String
  | ConfirmedName
  | Received (Result BGF.Error (BGF.Envelope PeerMsg))


type PeerMsg =
  MyNameMsg Client
  | ClientListMsg (Sync ClientList)


-- ClientList functions


addIfNotPresent : Client -> ClientList -> ClientList
addIfNotPresent client pos =
  let
    matches c =
      client.id == c.id
    isPresent =
      case pos of
        NoPlayers obs ->
          List.any matches obs

        OnePlayer p1 obs ->
          matches p1
          || List.any matches obs

        TwoPlayers p1 p2 obs ->
          matches p1
          || matches p2
          || List.any matches obs
  in
  case isPresent of
    True ->
      pos

    False ->
      case pos of
        NoPlayers obs ->
          OnePlayer client obs

        OnePlayer p1 obs ->
          TwoPlayers p1 client obs

        TwoPlayers p1 p2 obs ->
          TwoPlayers p1 p2 (client :: obs)


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
    , clients =
        NoPlayers []
        |> Sync.zero
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
  BGF.open outgoing server |> Debug.log "openCmd"


sendClientListCmd : Sync ClientList -> Cmd Msg
sendClientListCmd =
  BGF.send outgoing wrappedSyncClientListEncode


sendMyNameCmd : Client -> Cmd Msg
sendMyNameCmd =
  BGF.send outgoing wrappedMyNameEncode


-- Peer-to-peer messages


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions _ =
  incoming createMsg


createMsg : Enc.Value -> Msg
createMsg v =
  BGF.decode peerMsgDecoder v |> Received


-- JSON encoders and decoders


clientEncode : Client -> Enc.Value
clientEncode cl =
  Enc.object
    [ ( "id", Enc.string cl.id )
    , ( "name", Enc.string cl.name )
    ]


clientListEncode : List Client -> Enc.Value
clientListEncode cs =
  Enc.list clientEncode cs


playerListEncode : ClientList -> Enc.Value
playerListEncode pl =
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
    clientListEncode
    clients


syncClientListEncode : Sync ClientList -> Enc.Value
syncClientListEncode spl =
  Sync.encode playerListEncode spl


wrappedSyncClientListEncode : Sync ClientList -> Enc.Value
wrappedSyncClientListEncode pl =
  Enc.object
    [ ( "players", syncClientListEncode pl)
    ]


wrappedMyNameEncode : Client -> Enc.Value
wrappedMyNameEncode client =
  Enc.object
    [ ( "myName", clientEncode client)
    ]


clientDecoder : Dec.Decoder Client
clientDecoder =
  Dec.map2 Client
    (Dec.field "id" Dec.string)
    (Dec.field "name" Dec.string)


listOfClientsDecoder : Dec.Decoder (List Client)
listOfClientsDecoder =
  Dec.list clientDecoder


noPlayersDecoder : Dec.Decoder ClientList
noPlayersDecoder =
  Dec.map NoPlayers
    (Dec.index 1 listOfClientsDecoder)


onePlayerDecoder : Dec.Decoder ClientList
onePlayerDecoder =
  Dec.map2 OnePlayer
    (Dec.index 0 (Dec.index 0 clientDecoder))
    (Dec.index 1 listOfClientsDecoder)


twoPlayersDecoder : Dec.Decoder ClientList
twoPlayersDecoder =
  Dec.map3 TwoPlayers
    (Dec.index 0 (Dec.index 0 clientDecoder))
    (Dec.index 0 (Dec.index 1 clientDecoder))
    (Dec.index 1 listOfClientsDecoder)


clientListDecoder : Dec.Decoder ClientList
clientListDecoder =
  let
    headLength ps =
      List.head ps
      |> Maybe.map List.length
    nPlayersDecoder ps =
      case headLength ps of
        Just 0 ->
          noPlayersDecoder

        Just 1 ->
          onePlayerDecoder

        Just 2 ->
          twoPlayersDecoder

        Just n ->
          Dec.fail
          <| "JSON for ClientList has " ++ (String.fromInt n) ++ " players"

        Nothing ->
          Dec.fail
          <| "JSON for ClientList does not have a first element"
  in
  Dec.list listOfClientsDecoder
  |> Dec.andThen nPlayersDecoder


syncClientListDecoder : Dec.Decoder (Sync ClientList)
syncClientListDecoder =
  Sync.decoder clientListDecoder


wrappedSyncClientListDecoder : Dec.Decoder (Sync ClientList)
wrappedSyncClientListDecoder =
  Dec.field "players" syncClientListDecoder


wrappedMyNameDecoder : Dec.Decoder Client
wrappedMyNameDecoder =
  Dec.field "myName" clientDecoder


peerMsgDecoder : Dec.Decoder PeerMsg
peerMsgDecoder =
  Dec.oneOf
  [ Dec.map ClientListMsg wrappedSyncClientListDecoder
  , Dec.map MyNameMsg wrappedMyNameDecoder
  ]


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
        , gameId = maybeGameId |> Debug.log "maybeGameId"
        }
      , cmd |> Debug.log "Lobby cmd"
      )

    NewDraftName draft ->
      ( { model | draftName = draft }
      , Cmd.none
      )

    ConfirmedName ->
      if okName model.draftName then
        -- With a good name we can send our name to any other clients
        -- and our player list
        let
          name = model.draftName
          me = Client model.myId name
          clientList = OnePlayer me []
          clients =
            model.clients
            |> Sync.assume clientList
        in
        ( { model
          | name = Just name
          , clients = clients
          }
        , Cmd.batch
          [ sendMyNameCmd me
          , sendClientListCmd clients
          ]
        )
      else
        (model, Cmd.none)

    Received envRes ->
      case envRes |> Debug.log "envRes" of
        Ok env ->
          updateWithEnvelope env model

        Err _ ->
          -- Ignore an error for now
          (model, Cmd.none)


okName : String -> Bool
okName draft =
  (String.length draft >= 3)
  && (String.length draft <= 20)


updateWithEnvelope : BGF.Envelope PeerMsg -> Model -> (Model, Cmd Msg)
updateWithEnvelope env model =
  case env |> Debug.log "Received envelope" of
    BGF.Welcome rec ->
      -- We've joined the game, but no action required
      ( model
      , Cmd.none
      )

    BGF.Receipt rec ->
      -- Our own message
      ( model
      , Cmd.none
      )

    BGF.Peer rec ->
      -- A message from another peer
      case rec.body of
        MyNameMsg client ->
          updateWithMyName client model

        ClientListMsg syncClientList ->
          updateWithClientList rec.num syncClientList model

    BGF.Joiner rec ->
      -- Ignore a joiner
      ( model
      , Cmd.none
      )

    BGF.Leaver rec ->
      -- Ignore a joiner
      ( model
      , Cmd.none
      )

    BGF.Connection conn ->
      -- Ignore a connection change
      ( model
      , Cmd.none
      )


updateWithMyName : Client -> Model -> (Model, Cmd Msg)
updateWithMyName client model =
  let
    syncClientList2 =
      model.clients
      |> Sync.mapToNext (addIfNotPresent client)
  in
  ( { model
    | clients = syncClientList2
    }
  , sendClientListCmd model.clients
  )


updateWithClientList : Int -> Sync ClientList -> Model -> (Model, Cmd Msg)
updateWithClientList num spl model =
  (model, Cmd.none |> Debug.log "To be implememented!")


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Paper, scissors, rock"
  , body =
    case progress model of
      InLobby ->
        viewLobby model.lobby

      ChoosingName ->
        viewNameForm model

      InGame ->
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
    cs =
      model.clients
      |> Sync.value
      |> extract
  in
  [ Html.div []
    [ Html.p []
      [ Html.text "Players: "
      , if List.length cs.players == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " cs.players
      ]
    , Html.p []
      [ Html.text "Observers: "
      , if List.length cs.observers == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " cs.observers
      ]
    ]
  ]


-- Handy functions for viewing the ClientList


extract : ClientList -> { players : List String, observers : List String }
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
