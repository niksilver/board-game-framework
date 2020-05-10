-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module Main exposing (..)


import Browser
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events


main =
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view
    }


-- Null model and initialisation


type alias Model =
  { draftGameID: String
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( {draftGameID = "sample-game-id"}
  , Cmd.none
  )


-- Update the model with a message


type Msg =
  GameID String


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GameID id ->
      ( { model | draftGameID = id }
      , Cmd.none
      )


-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


-- View


view : Model -> Html Msg
view model =
  div[]
  [ p [] [text """
      Choose a game ID,
      then click "Open" to connect to the server.
      "Send" to send a message to the server.
      "Close" to close the connection. 
      You can change the message and send multiple times.
      """]
  , p [] [text "This code assumes the server is at http://localhost:8080"]
  , form []
    [ p []
      [ text "http://localhost:8080/g/"
      , input
        [ Attr.id "gameid"
        , Attr.type_ "text"
        , Attr.value model.draftGameID
        , Events.onInput GameID
        ] []
      , br [][]
      ]
    ]
  ]
