-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Encode as Enc
import Json.Decode as Dec
import Maybe
import Random
import Tuple
import Url

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


-- There are four game states:
--   Everything is unknown
--   We know our ID, but nothing else
--   We know we're in a game (with a good ID), but nothing else
--   Game has started, and maybe ended
type Game =
 Unknown
  | KnowSelfOnly String
  | KnowGameIdOnly String
  | Started StartedState


type alias StartedState =
  { myId : String
  , gameId : String
  , players : Dict String String
  , ended : Bool
  , error : Maybe String
  }


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  case BGF.goodGameIdMaybe url.fragment of
    Just id ->
      ( { key = key
        , url = url
        , draftGameId = id
        , draftMyName = ""
        , game = KnowGameIdOnly id
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
        KnowGameIdOnly old ->
          gameId == old
        Started state ->
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
        ( KnowGameIdOnly gameId
        , True
        )

      KnowSelfOnly myId ->
        ( Started
          { myId = myId
          , gameId = gameId
          , players = Dict.empty
          , ended = False
          , error = Nothing
          }
        , True
        )

      KnowGameIdOnly myId ->
        ( Started
          { myId = myId
          , gameId = gameId
          , players = Dict.empty
          , ended = False
          , error = Nothing
          }
        , True
        )

      Started old ->
        ( Started
          { myId = old.myId
          , gameId = gameId
          , players = Dict.empty
          , ended = False
          , error = Nothing
          }
        , True
        )


-- The board game server: connecting and sending


serverURL : String
-- serverURL = "wss://board-game-framework.nw.r.appspot.com"
-- serverURL = "ws://bgf-aws-dev.eu-west-2.elasticbeanstalk.com"
serverURL = "ws://bgf-aws-dev.eu-west-2.elasticbeanstalk.com"


openCmd : String -> Cmd Msg
openCmd gameId =
  BGF.Open (serverURL ++ "/g/" ++ gameId)
  |> BGF.encode bodyEncoder
  |> outgoing


-- Our peer-to-peer messages


type alias Body =
  { players : Dict String String
  , ended : Bool
  }


type alias Envelope = BGF.Envelope Body


bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  Enc.object
  [ ("players" , Enc.dict identity Enc.string body.players)
  , ("ended", Enc.bool body.ended)
  ]


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  let
    playersDec =
      Dec.field "players" (Dec.dict Dec.string)
    endedDec =
      Dec.field "ended" Dec.bool
  in
    Dec.map2 Body
      playersDec
      endedDec


-- Update the model with a message


type Msg =
  GeneratedGameId String
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | DraftGameIdChange String
  | JoinClick
  | DraftMyNameChange String
  | ConfirmNameClick
  | EndClick
  | Received (Result String Envelope)


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
      (model, Cmd.none)

    UrlChanged url ->
      -- URL may have been changed by this app or by the user,
      -- so we can't assume the URL fragment is a good game ID.
      let
        frag = Maybe.withDefault "" url.fragment
        (game, changed) = model.game |> setGameId frag
        cmd =
          if changed then
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
        Started state ->
          if not(state.ended) then
            let
              myId = state.myId
              myName = model.draftMyName
              players = state.players |> Dict.insert myId myName
              game = Started { state | players = players }
            in
            ( { model | game = game }
            , sendBodyCmd { players = players, ended = state.ended }
            )
          else
            (model, Cmd.none)

        _ ->
          (model, Cmd.none)

    EndClick ->
      -- If we're ending the game, tell our peers
      case model.game of
        Started state ->
          let
            game = Started { state | ended = True }
          in
          ( { model | game = game }
          , sendBodyCmd { players = state.players, ended = True }
          )

        _ ->
          (model, Cmd.none)

    Received envRes ->
      case envRes of
        Ok env ->
          updateWithEnvelope env model

        Err desc ->
          case model.game of
            Started state ->
              ( { model
                | game = Started { state | error = Just desc }
                }
              , Cmd.none
              )

            _ ->
              (model, Cmd.none)


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

        KnowSelfOnly _ ->
          let
            _ = Debug.log "Got welcome from KnowSelfOnly state - error!"
          in
            (model, Cmd.none)

        KnowGameIdOnly gameId ->
          ( { model
            | game =
              Started
              { myId = w.me
              , gameId = gameId
              , players = Dict.singleton w.me ""
              , ended = False
              , error = Nothing
              }
            }
          , Cmd.none
          )

        Started state ->
          ( { model
            | game =
              Started
              { state |
                myId = w.me
              , players = Dict.singleton w.me ""
              , error = Nothing
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
        Started state ->
          ( { model
            | game =
              Started
              { state
              | players = p.body.players
              , ended = p.body.ended
              }
            }
          , Cmd.none
          )

        _ ->
          let
            _ = Debug.log "Got peer, but not Started"
          in
          (model, Cmd.none)

    BGF.Joiner j ->
      -- When a client joins,
      -- (a) if the game has started but not ended, record their ID; and
      -- (b) tell them the game state
      let
        _ = Debug.log "Got joiner" j
      in
      case model.game of
        Started state ->
          let
            players =
              if state.ended then
                state.players
              else
                state.players |> Dict.insert j.joiner ""
          in
          ( { model
            | game = Started { state | players = players }
            }
          , sendBodyCmd { players = players, ended = state.ended }
          )

        _ ->
          let
            _ = Debug.log "Got joiner, game was not Started: " model.game
          in
          (model, Cmd.none)

    BGF.Leaver l ->
      -- When a client leaves, if the game has not ended remove their
      -- name from the players table
      let
        _ = Debug.log "Got leaver" l
      in
      case model.game of
        Started state ->
          let
            players =
              if state.ended then
                state.players
              else
                state.players |> Dict.remove l.leaver
          in
          ( { model
            | game = Started { state | players = players }
            }
          , Cmd.none
          )

        _ ->
          let
            _ = Debug.log "Got leaver, game was not Started: " model.game
          in
          (model, Cmd.none)

    BGF.Closed ->
      -- The connection has closed. We don't act on this, currently
      let
        _ = Debug.log "Got closed envelope" True
      in
      ( model, Cmd.none)


-- Subscriptions and ports


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming decodeEnvelope


decodeEnvelope : Enc.Value -> Msg
decodeEnvelope v =
  BGF.decodeEnvelope bodyDecoder v |> Received


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Lobby"
  , body =
      case model.game of
        Started state ->
          if state.ended then
            List.concat
            [ viewPlayers state
            , viewError state
            ]

          else
            List.concat
            [ viewJoin model
            , viewMyName model.draftMyName state
            , viewPlayers state
            , viewEndOffer state
            , viewError state
            ]

        _ ->
          List.concat
          [ viewJoin model
          ]
  }


viewJoin : Model -> List (Html Msg)
viewJoin model =
  [ p []
    [ text "This is the code for this game. Tell others to join you by "
    , text "typing the code into their box and hitting Join, or they can "
    , text " go to "
    , a [Attr.href <| Url.toString model.url]
      [ text <| Url.toString model.url ], text ". "
    , text "You can join their game by typing their code into the box and "
    , text "hitting Join, or by going to the address they give you."
    ]
  , input
    [ Attr.type_ "text", Attr.size 30
    , Attr.value model.draftGameId
    , Events.onInput DraftGameIdChange
    ] []
  , text " "
  , button
    [ Attr.disabled <| not(BGF.isGoodGameId model.draftGameId)
    , Events.onClick JoinClick
    ]
    [text "Join"]
  ]


viewMyName : String -> StartedState -> List (Html Msg)
viewMyName draftMyName state =
  if not(state.ended) then
    let
      myName = Dict.get state.myId state.players
    in
    [ p []
      [ text "Your name: "
      , input
        [ Attr.type_ "text", Attr.size 15
        , Attr.value draftMyName
        , Events.onInput DraftMyNameChange
        ] []
      , text " "
      , button
        [ Attr.disabled <| not(goodName draftMyName)
        , Events.onClick ConfirmNameClick
        ]
        [ text "Confirm" ]
      ]
    ]

  else
    []


goodName : String -> Bool
goodName name =
  String.length (String.trim name) >= 3


viewPlayers : StartedState -> List (Html Msg)
viewPlayers state =
  state.players
  |> Dict.toList
  |> List.map
    (\(id, name) ->
      nicePlayerName state.myId id name
      |> text
      |> List.singleton
      |> p []
    )


nicePlayerName : String -> String -> String -> String
nicePlayerName myId id name =
  (if goodName name then name else "Unknown player")
  ++ (if id == myId then " (you)" else "")


viewEndOffer : StartedState -> List (Html Msg)
viewEndOffer state =
  [ p []
    [ text "When everyone is here... "
    , button
      [ Attr.disabled <| not(canEnd state)
      , Events.onClick EndClick
      ]
      [ text "End" ]
    ]
  ]


canEnd : StartedState -> Bool
canEnd state =
  not(state.ended)
  && List.all goodName (Dict.values state.players)


viewError : StartedState -> List (Html Msg)
viewError state =
  case state.error of
    Just desc ->
      [ p [] [ "Error: " ++ desc |> text ]
      ]

    Nothing ->
      []
