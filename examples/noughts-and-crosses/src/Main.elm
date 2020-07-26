-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Array exposing (Array)
import Browser
import Browser.Navigation as Nav
import Json.Encode as Enc
import Json.Decode as Dec
import Random
import Url

import Element as El
import Element.Events as Events
import Element.Input as Input
import BoardGameFramework as BGF

import UI as UI


-- Basic setup


main : Program BGF.ClientId Model Msg
main =
  Browser.application
  { init = init
  , update = update
  , subscriptions = subscriptions
  , onUrlRequest = \req -> Ignore
  , onUrlChange = UrlChanged
  , view = view
  }


-- Main type definitions


type alias Model =
  { url : Url.Url
  , key : Nav.Key
  , myId : BGF.ClientId
  , screen : Screen
  }


type Screen =
  Entrance EntranceState
  | Playing PlayingState


type alias EntranceState =
  { draftGameId : String }


type alias PlayingState =
  { gameId : BGF.GameId
  , turn : Mark
  , board : Array (Maybe Mark)
  }


type Mark = XMark | OMark


type Msg =
  UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraftGameId String
  | ConfirmGameId String
  | CellClicked Int Mark
  | Received (Result BGF.Error (BGF.Envelope Body))
  | Ignore


-- Game connectivity


server : BGF.Server
server = BGF.wsServer "bgf.pigsaw.org"


openCmd : BGF.GameId -> Cmd Msg
openCmd =
  BGF.open outgoing server


sendCmd : Body -> Cmd Msg
sendCmd =
  BGF.send outgoing bodyEncoder


-- Peer-to-peer messages


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming receive


receive : Enc.Value -> Msg
receive v =
  BGF.decode bodyDecoder v |> Received


-- The structure of the messages we'll send between players
type alias Body =
  { turn : Mark
  , board : Array (Maybe Mark)
  }


bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  let
    markEnc turn =
      case turn of
        XMark -> Enc.string "X"
        OMark -> Enc.string "O"
    boardMarkEnc piece =
      case piece of
        Just XMark -> Enc.string "X"
        Just OMark -> Enc.string "O"
        Nothing -> Enc.string " "
    boardEnc =
      Enc.array boardMarkEnc
  in
    Enc.object
    [ ("turn", markEnc body.turn)
    , ("board", boardEnc body.board)
    ]


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  let
    stringToMark s =
      case s of
        "X" -> XMark
        _ -> OMark
    stringToBoardMark s =
      case s of
        "X" -> Just XMark
        "O" -> Just OMark
        _ -> Nothing
    markDecoder = Dec.map stringToMark Dec.string
    boardMarkDecoder = Dec.map stringToBoardMark Dec.string
    boardDecoder = Dec.array boardMarkDecoder
  in
  Dec.map2
    Body
    (Dec.field "turn" markDecoder)
    (Dec.field "board" boardDecoder)


-- Initial state


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init myId url key =
  let
    (screen, cmd) = initialScreen url key
  in
  ( { url = url
    , key = key
    , myId = myId
    , screen = screen
    }
  , cmd
  )


initialScreen : Url.Url -> Nav.Key -> (Screen, Cmd Msg)
initialScreen url key =
  let
    frag = url.fragment |> Maybe.withDefault ""
  in
  case BGF.gameId frag of
    Ok gameId ->
      ( Playing
        { gameId = gameId
        , turn = XMark
        , board = Array.repeat 9 Nothing
        }
      , openCmd gameId
      )

    Err _ ->
      case url.fragment of
        Just str ->
          ( Entrance { draftGameId = frag }
          , Cmd.none
          )

        Nothing ->
          ( Entrance { draftGameId = frag }
          , Random.generate GeneratedGameId BGF.idGenerator
          )

-- Updating the model


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UrlChanged url ->
      let
        (screen, cmd) = initialScreen url model.key
      in
      ( { model | screen = screen }
      , cmd
      )

    GeneratedGameId gameId ->
      ( model |> setDraftGameId (BGF.fromGameId gameId)
      , Cmd.none
      )

    NewDraftGameId draft ->
      case model.screen of
        Entrance _ ->
          ( model |> setDraftGameId draft
          , Cmd.none
          )

        Playing _ ->
          (model, Cmd.none)

    ConfirmGameId id ->
      ( model
      , id |> setFragment model.url |> Url.toString |> Nav.pushUrl model.key
      )

    CellClicked i turn ->
      case model.screen of
        Playing state ->
          let
            board2 = Array.set i (Just turn) state.board
            state2 =
              { state
              | board = board2
              , turn = next turn
              }
          in
          ( { model | screen = Playing state2 }
          , sendCmd { turn = state2.turn, board = state2.board }
          )

        Entrance _ ->
          (model, Cmd.none)

    Received envRes ->
      case model.screen of
        Entrance _ ->
          (model, Cmd.none)

        Playing state ->
          case envRes of
            Ok env ->
              let
                (state2, cmd) = updateWithEnvelope env state
              in
              ( { model | screen = Playing state2 }
              , cmd
              )

            Err desc ->
              let
                _ = Debug.log "Error" desc
              in
              (model, Cmd.none)

    Ignore ->
      (model, Cmd.none)


setDraftGameId : String -> Model -> Model
setDraftGameId draft model =
  { model
  | screen = Entrance { draftGameId = draft  }
  }



setFragment : Url.Url -> String -> Url.Url
setFragment url fragment =
  { url | fragment = Just fragment }


setUrl : Url.Url -> Model -> Model
setUrl url model =
  { model | url = url }


-- Game mechanics


next : Mark -> Mark
next turn =
  case turn of
    XMark -> OMark
    OMark -> XMark


winner : PlayingState -> Maybe Mark
winner state =
  wins 0 1 2 state
  |> orElse (wins 3 4 5 state)
  |> orElse (wins 6 7 8 state)
  |> orElse (wins 0 3 6 state)
  |> orElse (wins 1 4 7 state)
  |> orElse (wins 2 5 8 state)
  |> orElse (wins 0 4 8 state)
  |> orElse (wins 2 4 6 state)


wins : Int -> Int -> Int -> PlayingState -> Maybe Mark
wins i j k state =
  let
    a = Array.get i state.board
    b = Array.get j state.board
    c = Array.get k state.board
  in
  case a of
    Just (Just mark) ->
      if a == b && b == c then
        Just mark
      else
        Nothing

    _ ->
      Nothing


-- Return mY if it's Just something, or else return mX. Used like this:
--     mX |> orElse mY
-- Kind of the inverse of andThen.
orElse : Maybe a -> Maybe a -> Maybe a
orElse mY mX =
  case mX of
    Just _ ->
      mX

    Nothing ->
      mY


-- Responding to incoming information


updateWithEnvelope : BGF.Envelope Body -> PlayingState -> (PlayingState, Cmd Msg)
updateWithEnvelope env state =
  case env of
    BGF.Welcome w ->
      (state, Cmd.none)

    BGF.Receipt r ->
      ( updateBoard r.body state
      , Cmd.none
      )

    BGF.Peer p ->
      ( updateBoard p.body state
      , Cmd.none
      )

    BGF.Joiner j ->
      ( state
      , sendCmd { turn = state.turn, board = state.board }
      )

    BGF.Leaver l ->
      (state, Cmd.none)

    BGF.Connection conn ->
      (state, Cmd.none)


updateBoard : Body -> PlayingState -> PlayingState
updateBoard body state =
  { state
  | turn = body.turn
  , board = body.board
  }


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Noughts and crosses"
  , body =
    List.singleton
      <| UI.layout UI.miniPaletteThunderCloud
      <| case model.screen of
        Entrance draftGameId ->
          viewEntrance draftGameId

        Playing state ->
          viewPlay state
  }


viewEntrance : EntranceState -> El.Element Msg
viewEntrance state =
  let
    enabled =
      case state.draftGameId |> BGF.gameId of
        Ok _ ->
          True
        Err _ ->
          False
  in
  El.paragraph
  []
  [ UI.inputText
    { onChange = NewDraftGameId
    , text = state.draftGameId
    , placeholderText = "Game ID"
    , label = "Game ID"
    , fontScale = 12
    , miniPalette = UI.miniPaletteThunderCloud
    }
  , UI.button
    { onPress = Just (ConfirmGameId state.draftGameId)
    , label = "Go"
    , enabled = enabled
    , miniPalette = UI.miniPaletteThunderCloud
    }
  ]


viewPlay : PlayingState -> El.Element Msg
viewPlay state =
  El.column []
  [ viewRow 0 state
  , viewRow 3 state
  , viewRow 6 state
  , viewWhoseTurnOrWinner state
  ]


viewRow : Int -> PlayingState -> El.Element Msg
viewRow i state =
  El.row []
  [ viewCell (i + 0) state
  , viewCell (i + 1) state
  , viewCell (i + 2) state
  ]


viewCell : Int -> PlayingState -> El.Element Msg
viewCell i state =
  case Array.get i state.board |> Maybe.withDefault Nothing of
    Nothing ->
      viewClickableCell i state

    Just XMark ->
      El.text " X "

    Just OMark ->
      El.text " O "


viewClickableCell : Int -> PlayingState -> El.Element Msg
viewClickableCell i state =
  El.text "[ ]"
  |> El.el [Events.onClick <| CellClicked i state.turn]


viewWhoseTurnOrWinner : PlayingState -> El.Element Msg
viewWhoseTurnOrWinner state =
  case winner state of
    Just XMark ->
      El.text "X wins the game!"

    Just OMark ->
      El.text "O wins the game!"

    Nothing ->
      case state.turn of
        XMark ->
          El.text "X to play"

        OMark ->
          El.text "O to play"
