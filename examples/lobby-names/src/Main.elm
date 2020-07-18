-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Json.Encode as Enc
import Json.Decode as Dec
import Maybe
import Random
import Url

import UI
import Element as El
import Element.Background as Background
import Element.Font as Font
import BoardGameFramework as BGF


main : Program () Model Msg
main =
  Browser.application
  { init = init
  , update = update
  , subscriptions = subscriptions
  , onUrlRequest = UrlRequested
  , onUrlChange = UrlChanged
  , view = view
  }


-- Model and basic initialisation


type alias Model =
  { key : Nav.Key
  , url : Url.Url
  , draftGameId : String
  , draftMyName : String
  , game : Game
  }


-- There are these game states:
--   Everything is unknown
--   We know we're in a game (with a good ID), but nothing else
--   Players are gathering.
type Game =
 Unknown
  | KnowGameIdOnly String BGF.Connectivity
  | Gathering GatherState


type alias GatherState =
  { myId : String
  , gameId : String
  , players : Dict String String
  , error : Maybe BGF.Error
  , connected : BGF.Connectivity
  }


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  case BGF.goodGameIdMaybe url.fragment of
    Just id ->
      ( { key = key
        , url = url
        , draftGameId = id
        , draftMyName = ""
        , game = KnowGameIdOnly id BGF.Closed
        }
        , openCmd id
      )

    Nothing ->
      ( { key = key
        , url = url
        , draftGameId = Maybe.withDefault "" url.fragment
        , draftMyName = ""
        , game = Unknown
        }
        , Random.generate GeneratedGameId BGF.idGenerator
      )


-- Try to change the game ID. We'll get an updated game and a flag to
-- say if we have joined a new game.
setGameId : String -> Game -> (Game, Bool)
setGameId gameId game =
  let
    sameId =
      case game of
        KnowGameIdOnly old _ ->
          gameId == old
        Gathering state ->
          gameId == state.gameId
        _ ->
          False
  in
  if sameId then
    (game, False)

  else if not(BGF.isGoodGameId gameId) then
    (game, False)

  else
    case game of
      Unknown ->
        ( KnowGameIdOnly gameId BGF.Closed
        , True
        )

      KnowGameIdOnly myId connected ->
        ( Gathering
          { myId = myId
          , gameId = gameId
          , players = Dict.empty
          , error = Nothing
          , connected = connected
          }
        , True
        )

      Gathering old ->
        ( Gathering
          { myId = old.myId
          , gameId = gameId
          , players = Dict.empty
          , error = Nothing
          , connected = old.connected
          }
        , True
        )


-- The board game server: connecting and sending


serverURL : String
serverURL = "ws://bgf.pigsaw.org"


openCmd : String -> Cmd Msg
openCmd gameId =
  BGF.Open (serverURL ++ "/g/" ++ gameId)
  |> BGF.encode bodyEncoder
  |> outgoing


-- Our peer-to-peer messages


type alias Body =
  { players : Dict String String
  }


type alias Envelope = BGF.Envelope Body


bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  Enc.object
  [ ("players" , Enc.dict identity Enc.string body.players)
  ]


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  let
    playersDec =
      Dec.field "players" (Dec.dict Dec.string)
  in
    Dec.map Body
      playersDec


-- Update the model with a message


type Msg =
  GeneratedGameId String
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | DraftGameIdChange String
  | JoinClick
  | DraftMyNameChange String
  | ConfirmNameClick
  | Received (Result BGF.Error Envelope)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GeneratedGameId id ->
      let
        url = model.url
        url2 = { url | fragment = Just id }
      in
      ( model
      , Nav.pushUrl model.key (Url.toString url2)
      )

    UrlRequested req ->
      -- The user has clicked on a link
      case req of
        Browser.Internal url ->
          init () url model.key

        Browser.External url ->
          (model, Nav.load url)

    UrlChanged url ->
      -- URL may have been changed by this app or by the user,
      -- so we can't assume the URL fragment is a good game ID.
      let
        frag = Maybe.withDefault "" url.fragment
        (game, changed) = model.game |> setGameId frag
        disconnected = (connectivity model.game /= BGF.Opened)
        cmd =
          if changed || disconnected then
            openCmd frag
          else
            Cmd.none
        model2 = { model | game = game }
      in
      ( { model
        | draftGameId = frag
        , url = url
        , game = game
        }
      , cmd
      )

    DraftGameIdChange draftId ->
      ({model | draftGameId = draftId}, Cmd.none)

    JoinClick ->
      let
        url = model.url
        url2 = { url | fragment = Just model.draftGameId }
      in
      ( model
      , Nav.pushUrl model.key (Url.toString url2)
      )

    DraftMyNameChange draftName ->
      ({model | draftMyName = draftName}, Cmd.none)

    ConfirmNameClick ->
      -- We've confirmed our name. If the game is in progress,
      -- update our game state and tell our peers
      case model.game of
        Gathering state ->
          let
            myId = state.myId
            myName = model.draftMyName
            players = state.players |> Dict.insert myId myName
            game = Gathering { state | players = players }
          in
          ( { model | game = game }
          , sendBodyCmd { players = players }
          )

        _ ->
          (model, Cmd.none)

    Received envRes ->
      case envRes of
        Ok env ->
          model
          |> updateWithNoError
          |> updateWithEnvelope env

        Err desc ->
          case model.game of
            Gathering state ->
              ( { model
                | game = Gathering {state | error = Just desc}
                }
              , Cmd.none
              )

            _ ->
              (model, Cmd.none)


updateWithNoError : Model -> Model
updateWithNoError model =
  case model.game of
    Gathering state ->
      { model
      | game = Gathering {state | error = Nothing}
      }

    _ ->
      model


sendBodyCmd : Body -> Cmd Msg
sendBodyCmd body =
  BGF.Send body
  |> BGF.encode bodyEncoder
  |> outgoing


updateWithEnvelope : Envelope -> Model -> (Model, Cmd Msg)
updateWithEnvelope env model =
  case env of
    BGF.Welcome w ->
      -- When we're welcomed, we'll assume the game has just started.
      -- Note the client ID we've been given and record it in our player table.
      let
        _ = Debug.log "Got welcome" w
      in
      case model.game of
        Unknown ->
          let
            _ = Debug.log "Got welcome from Unknown state - error!"
          in
            (model, Cmd.none)

        KnowGameIdOnly gameId _ ->
          ( { model
            | game =
              Gathering
              { myId = w.me
              , gameId = gameId
              , players = Dict.singleton w.me ""
              , error = Nothing
              , connected = BGF.Opened
              }
            }
          , Cmd.none
          )

        Gathering state ->
          let
            myName = state.players |> Dict.get w.me |> Maybe.withDefault ""
          in
          ( { model
            | game =
              Gathering
              { state |
                myId = w.me
              , players = Dict.singleton w.me myName
              , error = Nothing
              , connected = BGF.Opened
              }
            }
          , Cmd.none
          )

    BGF.Peer p ->
      -- A peer will send us the state of the whole game
      let
        _ = Debug.log "Got peer" p
      in
      case model.game of
        Gathering state ->
          ( { model
            | game =
              Gathering
              { state
              | players = p.body.players
              }
            }
          , Cmd.none
          )

        _ ->
          let
            _ = Debug.log "Got peer, but not Gathering"
          in
          (model, Cmd.none)

    BGF.Receipt r ->
      -- A receipt will be what we sent, so ignore it
      let
        _ = Debug.log "Got receipt" r
      in
        (model, Cmd.none)

    BGF.Joiner j ->
      -- When a client joins, record their ID and tell them the game state.
      let
        _ = Debug.log "Got joiner" j
      in
      case model.game of
        Gathering state ->
          let
            players =
              state.players |> Dict.insert j.joiner ""
          in
          ( { model
            | game = Gathering { state | players = players }
            }
          , sendBodyCmd { players = players }
          )

        _ ->
          let
            _ = Debug.log "Got joiner, game was not Gathering: " model.game
          in
          (model, Cmd.none)

    BGF.Leaver l ->
      -- When a client leaves remove their name from the players table
      let
        _ = Debug.log "Got leaver" l
      in
      case model.game of
        Gathering state ->
          let
            players =
              state.players |> Dict.remove l.leaver
          in
          ( { model
            | game = Gathering { state | players = players }
            }
          , Cmd.none
          )

        _ ->
          let
            _ = Debug.log "Got leaver, game was not Gathering: " model.game
          in
          (model, Cmd.none)

    BGF.Connection conn ->
      -- The connection state has changed
      let
        _ = Debug.log "Got connection envelope" conn
      in
      case model.game of
        Unknown ->
          ( model, Cmd.none)

        KnowGameIdOnly gameId _ ->
          ( { model
            | game = KnowGameIdOnly gameId conn
            }
          , Cmd.none
          )

        Gathering state ->
          ( { model
            | game = Gathering { state | connected = conn }
            }
          , Cmd.none
          )


-- Subscriptions and ports


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming decode


decode : Enc.Value -> Msg
decode v =
  BGF.decode bodyDecoder v |> Received


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Lobby demo"
  , body =
      List.singleton
      <| UI.layout UI.miniPaletteWaterfall.background
      <| El.column []
      <| case model.game of
          Gathering state ->
            [ viewLobbyTop model
            , viewNameSelection model.draftMyName state
            , viewFooter model
            ]

          _ ->
            [ viewLobbyTop model
            , viewFooter model
            ]
  }


viewWelcome : El.Element Msg
viewWelcome =
  El.text "Welcome"


viewLobbyTop : Model -> El.Element Msg
viewLobbyTop model =
  let
    mp = UI.miniPaletteThunderCloud
  in
  El.column
  [ El.padding (UI.scaledInt 2)
  , El.spacing (UI.scaledInt 3)
  , Background.color mp.background
  , Font.color mp.text
  ]
  [ UI.heading "Lobby demo" 3
  , viewJoin model
  ]


viewJoin : Model -> El.Element Msg
viewJoin model =
  let
    mp = UI.miniPaletteThunderCloud
  in
  El.row
  [ El.spacing (UI.scaledInt 3)
  ]
  [ El.column
    [ El.spacing (UI.scaledInt 1)
    , El.alignRight
    ]
    [ El.row
      [ El.spacing (UI.scaledInt 1) ]
      [ UI.inputText
        { onChange = DraftGameIdChange
        , text = model.draftGameId
        , placeholderText = "Game code"
        , label = "The code for this game is"
        , fontScale = 12
        , miniPalette = mp
        }
      , El.text " "
      , UI.button
        { onPress = Just JoinClick
        , enabled = joinEnabled model
        , label = "Join"
        , miniPalette = mp
        }
      ]
    , El.row [El.alignRight]
      [ viewError model |> El.el [El.alignRight]
      , El.text " "
      , viewConnectivity model |> El.el [El.alignRight]
      ]
    ]
    |> El.el [El.width (El.fillPortion 1), El.alignTop]
  , middleBlock
  , El.paragraph
    [ El.width (El.fillPortion 1)
    , El.alignTop
    ]
    [ El.text "Tell others to join you by "
    , El.text "typing the code into their box and hitting Join, or they can "
    , El.text " go to "
    , UI.link
      { url = Url.toString model.url
      , label = El.text (Url.toString model.url)
      }
    , El.text ". "
    ]
  ]


middleBlock : El.Element Msg
middleBlock =
  El.el [El.width (UI.scaledInt 4 |> El.px)] El.none


joinEnabled : Model -> Bool
joinEnabled model =
  let
    inGame gameId =
      case model.game of
        Gathering state ->
          state.gameId == gameId

        _ ->
          False
    goodId =
      BGF.isGoodGameId model.draftGameId
    draftIsThisGame =
      not(inGame model.draftGameId)
    disconnected =
      (connectivity model.game /= BGF.Opened)
  in
  goodId
  && (draftIsThisGame || disconnected)


connectivity : Game -> BGF.Connectivity
connectivity game =
  case game of
    Unknown ->
      BGF.Closed

    KnowGameIdOnly _ c ->
      c

    Gathering state ->
      state.connected


viewConnectivity : Model -> El.Element Msg
viewConnectivity model =
  case connectivity model.game of
    BGF.Opened ->
      UI.greenLight "Connected"

    BGF.Connecting ->
      UI.redLight "Connecting"

    BGF.Closed ->
      UI.redLight "Disconnected"


viewNameSelection : String -> GatherState -> El.Element Msg
viewNameSelection draftMyName state =
  let
    mp = UI.miniPaletteWaterfall
  in
  El.row
  [ El.width El.fill
  , El.padding (UI.scaledInt 2)
  , El.spacing (UI.scaledInt 3)
  , Background.color mp.background
  , Font.color mp.text
  ]
  [ viewMyName draftMyName state
  , middleBlock
  , viewPlayers state
  ]


viewMyName : String -> GatherState -> El.Element Msg
viewMyName draftMyName state =
  let
    mp = UI.miniPaletteWaterfall
  in
  El.row
  [ El.spacing (UI.scaledInt 1) ]
  [ UI.inputText
    { onChange = DraftMyNameChange
    , text = draftMyName
    , placeholderText = "Enter name"
    , label = "Your name"
    , fontScale = 12
    , miniPalette = mp
    }
  , El.text " "
  , UI.button
    { onPress = Just ConfirmNameClick
    , enabled = goodName draftMyName
    , label = "Confirm"
    , miniPalette = mp
    }
  ]
  |> El.el [El.alignRight]
  |> El.el
    [ El.alignTop
    , El.width (El.fillPortion 1)
    ]


goodName : String -> Bool
goodName name =
  String.length (String.trim name) >= 3


viewPlayers : GatherState -> El.Element Msg
viewPlayers state =
  let
    players =
      state.players
      |> Dict.toList
      |> List.map
        (\(id, name) ->
          El.text (nicePlayerName state.myId id name)
          |> El.el [El.height (UI.fontSize * 3 // 2 |> El.px)]
        )
      |> El.column [El.centerX]
    heading =
      UI.heading "Players" 2
  in
  El.column
  [ El.centerX
  , El.alignTop
  , El.width (El.fillPortion 1)
  , El.spacing (UI.scaledInt 1)
  ]
  [ heading
  , players
  ]


nicePlayerName : String -> String -> String -> String
nicePlayerName myId id name =
  (if goodName name then name else "Unknown player")
  ++ (if id == myId then " (you)" else "")


viewError : Model -> El.Element Msg
viewError model =
  let
    error =
      case model.game of
        Gathering state ->
          state.error

        _ ->
          Nothing
  in
  case error of
    Just (BGF.LowLevel desc) ->
        UI.amberLight ("Low level error: " ++ desc)

    Just (BGF.Json err) ->
      let
        desc = Dec.errorToString err
      in
      if String.length desc > 20 then
        UI.amberLight ("JSON error: " ++ (String.left 20 desc) ++ "...")
      else
        UI.amberLight ("JSON error: " ++ desc)

    Nothing ->
      El.none


viewFooter : Model -> El.Element Msg
viewFooter model =
  let
    url = model.url
    baseUrl = { url | fragment = Nothing }
    mp = UI.miniPaletteWaterfall
  in
  UI.link
  { url = Url.toString baseUrl
  , label = El.text "Click here to try a new game"
  }
  |> El.el [El.centerX]
  |> El.el
    [ Font.color mp.text
    , El.width El.fill
    ]
