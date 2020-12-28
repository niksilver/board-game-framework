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
  , role : Role
  }


type Role =
  Observer
  | Player Hand


type Hand =
  Closed
  | Showing


isPlayer : Client Profile -> Bool
isPlayer client =
  case client.role of
    Player _ ->
      True

    Observer ->
      False


-- Message types


type Msg =
  ToLobby Lobby.Msg
  | NewDraftName String
  | ConfirmedName
  | Received (Result Dec.Error (BGF.Envelope Body))
  | ConfirmedBecomeObserver
  | ConfirmedBecomePlayer
  | ConfirmedShow


type Body =
  MyNameMsg NamedClient
  | ClientListMsg (Sync (Clients Profile))


-- Client functions


playerCount : Clients Profile -> Int
playerCount cs =
  cs
  |> Clients.filterLength isPlayer


addClient : NamedClient -> Clients Profile -> Clients Profile
addClient namedClient cs =
  let
    clientIsPlayer =
      Clients.get namedClient.id cs
      |> Maybe.map isPlayer
      |> Maybe.withDefault False
    playerNeeded =
      playerCount cs < 2
    client =
      { id = namedClient.id
      , name = namedClient.name
      , role =
          if clientIsPlayer || playerNeeded then
            Player Closed
          else
            Observer
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
      ChoosingName
      { room = room
      , draftName = rec.draftName
      , clients = initClients
      }

    Playing rec ->
      Playing
      { room = room
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
  Wrap.send outgoing "clients" encodeSyncClientList


sendMyNameCmd : NamedClient -> Cmd Msg
sendMyNameCmd =
  Wrap.send outgoing "myName" encodeNamedClient


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


encodeRole : Role -> Enc.Value
encodeRole role =
  case role of
    Player Closed ->
      Enc.string "PlayerClosed"

    Player Showing ->
      Enc.string "PlayerShowing"

    Observer ->
      Enc.string "Observer"


encodeNamedClient : NamedClient -> Enc.Value
encodeNamedClient namedClient =
  Enc.object
    [ ( "id", Enc.string namedClient.id )
    , ( "name", Enc.string namedClient.name )
    ]


encodeClientList : Clients Profile -> Enc.Value
encodeClientList =
  Clients.encode
  [ ("name", .name >> Enc.string)
  , ("role", .role >> encodeRole)
  ]


encodeSyncClientList : Sync (Clients Profile) -> Enc.Value
encodeSyncClientList scl =
  Sync.encode encodeClientList scl


namedClientDecoder : Dec.Decoder NamedClient
namedClientDecoder =
  Dec.map2 NamedClient
    (Dec.field "id" Dec.string)
    (Dec.field "name" Dec.string)


roleDecoder : Dec.Decoder Role
roleDecoder =
  let
    toSymbol str =
      case str of
        "PlayerClosed" -> Dec.succeed (Player Closed)
        "PlayerShowing" -> Dec.succeed (Player Showing)
        "Observer" -> Dec.succeed Observer
        _ -> Dec.fail ("Unrecognised role '" ++ str ++ "'")
  in
  Dec.string
  |> Dec.andThen toSymbol


clientDecoder : Dec.Decoder (Client Profile)
clientDecoder =
  Dec.map3
  (\id name role -> { id = id, name = name, role = role })
  (Dec.field "id" Dec.string)
  (Dec.field "name" Dec.string)
  (Dec.field "role" roleDecoder)


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

    ConfirmedBecomeObserver ->
      updateMyRole Observer model

    ConfirmedBecomePlayer ->
      updateMyRole (Player Closed) model

    ConfirmedShow ->
      updateMyRole (Player Showing) model


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
        InLobby ->
          ( model
          , Cmd.none
          )

        ChoosingName state ->
          ( model
          , sendClientListCmd state.clients
          )

        Playing state ->
          ( model
          , sendClientListCmd state.clients
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
    InLobby ->
      (model, Cmd.none)

    ChoosingName state ->
      let
        clients =
          state.clients
          |> Sync.mapToNext mapping
      in
      ( { model
        | progress =
            ChoosingName { state | clients = clients }
        }
      , sendClientListCmd clients
      )

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


-- Change the role of one client only in a synced client list
changeRole : BGF.ClientId -> Role -> Sync (Clients Profile) -> Sync (Clients Profile)
changeRole id role clients =
  let
    changeRole2 client =
      { client | role = role }
    changeList =
      Clients.mapOne id changeRole2
  in
  clients
  |> Sync.mapToNext changeList


updateMyRole : Role -> Model -> (Model, Cmd Msg)
updateMyRole role model =
  case model.progress of
    Playing state ->
      let
        clients2 =
          state.clients
          |> changeRole model.myId role
      in
      ( { model
        | progress =
            Playing { state | clients = clients2 }
        }
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


-- Show a client's name with the hand they are currently playing. E.g. "Alice (scissors)"
nameWithHand : Client Profile -> String
nameWithHand client =
  let
    roleToShapeText role =
      case role of
        Observer -> ""
        Player Closed -> "..."
        Player Showing -> " (played!)"
  in
  client.name ++ (roleToShapeText client.role)


viewGame : Sync (Clients Profile) -> BGF.ClientId -> List (Html Msg)
viewGame clients myId =
  let
    (players, observers) =
      clients
      |> Sync.value
      |> Clients.partition isPlayer
    (playerNames, observerNames) =
      (players, observers)
      |> Tuple.mapBoth (Clients.mapToList nameWithHand) (Clients.mapToList nameWithHand)
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
        [ Events.onClick ConfirmedBecomeObserver
        , Attr.disabled (not <| amPlayer)
        ]
        [ Html.label [] [ Html.text "Become observer" ]
        ]
      , Html.button
        [ Events.onClick ConfirmedBecomePlayer
        , Attr.disabled (not <| canBePlayer)
        ]
        [ Html.label [] [ Html.text "Become player" ]
        ]
      ]

    , Html.p []
      [ Html.button
        [ Events.onClick ConfirmedShow
        , Attr.disabled (not <| amPlayer)
        ]
        [ Html.label [] [ Html.text "Show" ]
        ]
      ]
    ]
  ]
