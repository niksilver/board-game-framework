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


type Msg =
  ToLobby Lobby.Msg
  | NewDraftName String
  | ConfirmedName
  | Received (Result BGF.Error (BGF.Envelope (Sync PlayerList)))


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


-- Encode a synced data value for sending to another client
syncEncoder : (a -> Enc.Value) -> Sync a -> Enc.Value
syncEncoder enc (Sync code dat) =
  Enc.object
    [ ( "moveNumber", Enc.int code.moveNumber )
    , ( "envNum", maybeEncoder Enc.int code.envNum )
    , ( "data", enc dat)
    ]


-- Decode a synced data value received from another client
syncDecoder : (Dec.Decoder a) -> Dec.Decoder (Sync a)
syncDecoder dec =
  Dec.map3 (\mn en dat -> Sync { moveNumber = mn, envNum = en } dat)
    (Dec.field "moveNumber" Dec.int)
    (Dec.field "envNum" (maybeDecoder Dec.int))
    (Dec.field "data" dec)


-- Encodes Nothing to [], and Just x to [x]
maybeEncoder : (a -> Enc.Value) -> Maybe a -> Enc.Value
maybeEncoder enc ma =
  case ma of
    Nothing ->
      Enc.list enc []

    Just x ->
      Enc.list enc [x]


-- Decodes [] to Nothing and [x] to Just x
maybeDecoder : Dec.Decoder a -> Dec.Decoder (Maybe a)
maybeDecoder dec =
  let
    innerDec list =
      case list of
        [] ->
          Dec.succeed Nothing

        head :: _ ->
          Dec.succeed (Just head)
  in
  Dec.list dec
  |> Dec.andThen innerDec


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
  BGF.open outgoing server |> Debug.log "openCmd"


sendPlayerListCmd : Sync PlayerList -> Cmd Msg
sendPlayerListCmd =
  BGF.send outgoing wrappedSyncPlayerListEncoder


-- Peer-to-peer messages


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions _ =
  incoming createMsg


createMsg : Enc.Value -> Msg
createMsg v =
  BGF.decode wrappedSyncPlayerListDecoder v |> Received 


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


syncPlayerListEncoder : Sync PlayerList -> Enc.Value
syncPlayerListEncoder spl =
  syncEncoder playerListEncoder spl


wrappedSyncPlayerListEncoder : Sync PlayerList -> Enc.Value
wrappedSyncPlayerListEncoder pl =
  Enc.object
    [ ( "players", syncPlayerListEncoder pl)
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
          <| "JSON for PlayerList has " ++ (String.fromInt n) ++ " players"

        Nothing ->
          Dec.fail
          <| "JSON for PlayerList does not have a first element"
  in
  Dec.list clientListDecoder
  |> Dec.andThen nPlayersDecoder


syncPlayerListDecoder : Dec.Decoder (Sync PlayerList)
syncPlayerListDecoder =
  syncDecoder playerListDecoder


wrappedSyncPlayerListDecoder : Dec.Decoder (Sync PlayerList)
wrappedSyncPlayerListDecoder =
  Dec.field "players" syncPlayerListDecoder


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
        -- With a good name we can send our name in the player list
        let
          name = model.draftName
          me = Client model.myId name
          playerList = OnePlayer me []
          players =
            model.players
            |> assume playerList
        in
        ( { model
          | name = Just name
          , players = players
          }
        , sendPlayerListCmd players
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


updateWithEnvelope : BGF.Envelope (Sync PlayerList) -> Model -> (Model, Cmd Msg)
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
      ( model
      , Cmd.none
      )

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
