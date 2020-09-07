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
  , lobby : Lobby Msg BGF.GameId
  , gameId : Maybe BGF.GameId
  , draftName : String
  , name : Maybe String
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
  | Received (Result BGF.Error (BGF.Envelope Body))


type Body =
  MyNameMsg NamedClient
  | ClientListMsg (Sync (Clients Profile))


-- Client functions


playerCount : Clients Profile -> Int
playerCount cs =
  cs
  |> Clients.filterSize (.player >> not)


addIfNotPresent : NamedClient -> Clients Profile -> Clients Profile
addIfNotPresent namedClient cs =
  let
    playerMissing =
      playerCount cs < 2
    client =
      { id = namedClient.id
      , name = namedClient.name
      , player = playerMissing
      }
  in
    cs
    |> Clients.insert client


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
        Clients.empty
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


sendClientListCmd : Sync (Clients Profile) -> Cmd Msg
sendClientListCmd =
  Wrap.send outgoing "clients" syncClientListEncode


sendMyNameCmd : NamedClient -> Cmd Msg
sendMyNameCmd =
  Wrap.send outgoing "myName" namedClientEncode


-- Peer-to-peer messages


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


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
          me =
            { id = model.myId
            , name = name
            , player = True
            }
          clientList = Clients.singleton me
          clients =
            model.clients
            |> Sync.assume clientList
        in
        ( { model
          | name = Just name
          , clients = clients
          }
        , Cmd.batch
          [ sendMyNameCmd (NamedClient me.id me.name)
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


updateWithEnvelope : BGF.Envelope Body -> Model -> (Model, Cmd Msg)
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
        MyNameMsg namedClient ->
          updateWithMyName namedClient model

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


updateWithMyName : NamedClient -> Model -> (Model, Cmd Msg)
updateWithMyName namedClient model =
  let
    syncClientList2 =
      model.clients
      |> Sync.mapToNext (addIfNotPresent namedClient)
  in
  ( { model
    | clients = syncClientList2
    }
  , sendClientListCmd model.clients
  )


updateWithClientList : Int -> Sync (Clients Profile) -> Model -> (Model, Cmd Msg)
updateWithClientList num scl model =
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
    (players, observers) =
      model.clients
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
