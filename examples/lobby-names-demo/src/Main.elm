-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module Main exposing (..)


import Browser
import Html exposing (..)
-- import Html.Attributes as Attr
-- import Html.Events as Events
-- import Json.Encode as Enc
import Array exposing (Array)
import Maybe
import Random

import BoardGameFramework as BGF


main : Program () Model Msg
main =
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view
    }


-- Model and basic initialisation


-- The board game server
serverURL : String
serverURL = "wss://board-game-framework.nw.r.appspot.com"


type alias Model =
  { gameID: Maybe String
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( { gameID = Nothing
    }
    , Random.generate GameID BGF.idGenerator
  )


-- Update the model with a message


type Msg =
  GameID String


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GameID id ->
      ( { model | gameID = Just id }
      , Cmd.none
      )


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


view : Model -> Html Msg
view model =
  text <| "Game ID is " ++ Maybe.withDefault "[unknown]" model.gameID
