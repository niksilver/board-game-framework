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
import BoardGameFramework.Clients as Clients exposing (Clients, Client)
import BoardGameFramework.Lobby as Lobby exposing (Lobby)
import BoardGameFramework.Sync as Sync exposing (Sync)
import BoardGameFramework.Wrap as Wrap


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
  , lobby : Lobby Msg Progress
  , progress : Progress
  }


-- How much progress have we made into the game?
type Progress =
  InLobby
  | ChoosingName
    { room : BGF.Room
    , draftName : String
    , clients : Sync (Clients Profile)
    }
  | Playing
    { room : BGF.Room
    , name : String
    , clients : Sync (Clients Profile)
    }


type alias NamedClient =
  { id : BGF.ClientId
  , name : String
  }

-- A profile is a client description without their ID.
-- Their ID is added when we talk about a Client Profile.
type alias Profile =
  { name : String
  , player : Bool
  }


-- Message types


type Msg =
  ToLobby Lobby.Msg
  | NewDraftName String
  | ConfirmedName
  | Received (Result Dec.Error (BGF.Envelope Body))
  | ConfirmedObserve
  | ConfirmedPlay


type Body =
  MyNameMsg NamedClient
  | ClientListMsg (Sync (Clients Profile))


-- Client functions


playerCount : Clients Profile -> Int
playerCount cs =
  cs
  |> Clients.filterLength .player


addClient : NamedClient -> Clients Profile -> Clients Profile
addClient namedClient cs =
  let
    isPlayer =
      Clients.get namedClient.id cs
      |> Maybe.map .player
      |> Maybe.withDefault False
    playerNeeded =
      playerCount cs < 2
    client =
      { id = namedClient.id
      , name = namedClient.name
      , player =
          isPlayer || playerNeeded
      }
  in
    cs
    |> Clients.insert client


-- Initialisation functions


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init clientId url key =
  let
    (lobby, progress, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { myId = clientId
    , lobby = lobby
    , progress = progress
    }
  , cmd
  )


initClients : Sync (Clients Profile)
initClients =
  Clients.empty
  |> Sync.zero


lobbyConfig : Lobby.Config Msg Progress
lobbyConfig =
  { initBase = InLobby
  , initGame = lobbyProgress
  , change = changeRoom
  , openCmd = openCmd
  , msgWrapper = ToLobby
  }


lobbyProgress : BGF.Room -> Progress
lobbyProgress room =
  ChoosingName
  { room = room
  , draftName = ""
  , clients = initClients
  }


changeRoom : BGF.Room -> Progress -> Progress
changeRoom room progress =
  case progress of
    InLobby ->
      lobbyProgress room

    ChoosingName rec ->
      ChoosingName { rec | room = room }

    Playing rec ->
      Playing
      { room = room
      , name = rec.name
      , clients = initClients
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


sendClientListCmd : Sync (Clients Profile) -> Cmd Msg
sendClientListCmd =
  Wrap.send outgoing "clients" syncClientListEncode


sendMyNameCmd : NamedClient -> Cmd Msg
sendMyNameCmd =
  Wrap.send outgoing "myName" namedClientEncode


subscriptions : Model -> Sub Msg
subscriptions _ =
  incoming receive


receive : Enc.Value -> Msg
receive =
  Wrap.receive
  Received
  [ ("clients", Dec.map ClientListMsg syncClientListDecoder)
  , ("myName", Dec.map MyNameMsg namedClientDecoder)
  ]


-- JSON encoders and decoders


namedClientEncode : NamedClient -> Enc.Value
namedClientEncode namedClient =
  Enc.object
    [ ( "id", Enc.string namedClient.id )
    , ( "name", Enc.string namedClient.name )
    ]


clientListEncode : Clients Profile -> Enc.Value
clientListEncode =
  Clients.encode
  [ ("name", .name >> Enc.string)
  , ("player", .player >> Enc.bool)
  ]


syncClientListEncode : Sync (Clients Profile) -> Enc.Value
syncClientListEncode scl =
  Sync.encode clientListEncode scl


namedClientDecoder : Dec.Decoder NamedClient
namedClientDecoder =
  Dec.map2 NamedClient
    (Dec.field "id" Dec.string)
    (Dec.field "name" Dec.string)


clientDecoder =
  Dec.map3
  (\id name player -> { id = id, name = name, player = player })
  (Dec.field "id" Dec.string)
  (Dec.field "name" Dec.string)
  (Dec.field "player" Dec.bool)


clientListDecoder : Dec.Decoder (Clients Profile)
clientListDecoder =
  Clients.decoder clientDecoder


syncClientListDecoder : Dec.Decoder (Sync (Clients Profile))
syncClientListDecoder =
  Sync.decoder clientListDecoder


-- Updating the model


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    ToLobby subMsg ->
      let
        (lobby, progress, cmd) = Lobby.update subMsg model.progress model.lobby
      in
      ( { model
        | lobby = lobby
        , progress = progress
        }
      , cmd
      )

    NewDraftName draft ->
      ( model
        |> setDraftName draft
      , Cmd.none
      )

    ConfirmedName ->
      case model.progress of
        ChoosingName state ->
          if okName state.draftName then
            -- With a good name we can send our name to any other clients
            -- and our player list
            let
              me =
                { id = model.myId
                , name = state.draftName
                }
              clients =
                state.clients
                |> Sync.mapToNext (addClient me)
              progress =
                Playing
                { room = state.room
                , name = me.name
                , clients = clients
                }
            in
            ( { model
              | progress = progress
              }
            , Cmd.batch
              [ sendMyNameCmd (NamedClient me.id me.name)
              , sendClientListCmd clients
              ]
            )
          else
            (model, Cmd.none)

        _ ->
          (model, Cmd.none)

    Received envRes ->
      case envRes of
        Ok env ->
          updateWithEnvelope env model

        Err _ ->
          -- Ignore an error for now
          (model, Cmd.none)

    ConfirmedObserve ->
      makeMeObserver model

    ConfirmedPlay ->
      makeMePlayer model


okName : String -> Bool
okName draft =
  (String.length draft >= 3)
  && (String.length draft <= 20)


updateWithEnvelope : BGF.Envelope Body -> Model -> (Model, Cmd Msg)
updateWithEnvelope env model =
  case env of
    BGF.Welcome rec ->
      -- We've joined the game, but no action required.
      ( model
      , Cmd.none
      )

    BGF.Peer rec ->
      updateWithBody env rec.body model

    BGF.Joiner rec ->
      -- We've got a joiner, so let's tell them who the named clients are so far, if we can
      case model.progress of
        Playing state ->
          ( model
          , sendClientListCmd state.clients
          )

        _ ->
          ( model
          , Cmd.none
          )

    BGF.Leaver rec ->
      -- Remove a leaver from the clients list and send the new list
      model
      |> mapClientsToNextAndSend (Clients.remove rec.leaver)

    BGF.Connection conn ->
      -- Ignore a connection change
      ( model
      , Cmd.none
      )

    BGF.Error _ ->
      -- Ignore an error
      ( model
      , Cmd.none
      )


-- Respond to a Peer envelope
updateWithBody : BGF.Envelope Body -> Body -> Model -> (Model, Cmd Msg)
updateWithBody env body model =
  -- A message from another peer
  case body of
    MyNameMsg namedClient ->
      model
      |> mapClientsToNextAndSend (addClient namedClient)

    ClientListMsg clients ->
      case model.progress of
        Playing state ->
          -- We're playing and we've got an updated list of named clients
          let
            clients2 =
              state.clients
              |> Sync.resolve env clients
          in
          ( { model
            | progress =
                Playing { state | clients = clients2 }
            }
          -- Don't send out the client list we've just received
          , Cmd.none
          )

        ChoosingName state ->
          -- We're still choosing our name, but we've got a list of named clients
          ( { model
            | progress =
                ChoosingName { state | clients = clients }
            }
          , Cmd.none
          )

        _ ->
          (model, Cmd.none)


-- Set values for progress in the model


setDraftName : String -> Model -> Model
setDraftName draft model =
  case model.progress of
    ChoosingName state ->
      let
        progress =
          ChoosingName { state | draftName = draft}
      in
      { model
      | progress = progress
      }

    _ ->
      model


mapClientsToNextAndSend : (Clients Profile -> Clients Profile) -> Model -> (Model, Cmd Msg)
mapClientsToNextAndSend mapping model =
  case model.progress of
    Playing state ->
      let
        clients =
          state.clients
          |> Sync.mapToNext mapping
      in
      ( { model
        | progress =
            Playing { state | clients = clients }
        }
      , sendClientListCmd clients
      )

    _ ->
      (model, Cmd.none)


makeMeObserver : Model -> (Model, Cmd Msg)
makeMeObserver model =
  case model.progress of
    Playing state ->
      let
        downgradeMe client =
          if client.id == model.myId then
            { client | player = False }
          else
            client
        clients2 =
          state.clients
          |> Sync.mapToNext (Clients.map downgradeMe)
        model2 =
          { model
          | progress =
              Playing { state | clients = clients2 }
          }
      in
      ( model
      , sendClientListCmd clients2
      )

    _ ->
      (model, Cmd.none)


makeMePlayer : Model -> (Model, Cmd Msg)
makeMePlayer model =
  case model.progress of
    Playing state ->
      let
        upgradeMe client =
          if client.id == model.myId then
            { client | player = True }
          else
            client
        clients2 =
          state.clients
          |> Sync.mapToNext (Clients.map upgradeMe)
        model2 =
          { model
          | progress =
              Playing { state | clients = clients2 }
          }
      in
      ( model
      , sendClientListCmd clients2
      )

    _ ->
      (model, Cmd.none)


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Paper, scissors, rock"
  , body =
    case model.progress of
      InLobby ->
        viewLobby model.lobby

      ChoosingName state ->
        viewNameForm state.draftName

      Playing state ->
        viewGame state.clients model.myId
  }


viewLobby : Lobby Msg Progress -> List (Html Msg)
viewLobby lobby =
  [ Lobby.view
    { label = "Room:"
    , placeholder = "Room"
    , button = "Next"
    }
    lobby
  ]


viewNameForm : String -> List (Html Msg)
viewNameForm draftName =
  [ Html.label [] [ Html.text "Your name" ]
  , Html.input
    [ Events.onInput NewDraftName
    , Attr.value draftName
    ]
    []
  , Html.button
    [ Events.onClick ConfirmedName
    , Attr.disabled (not <| okName draftName)
    ]
    [ Html.label [] [ Html.text "Go" ]
    ]
  ]


viewGame : Sync (Clients Profile) -> BGF.ClientId -> List (Html Msg)
viewGame clients myId =
  let
    (players, observers) =
      clients
      |> Sync.value
      |> Clients.partition .player
    (playerNames, observerNames) =
      (players, observers)
      |> Tuple.mapBoth (Clients.mapToList .name) (Clients.mapToList .name)
    amPlayer =
      players
      |> Clients.member myId
    amObserver =
      observers
      |> Clients.member myId
    playerVacancy = List.length playerNames < 2
    canBePlayer = amObserver && playerVacancy
  in
  [ Html.div []
    [ Html.p []
      [ Html.text "Players: "
      , if List.length playerNames == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " playerNames
      ]
    , Html.p []
      [ Html.text "Observers: "
      , if List.length observerNames == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " observerNames
      ]
    , Html.p []
      [ Html.button
        [ Events.onClick ConfirmedObserve
        , Attr.disabled (not <| amPlayer)
        ]
        [ Html.label [] [ Html.text "Observe" ]
        ]
      , Html.button
        [ Events.onClick ConfirmedPlay
        , Attr.disabled (not <| canBePlayer)
        ]
        [ Html.label [] [ Html.text "Play" ]
        ]
      ]
    ]
  ]
