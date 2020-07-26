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
  , turn : Turn
  , board : Array Mark
  }


type Mark = Empty | XMark | OMark


type Turn = XTurn | OTurn


type Msg =
  UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraftGameId String
  | ConfirmGameId String
  | CellClicked Int Turn
  | Received (Result BGF.Error (BGF.Envelope Body))
  | Ignore


-- Game connectivity


server : BGF.Server
server = BGF.wsServer "bgf,pigsaw.org"


openCmd : BGF.GameId -> Cmd Msg
openCmd =
  BGF.open outgoing server


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
  { board : Array Mark
  }


bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  let
    pieceEnc piece =
      case piece of
        Empty -> Enc.string " "
        XMark -> Enc.string "X"
        OMark -> Enc.string "O"
    boardEnc =
      Enc.array pieceEnc body.board
  in
    Enc.object [("board", boardEnc)]


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  let
    stringToMark s =
      case s of
        "X" -> XMark
        "O" -> OMark
        _ -> Empty
    pieceDecoder = Dec.map stringToMark Dec.string
    boardDecoder = Dec.array pieceDecoder
  in
  Dec.map
    Body
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
        , turn = XTurn
        , board = Array.repeat 9 Empty
        }
      , Cmd.none
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
            board2 = takeTurn i turn state.board
            state2 =
              { state
              | board = board2
              , turn = next turn
              }
          in
          ( { model | screen = Playing state2 }
          , Cmd.none
          )

        Entrance _ ->
          (model, Cmd.none)

    Received env ->
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


takeTurn : Int -> Turn -> Array Mark -> Array Mark
takeTurn i turn array =
  let
    mark =
      case turn of
        XTurn -> XMark
        OTurn -> OMark
  in
  Array.set i mark array


next : Turn -> Turn
next turn =
  case turn of
    XTurn -> OTurn
    OTurn -> XTurn


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
  , viewWhoseTurn state.turn
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
  case Array.get i state.board of
    Nothing ->
      El.none

    Just Empty ->
      viewClickableCell i state

    Just XMark ->
      El.text " X "

    Just OMark ->
      El.text " O "


viewClickableCell : Int -> PlayingState -> El.Element Msg
viewClickableCell i state =
  El.text "[ ]"
  |> El.el [Events.onClick <| CellClicked i state.turn]


viewWhoseTurn : Turn -> El.Element Msg
viewWhoseTurn turn =
  case turn of
    XTurn ->
      El.text "X to play"

    OTurn ->
      El.text "O to play"
