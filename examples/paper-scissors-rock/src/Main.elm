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
  , score : Int
  }


type Role =
  Observer
  | Player Hand


type Hand =
  Closed
  | Showing Shape


type Shape =
  Paper
  | Scissors
  | Rock


-- Message types


type Msg =
  ToLobby Lobby.Msg
  | NewDraftName String
  | ConfirmedName
  | Received (Result Dec.Error (BGF.Envelope Body))
  | ConfirmedBecomeObserver
  | ConfirmedBecomePlayer
  | ConfirmedShow Shape
  | ConfirmedAnother


type Body =
  MyNameMsg NamedClient
  | ClientListMsg (Sync (Clients Profile))


-- Client functions


isPlayer : Client Profile -> Bool
isPlayer client =
  case client.role of
    Player _ ->
      True

    Observer ->
      False


hasPlayed : Client Profile -> Bool
hasPlayed client =
  case client.role of
    Player (Showing _) ->
      True

    _ ->
      False


-- True if all players have played their hand
allHavePlayed : Clients Profile -> Bool
allHavePlayed clients =
  clients
  |> Clients.filterLength hasPlayed
  |> (==) 2


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
      , score = 0
      }
  in
    cs
    |> Clients.insert client


-- Set the role of one client only in a client list
setRole : BGF.ClientId -> Role -> Clients Profile -> Clients Profile
setRole id role clients =
  let
    changeRole client =
      { client | role = role }
  in
  clients
  |> Clients.mapOne id changeRole


-- Get the other player (as long as we're given a player and there is another one)
otherPlayer : Client Profile -> Clients Profile -> Maybe (Client Profile)
otherPlayer me clients =
  case me.role of
    Observer ->
      Nothing

    Player _ ->
      clients
      |> Clients.filter (\c -> isPlayer c && c.id /= me.id)
      |> Clients.toList
      |> List.head


-- When one player has just become an observer we want to make sure the other
-- player's hand reverts to a closed state. This function does this for us.
closeOtherHandById : BGF.ClientId -> Role -> Clients Profile -> Clients Profile
closeOtherHandById myId myRole clients =
  let
    maybeOther =
      clients
      |> Clients.filter (\c -> isPlayer c && c.id /= myId)
      |> Clients.toList
      |> List.head
    maybeMe = Clients.get myId clients
    maybeMaybeOther =
      maybeMe
      |> Maybe.map (\me -> otherPlayer me clients)
  in
  case (myRole, maybeOther)
    (Observer, Just other) ->
      clients
      |> Clients.mapOne other.id (\c -> { c | role = Player Closed })

    _ ->
      clients


-- Increment the scores for all the players (but at most one player will score 1 point)
incrementScores : Clients Profile -> Clients Profile
incrementScores clients =
  let
    -- Allow a client to score 1 point if it's won vs another client
    points client =
      pointsVsOther client (otherPlayer client clients)

    -- Increment one client's score by however many points it deserves
    increment client =
      { client
      | score = client.score + (points client)
      }
  in
  clients
  |> Clients.map increment


-- How many points we score (1 or 0) vs a possible other player
pointsVsOther : Client Profile -> Maybe (Client Profile) -> Int
pointsVsOther me maybeOther =
  let
    otherRole =
      maybeOther
      |> Maybe.map .role
      |> Maybe.withDefault Observer
  in
  case (me.role, otherRole) of
    (Player (Showing myHand), Player (Showing otherHand)) ->
      case winner myHand otherHand of
        1 -> 1
        2 -> 0
        _ -> 0

    _ ->
      0


-- What is the winning shape? Shape 1, 2 or neither.
winner : Shape -> Shape -> Int
winner shape1 shape2 =
  case (shape1, shape2) of
    -- Shape 1 wins
    (Paper, Rock) -> 1
    (Scissors, Paper) -> 1
    (Rock, Scissors) -> 1

    -- Shape 2 wins
    (Rock, Paper) -> 2
    (Paper, Scissors) -> 2
    (Scissors, Rock) -> 2

    -- It's a draw
    _ -> 0


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

    Player (Showing Paper) ->
      Enc.string "PlayerShowingPaper"

    Player (Showing Scissors) ->
      Enc.string "PlayerShowingScissors"

    Player (Showing Rock) ->
      Enc.string "PlayerShowingRock"

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
  , ("score", .score >> Enc.int)
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
        "PlayerShowingPaper" -> Dec.succeed (Player (Showing Paper))
        "PlayerShowingScissors" -> Dec.succeed (Player (Showing Scissors))
        "PlayerShowingRock" -> Dec.succeed (Player (Showing Rock))
        "Observer" -> Dec.succeed Observer
        _ -> Dec.fail ("Unrecognised role '" ++ str ++ "'")
  in
  Dec.string
  |> Dec.andThen toSymbol


clientDecoder : Dec.Decoder (Client Profile)
clientDecoder =
  Dec.map4
  (\id name role score -> { id = id, name = name, role = role, score = score })
  (Dec.field "id" Dec.string)
  (Dec.field "name" Dec.string)
  (Dec.field "role" roleDecoder)
  (Dec.field "score" Dec.int)


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

    ConfirmedShow shape ->
      updateMyRole (Player (Showing shape)) model

    ConfirmedAnother ->
      updateAnotherRound model


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


updateMyRole : Role -> Model -> (Model, Cmd Msg)
updateMyRole role model =
  case model.progress of
    Playing state ->
      let
        setMyRole = setRole model.myId role
        closeOtherHand = closeOtherHandById model.myId role
        changeClients =
          setMyRole >> closeOtherHand >> incrementScores
        clients2 =
          state.clients
          |> Sync.mapToNext changeClients
      in
      ( { model
        | progress =
            Playing { state | clients = clients2 }
        }
      , sendClientListCmd clients2
      )

    _ ->
      (model, Cmd.none)


updateAnotherRound : Model -> (Model, Cmd Msg)
updateAnotherRound model =
  case model.progress of
    Playing state ->
      let
        resetHand client =
          case client.role of
            Player _ ->
              { client | role = Player Closed }

            Observer ->
              client
        clients2 =
          state.clients
          |> Sync.mapToNext (Clients.map resetHand)
        state2 =
          { state
          | clients = clients2
          }
      in
      ( { model
        | progress = Playing state2
        }
      , sendClientListCmd clients2
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
        viewGame
          (Sync.value state.clients)
          model.myId
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


-- Show a client's name with the hand they are currently playing.
-- E.g. "Alice (scissors)".  But if we're all not ready, just show "Alice (ready)"
nameWithHand : Bool -> Client Profile -> String
nameWithHand ready client =
  let
    roleToShapeText role =
      case (ready, role) of
        (_, Observer) -> ""
        (_, Player Closed) -> "..."
        (False, Player (Showing _)) -> " (ready)"
        (True, Player (Showing hand)) ->
          case hand of
            Paper -> " (paper)"
            Scissors -> " (scissors)"
            Rock -> " (rock)"
  in
  client.name ++ (roleToShapeText client.role)


viewGame : Clients Profile -> BGF.ClientId -> List (Html Msg)
viewGame clients myId =
  let
    showHands =
      allHavePlayed clients
    (players, observers) =
      clients
      |> Clients.partition isPlayer
    observerNames =
      observers
      |> Clients.mapToList .name
    amPlayer =
      players
      |> Clients.member myId
    amObserver =
      observers
      |> Clients.member myId
    playerVacancy = Clients.length players < 2
    canBePlayer = amObserver && playerVacancy
  in
  [ Html.div []
    [ Html.p [] <|
      viewUserBar myId clients amPlayer canBePlayer

    , Html.div [] <|
      viewPlayers myId players

    , Html.p []
      [viewPlayStatus players
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
        [ Events.onClick (ConfirmedAnother)
        , Attr.disabled (not <| amPlayer)
        ]
        [ Html.label [] [ Html.text "Again" ]
        ]
      ]

    , Html.p [] <|
      viewScores clients

    ]
  ]


viewUserBar : BGF.ClientId -> Clients Profile -> Bool -> Bool -> List (Html Msg)
viewUserBar myId clients amPlayer canBePlayer =
  case Clients.get myId clients of
    Nothing ->
      []

    Just me ->
      let
        roleText =
          case me.role of
            Observer -> "Observer"
            Player _ -> "Player"
      in
      [ Html.text <| "You: " ++ me.name ++ " (" ++ roleText ++ ") "
      , Html.button
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


viewPlayers : BGF.ClientId -> Clients Profile -> List (Html Msg)
viewPlayers myId clients =
  case Clients.toList clients of
    [] ->
      [ Html.p [] [Html.text "Waiting for first player"]
      , Html.p [] [Html.text "Waiting for second player"]
      ]

    [player1] ->
      [ Html.p [] <| viewPlayer myId player1 clients
      , Html.p [] [Html.text "Waiting for second player"]
      ]

    [player1, player2] ->
      [ Html.p [] <| viewPlayer myId player1 clients
      , Html.p [] <| viewPlayer myId player2 clients
      ]

    _ ->
      -- Should never have three or more players
      [ Html.p []
        [ Html.text "Too many players!"
        ]
      ]


-- View one player. We show their name, followed by something...
--   The shape - if both players have played
--   "played"  - if they've played but the other player hasn't
--   Error     - if they've played and there's no other player
--   "to play" - if they've not played, and they're not us, and there's another player
--   "alone"   - if they've not played, and they're not us, and there's no other player
--   Buttons   - if they've not played, and they are us
--               Buttons are disabled if there's no other player
viewPlayer : BGF.ClientId -> Client Profile -> Clients Profile -> List (Html Msg)
viewPlayer myId player clients =
  let
    playerIsMe =
      player.id == myId
    otherRole =
      otherPlayer player clients
      |> Maybe.map .role
      |> Maybe.withDefault Observer
  in
  case (player.role, playerIsMe, otherRole) of
    (Player (Showing shape1), _, Player (Showing _)) ->
      [ Html.text <| player.name ++ " (" ++ (shapeToText shape1) ++ ")"
      ]

    (Player (Showing _), _, Player Closed) ->
      [ Html.text <| player.name ++ " (played)"
      ]

    (Player (Showing _), _, Observer) ->
      [ Html.text <| player.name ++ " Error! Played without another player"
      ]

    (Player Closed, False, Player _) ->
      [ Html.text <| player.name ++ " to play"
      ]

    (Player Closed, False, Observer) ->
      [ Html.text <| player.name ++ " is alone"
      ]

    (Player Closed, True, other) ->
      [ Html.text <| player.name ++ " "
      , viewShapeButtons otherRole
      ]

    (Observer, _, _) ->
      [ Html.text <| player.name ++ " Error! This player is an observer"
      ]


shapeToText : Shape -> String
shapeToText shape =
  case shape of
    Paper -> "paper"
    Scissors -> "scissors"
    Rock -> "rock"


viewShapeButtons : Role -> Html Msg
viewShapeButtons otherRole =
  let
    noOtherPlayer =
      otherRole == Observer
  in
  Html.span []
    [ Html.button
      [ Events.onClick (ConfirmedShow Paper)
      , Attr.disabled noOtherPlayer
      ]
      [ Html.label [] [ Html.text "Paper" ]
      ]
    , Html.button
      [ Events.onClick (ConfirmedShow Scissors)
      , Attr.disabled noOtherPlayer
      ]
      [ Html.label [] [ Html.text "Scissors" ]
      ]
    , Html.button
      [ Events.onClick (ConfirmedShow Rock)
      , Attr.disabled noOtherPlayer
      ]
      [ Html.label [] [ Html.text "Rock" ]
      ]
    ]


viewPlayStatus : Clients Profile -> Html Msg
viewPlayStatus players =
  case Clients.toList players of
    [] ->
      Html.text "Need two players"

    [_] ->
      Html.text "Need one more player"

    [player1, player2] ->
      case (player1.role, player2.role) of
        (Player Closed, Player Closed) ->
          Html.text "Both to play"

        (Player (Showing _), Player Closed) ->
          Html.text <| "Waiting for " ++ player2.name

        (Player Closed, Player (Showing _)) ->
          Html.text <| "Waiting for " ++ player1.name

        (Player (Showing shape1), Player (Showing shape2)) ->
          case winner shape1 shape2 of
            1 ->
              Html.text <| player1.name ++ " wins!"
            2 ->
              Html.text <| player2.name ++ " wins!"
            _ ->
              Html.text "It's a draw"

        _ ->
          Html.text "Strange. One player is an observer"

    _ ->
      Html.text "Too many players"


viewScores : Clients Profile -> List (Html Msg)
viewScores clients =
  let
    viewScore client =
      [ Html.text <| client.name ++ ": " ++ (String.fromInt client.score)
      , Html.br [] []
      ]
  in
  clients
  |> Clients.mapToList viewScore
  |> List.concat
