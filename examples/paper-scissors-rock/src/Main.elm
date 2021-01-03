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

import Element as El
import Element.Background as Background
import Element.Font as Font
import Element.Input as Input

import UI

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


-- Sometimes it will be be useful to have a Client which we know is a player
type alias PlayerProfile =
  { name : String
  , hand : Hand
  , score : Int
  }


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


playerList : Clients Profile -> List (Client PlayerProfile)
playerList clients =
  let
    toPlayer client =
      case client.role of
        Player hand ->
          Just { id = client.id, name = client.name, hand = hand, score = client.score}

        Observer ->
          Nothing
  in
  Clients.filterMap toPlayer clients
  |> Clients.toList


hasPlayed : Client Profile -> Bool
hasPlayed client =
  case client.role of
    Player (Showing _) ->
      True

    _ ->
      False


-- The number of clients that have played their hand
countOfPlayed : Clients Profile -> Int
countOfPlayed clients =
  clients
  |> Clients.filterLength hasPlayed


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


-- Get the other player, if there is one.
otherPlayer : Client PlayerProfile -> Clients Profile -> Maybe (Client PlayerProfile)
otherPlayer me clients =
  playerList clients
  |> List.filter (\c -> c.id /= me.id)
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
  in
  case (myRole, maybeOther) of
    (Observer, Just other) ->
      clients
      |> Clients.mapOne other.id (\c -> { c | role = Player Closed })

    _ ->
      clients


-- Increment the score of the one player (if any) who has the winning hand.
awardPoint : Clients Profile -> Clients Profile
awardPoint clients =
  case playerList clients of
    [player1, player2] ->
      let
        id1 = player1.id
        id2 = player2.id
        (points1, points2) =
          case winner player1.hand player2.hand of
            1 -> (1, 0)
            2 -> (0, 1)
            _ -> (0, 0)
        increment points client =
          { client | score = client.score + points }
      in
      clients
      |> Clients.mapOne id1 (increment points1)
      |> Clients.mapOne id2 (increment points2)

    _ ->
      clients


-- What is the winning hand? Hand 1, 2 or neither.
winner : Hand -> Hand -> Int
winner hand1 hand2 =
  case (hand1, hand2) of
    (Showing shape1, Showing shape2) ->
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

    -- We don't have both hands showing
    _ ->
      0


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
          setMyRole >> closeOtherHand >> awardPoint
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
    List.singleton
    <| UI.layout
    <| case model.progress of
      InLobby ->
        viewLobby model.lobby

      ChoosingName state ->
        viewNameForm state.draftName

      Playing state ->
        viewGame
          (Lobby.urlString model.lobby)
          (Sync.value state.clients)
          model.myId
  }


viewLobby : Lobby Msg Progress -> El.Element Msg
viewLobby lobby =
  entryScreen
    ( UI.inputText
      { onChange = Lobby.newDraft ToLobby
      , text = Lobby.draft lobby
      , placeholderText = "Room name"
      , label = "Choose a room name"
      , fontScale = 12
      }
    )
    ( UI.shortButton
      { enabled = Lobby.okDraft lobby
      , onPress = Just (Lobby.confirm ToLobby)
      , textLabel = "Next"
      , imageLabel = El.none
      }
    )


entryScreen : El.Element Msg -> El.Element Msg -> El.Element Msg
entryScreen textInput button =
  UI.mainColumn
  [ UI.heading "Paper, Scissors, Rock"
  , UI.paddedRowWith
    [ El.spacing 20
    ]
    [ El.el
      [ El.width (El.fillPortion 2)
      ]
      (El.el [El.alignRight] textInput)
    , El.el
      [ El.width (El.fillPortion 1)
      , El.alignLeft
      ]
      button
    ]
  ]


viewNameForm : String -> El.Element Msg
viewNameForm draftName =
  entryScreen
  ( UI.inputText
    { onChange = NewDraftName
    , text = draftName
    , placeholderText = "Name"
    , label = "Your name"
    , fontScale = 12
    }
  )
  ( UI.shortButton
    { enabled = okName draftName
    , onPress = Just ConfirmedName
    , textLabel = "Go"
    , imageLabel = El.none
    }
  )


viewGame : String -> Clients Profile -> BGF.ClientId -> El.Element Msg
viewGame urlString clients myId =
  let
    showHands =
      (countOfPlayed clients) == 2
    players =
      playerList clients
    observers =
      clients
      |> Clients.filter (not << isPlayer)
    observerNames =
      observers
      |> Clients.mapToList .name
    amPlayer =
      players
      |> List.any (\p -> p.id == myId)
    amObserver =
      observers
      |> Clients.member myId
    playerVacancy = List.length players < 2
    canBePlayer = amObserver && playerVacancy
  in
  UI.mainColumn
  [ El.row [ El.width El.fill ]
    [ El.column
      [ El.width <| El.fillPortion 10
      , El.alignTop
      ]
      [ viewUserBar myId clients amPlayer canBePlayer
      , viewPlayers myId players
      , viewPlayStatus players
      ]
    , El.column [ El.width <| El.fillPortion 1 ] [ El.none ]
    , El.column
      [ El.width <| El.fillPortion 3
      , El.alignTop
      ]
      [ viewScores clients
      ]
    ]
  , viewInvitation urlString
  ]


viewUserBar : BGF.ClientId -> Clients Profile -> Bool -> Bool -> El.Element Msg
viewUserBar myId clients amPlayer canBePlayer =
  case Clients.get myId clients of
    Nothing ->
      -- A client that's not in the client list?!
      El.none

    Just me ->
      let
        roleText =
          case me.role of
            Observer -> "Observer"
            Player _ -> "Player"
      in
      UI.paddedRowWith
      [ El.spacing 20
      ]
      [ El.paragraph [ El.width (El.fillPortion 3) ] <|
        [ El.text <| "You: " ++ me.name ++ " (" ++ roleText ++ ") "
        ]

      , El.el [ El.width (El.fillPortion 2) ] <|
        UI.shortCentredButton
        { enabled = amPlayer
        , onPress = Just ConfirmedBecomeObserver
        , textLabel = "Become observer"
        , imageLabel = El.none
        }

      , El.el [ El.width (El.fillPortion 2) ] <|
        UI.shortCentredButton
        { enabled = canBePlayer
        , onPress = Just ConfirmedBecomePlayer
        , textLabel = "Become player"
        , imageLabel = El.none
        }

      , El.el [ El.width (El.fillPortion 2) ] <|
        UI.shortCentredButton
        { enabled = (countOfPlayed clients >= 1)
        , onPress = Just ConfirmedAnother
        , textLabel = "Play again"
        , imageLabel = El.none
        }

      ]


viewPlayers : BGF.ClientId -> List (Client PlayerProfile) -> El.Element Msg
viewPlayers myId players =
  case players of
    [] ->
      UI.paddedRow
      [ viewWaitingMessage "Waiting for first player"
      , viewWaitingMessage "Waiting for second player"
      ]

    [player1] ->
      UI.paddedRow
      [ viewPlayer myId player1 Nothing
      , viewWaitingMessage "Waiting for second player"
      ]

    [player1, player2] ->
      UI.paddedRow
      [ viewPlayer myId player1 (Just player2)
      , viewPlayer myId player2 (Just player1)
      ]

    _ ->
      -- Should never have three or more players
      UI.paddedRow
      [ viewWaitingMessage "Too many players!"
      ]


viewWaitingMessage : String -> El.Element Msg
viewWaitingMessage message =
  viewPlayerElements
  [ UI.centredTextWith
    [ El.width <| El.fillPortion 1
    , El.centerY
    ]
    message
  ]


-- View one player. We show their name, followed by something...
--   "alone"   - if there's no other player
--   The shape - if both players have played
--   "played"  - if they've played but the other player hasn't
--   "to play" - if they've not played, and they're not us, and there's another player
--   Buttons   - if they've not played, and they are us
viewPlayer : BGF.ClientId -> Client PlayerProfile -> Maybe (Client PlayerProfile) -> El.Element Msg
viewPlayer myId player maybeOtherPlayer =
  let
    playerIsMe =
      player.id == myId
    maybeOtherHand =
      maybeOtherPlayer
      |> Maybe.map .hand
    name = player.name
  in
  case (player.hand, playerIsMe, maybeOtherHand) of
    (_, _, Nothing) ->
      viewNamedPlayerMessage name "is alone"

    (Showing shape1, _, Just (Showing _)) ->
      viewNamedPlayerShape name shape1

    (Showing _, _, Just Closed) ->
      viewNamedPlayerMessage name "has played"

    (Closed, False, Just _) ->
      viewNamedPlayerMessage name "to play"

    (Closed, True, Just otherHand) ->
      viewNamedPlayerShapeButtons name


-- The player name and a message about them
viewNamedPlayerMessage : String -> String -> El.Element Msg
viewNamedPlayerMessage name message =
  viewNamedPlayerElement name <|
    UI.centredTextWith [ El.centerY ] message


-- The player name and the shape they've played
viewNamedPlayerShape : String -> Shape -> El.Element Msg
viewNamedPlayerShape name shape =
  viewNamedPlayerElement name <|
    case shape of
      Paper ->
        El.el [El.centerX] <|
          UI.image "Paper" "../images/paper.svg" 250

      Scissors ->
        El.el [El.centerX] <|
          UI.image "Scissors" "../images/scissors.svg" 250

      Rock ->
        El.el [El.centerX] <|
          UI.image "Rock" "../images/rock.svg" 250


-- The player name and the shape buttons
viewNamedPlayerShapeButtons : String -> El.Element Msg
viewNamedPlayerShapeButtons name =
  viewNamedPlayerElement name viewShapeButtons


-- The player name and some element
viewNamedPlayerElement : String -> El.Element Msg -> El.Element Msg
viewNamedPlayerElement name elt =
  viewPlayerElements
  [ UI.heading name
  , elt
  ]


-- Some elements showing a player's situation
viewPlayerElements : List (El.Element Msg) -> El.Element Msg
viewPlayerElements elts =
  El.column
  [ El.width <| El.fillPortion 1
  , El.height <| El.px 260
  ]
  elts


viewShapeButtons : El.Element Msg
viewShapeButtons =
  El.column
  [ El.centerX
  , El.spacing UI.fontSize
  , El.padding UI.fontSize
  ]
  [ UI.longButton
    { enabled = True
    , onPress = Just (ConfirmedShow Paper)
    , textLabel = "Paper"
    , imageLabel = UI.image "Paper" "../images/paper.svg" 28
    }
  , UI.longButton
    { enabled = True
    , onPress = Just (ConfirmedShow Scissors)
    , textLabel = "Scissors"
    , imageLabel = UI.image "Scissors" "../images/scissors.svg" 28
    }
  , UI.longButton
    { enabled = True
    , onPress = Just (ConfirmedShow Rock)
    , textLabel = "Rock"
    , imageLabel = UI.image "Rock" "../images/rock.svg" 28
    }
  ]


viewPlayStatus : List (Client PlayerProfile) -> El.Element Msg
viewPlayStatus players =
  case players of
    [] ->
      viewPlayStatusMessage "Need two players"

    [_] ->
      viewPlayStatusMessage "Need one more player"

    [player1, player2] ->
      case (player1.hand, player2.hand) of
        (Showing _, Showing _) ->
          case winner player1.hand player2.hand of
            1 ->
              viewPlayStatusMessage <| player1.name ++ " wins!"
            2 ->
              viewPlayStatusMessage <| player2.name ++ " wins!"
            _ ->
              viewPlayStatusMessage "It's a draw"

        _ ->
          -- Empty status (non-breaking space)
          viewPlayStatusMessage "\u{00a0}"

    _ ->
      viewPlayStatusMessage "Too many players"


viewPlayStatusMessage : String -> El.Element Msg
viewPlayStatusMessage message =
  UI.paddedRow
  [ UI.centredTextWith [Font.size UI.bigFontSize] message
  ]


viewScores : Clients Profile -> El.Element Msg
viewScores clients =
  let
    sortList =
      Clients.toList >> List.sortBy .name
    (players, observers) =
      clients
      |> Clients.partition isPlayer
      |> Tuple.mapBoth sortList sortList
    (maybePlayer1, maybePlayer2) =
      case players of
        [] ->
          ( Nothing, Nothing )
        [ p1 ] ->
          ( Just p1, Nothing )
        p1 :: p2 :: _ ->
          ( Just p1, Just p2 )

  in
  UI.paddedSpacedColumn <|
    List.concat
    [ [ UI.heading "Players" ]
    , [ viewMaybeOneScore maybePlayer1 ]
    , [ viewMaybeOneScore maybePlayer2 ]
    , [ viewEmptyScore ]
    , [ UI.heading "Observers" ]
    , List.map viewOneScore observers
    ]


viewMaybeOneScore : Maybe (Client Profile) -> El.Element Msg
viewMaybeOneScore maybeClient =
  case maybeClient of
    Nothing ->
      viewEmptyScore

    Just client ->
      viewOneScore client


viewOneScore : Client Profile -> El.Element Msg
viewOneScore client =
  El.row [ El.width El.fill ]
  [ El.el [ El.alignLeft ] <|
      El.text client.name
  , El.el [ El.alignRight ] <|
      El.text (String.fromInt client.score)
  ]


viewEmptyScore :  El.Element Msg
viewEmptyScore =
  El.row [ El.width El.fill ]
  [ El.text " "
  ]


viewInvitation : String -> El.Element Msg
viewInvitation urlString =
  let
    hashIndexes = String.indexes "#" urlString
    (restartLink, roomString) =
      case String.indexes "#" urlString of
        i :: _ ->
          ( String.left i urlString
          , String.dropLeft (i + 1) urlString
          )
        _ ->
          ( "[unknown]"
          , "[unknown]"
          )
  in
  UI.paddedRow
  [ El.paragraph []
    [ El.text "Invite your friends to "
    , El.link
      [ El.pointer, Font.underline ]
      { url = urlString
      , label = El.text urlString
      }
    , El.text <| " or give them room name " ++ roomString ++ ". "
    , El.text "You can also "
    , El.link
      [ El.pointer, Font.underline ]
      { url = restartLink
      , label = El.text "find another room"
      }
      , El.text "."
    ]
  ]
