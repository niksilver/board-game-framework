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
  , onUrlRequest = \req -> Something
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
  , board : Array Piece
  }


type Piece = Empty | XMark | OMark


type Msg =
  UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraftGameId String
  | ConfirmGameId String
  | Something


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

    Something ->
      (model, dUMMY_FUNCTION)


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


-- Subscriptions and ports


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming (\v -> Something)


dUMMY_FUNCTION : Cmd msg
dUMMY_FUNCTION =
  Enc.string "x" |> outgoing


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
  [ viewRow 0 state.board
  , viewRow 3 state.board
  , viewRow 6 state.board
  ]


viewRow : Int -> Array Piece -> El.Element Msg
viewRow i array =
  El.row []
  [ viewCell (i + 0) array
  , viewCell (i + 1) array
  , viewCell (i + 2) array
  ]


viewCell : Int -> Array Piece -> El.Element Msg
viewCell i array =
  case Array.get i array of
    Nothing ->
      El.none

    Just Empty ->
      El.text "[ ]"

    Just XMark ->
      El.text " X "

    Just OMark ->
      El.text " O "
