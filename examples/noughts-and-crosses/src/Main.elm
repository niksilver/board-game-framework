-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Json.Encode as Enc
import Json.Decode as Dec
import Url


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


type alias Model =
  String


type Msg = Something


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  ("Hello!", Enc.string "Hiya!" |> outgoing)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  ("Helloee", Cmd.none)


-- Subscriptions and ports


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming (\v -> Something)


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Noughts and crosses"
  , body =
    [ Html.div [] [Html.text model]
    ]
  }
