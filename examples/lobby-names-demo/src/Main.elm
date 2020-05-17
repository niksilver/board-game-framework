-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Html exposing (..)
-- import Html.Attributes as Attr
-- import Html.Events as Events
-- import Json.Encode as Enc
import Array exposing (Array)
import Maybe
import Random
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


-- The board game server
serverURL : String
serverURL = "wss://board-game-framework.nw.r.appspot.com"


type alias Model =
  { gameID: Maybe String
  , key: Nav.Key
  , url: Url.Url
  }


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  if BGF.isGoodGameIDMaybe url.fragment then
    ( { gameID = url.fragment
      , key = key
      , url = url
      }
      , Cmd.none
    )

  else
    ( { gameID = Nothing
      , key = key
      , url = url
      }
      , Random.generate GameID BGF.idGenerator
    )


-- Update the model with a message


type Msg =
  GameID String
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GameID id ->
      ( { model | gameID = Just id }
      , Cmd.none
      )

    UrlRequested req ->
      (model, Cmd.none)

    UrlChanged url ->
      (model, Cmd.none)


-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


-- Ports to communicate with the framework


{-- port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


type Request a =
  Open String
  | Send Body
  | Close
  --}


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Lobby"
  , body =
    [ text <| "Game ID is " ++ Maybe.withDefault "[unknown]" model.gameID
    ]
  }
