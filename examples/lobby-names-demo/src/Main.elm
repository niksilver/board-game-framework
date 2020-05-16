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


-- How we pick random numbers for our game ID
gameIDGenerator = Random.int 0 (Array.length words - 1)


-- Words for the game ID
words : Array String
words =
  [ "aarvark"
  , "abbey"
  , "battle"
  , "cucumber"
  , "zebra"
  ]
  |> Array.fromList


type alias Model =
  { gameID: Maybe String
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( { gameID = Nothing
    }
    , Random.generate GameIDNum gameIDGenerator
  )


-- Update the model with a message


type Msg =
  GameIDNum Int


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GameIDNum n ->
      let
        -- Get a word from the word list for the game ID
        id =
          case Array.get n words of
            Nothing -> "xxx"
            Just id0 -> id0
      in
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
