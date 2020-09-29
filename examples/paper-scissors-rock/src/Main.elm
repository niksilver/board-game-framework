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
    { gameId : BGF.GameId
    , draftName : String
    }
  | Playing
    { gameId : BGF.GameId
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
    (lobby, maybeProgress, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { myId = clientId
    , lobby = lobby
    , progress =
        maybeProgress
        |> Maybe.withDefault InLobby
    }
  , cmd
  )


initClients : Sync (Clients Profile)
initClients =
  Clients.empty
  |> Sync.zero


lobbyConfig : Lobby.Config Msg Progress
lobbyConfig =
  { init = lobbyProgress
  , openCmd = openCmd
  , msgWrapper = ToLobby
  }


lobbyProgress : BGF.GameId -> Progress
lobbyProgress gameId =
  ChoosingName
  { gameId = gameId
  , draftName = ""
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
        (lobby, maybeProgress, cmd) = Lobby.update subMsg model.lobby
      in
      case maybeProgress of
        Nothing ->
          ( { model
            | lobby = lobby
            }
          , cmd
          )

        Just progress ->
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
                initClients
                |> Sync.mapToNext (addClient me)
              progress =
                Playing
                { gameId = state.gameId
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


okName : String -> Bool
okName draft =
  (String.length draft >= 3)
  && (String.length draft <= 20)


updateWithEnvelope : BGF.Envelope Body -> Model -> (Model, Cmd Msg)
updateWithEnvelope env model =
  case env |> Debug.log "Received envelope" of
    BGF.Welcome rec ->
      -- We've joined the game, but no action required.
      ( model
      , Cmd.none
      )

    BGF.Receipt rec ->
      updateWithBody env rec.body model

    BGF.Peer rec ->
      updateWithBody env rec.body model

    BGF.Joiner rec ->
      -- Ignore a joiner. We'll do something later when they send their name.
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


-- Respond the same to a Receipt or Peer envelope
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
        viewGame state.clients
  }


viewLobby : Lobby Msg Progress -> List (Html Msg)
viewLobby lobby =
  [ Lobby.view
    { label = "Enter game ID:"
    , placeholder = "Game ID"
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


viewGame : Sync (Clients Profile) -> List (Html Msg)
viewGame clients =
  let
    (players, observers) =
      clients
      |> Sync.value
      |> Clients.partition .player
      |> Tuple.mapBoth (Clients.mapToList .name) (Clients.mapToList .name)
  in
  [ Html.div []
    [ Html.p []
      [ Html.text "Players: "
      , if List.length players == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " players
      ]
    , Html.p []
      [ Html.text "Observers: "
      , if List.length observers == 0 then
          Html.text "None"
        else
          Html.text <| String.join ", " observers
      ]
    ]
  ]
