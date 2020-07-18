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


-- Basic setup


main : Program () Model Msg
main =
  Browser.application
  { init = init
  , update = update
  , subscriptions = subscriptions
  , onUrlRequest = \req -> Something
  , onUrlChange = \url -> Something
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


type Msg = Something


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


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  (model, dUMMY_FUNCTION)


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
      <| El.layout []
      <| case model.screen of
        Entrance draftGameId ->
          viewEntrance draftGameId

        Board ->
          viewBoard
  }


viewEntrance : String -> El.Element Msg
viewEntrance draftGameId =
  El.text ("Entrance, with game ID " ++ draftGameId)


viewBoard : El.Element Msg
viewBoard =
  El.text "(Board goes here)"
