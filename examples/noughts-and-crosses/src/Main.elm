-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Json.Encode as Enc
import Json.Decode as Dec
import Url

import Element as El
import Element.Input as Input

import UI as UI


-- Basic setup


main : Program () Model Msg
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
  , screen : Screen
  }


type Screen =
  Entrance String
  | Board


type Msg =
  NewDraftGameId String
  | ConfirmGameId String
  | UrlChanged Url.Url
  | Something


-- Initial state


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  ( { url = url
    , key = key
    , screen = initialScreen url key
    }
  , Cmd.none
  )


initialScreen : Url.Url -> Nav.Key -> Screen
initialScreen url key =
  case url.fragment of
    Just fragment ->
      Board

    Nothing ->
      Entrance "some-random-name"


-- Updating the model


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewDraftGameId draftId ->
      case model.screen of
        Entrance _ ->
          ({ model | screen = Entrance draftId }, Cmd.none)

        Board ->
          ({ model | screen = Board }, Cmd.none)

    ConfirmGameId id ->
      ( model
      , id |> setFragment model.url |> Url.toString |> Nav.pushUrl model.key
      )

    UrlChanged url ->
      ( model |> updateWithNewUrl url
      , Cmd.none
      )

    Something ->
      (model, dUMMY_FUNCTION)


setFragment : Url.Url -> String -> Url.Url
setFragment url fragment =
  { url | fragment = Just fragment }


setUrl : Url.Url -> Model -> Model
setUrl url model =
  { model | url = url }


updateWithNewUrl : Url.Url -> Model -> Model
updateWithNewUrl url model =
  case url.fragment of
    Just frag ->
      { model | screen = Board }
      |> setUrl url

    Nothing ->
      { model | screen = initialScreen url model.key }
      |> setUrl url


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

        Board ->
          viewBoard
  }


viewEntrance : String -> El.Element Msg
viewEntrance draftGameId =
  El.paragraph
  []
  [ UI.inputText
    { onChange = NewDraftGameId
    , text = draftGameId
    , placeholderText = "Game ID"
    , label = "Game ID"
    , fontScale = UI.fontSize
    , miniPalette = UI.miniPaletteThunderCloud
    }
  , UI.button
    { onPress = Just (ConfirmGameId draftGameId)
    , label = "Go"
    , enabled = True
    , miniPalette = UI.miniPaletteThunderCloud
    }
  ]


viewBoard : El.Element Msg
viewBoard =
  El.text "(Board goes here)"
