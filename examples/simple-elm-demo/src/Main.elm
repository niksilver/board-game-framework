-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Encode as Enc
import List
import Maybe
import String

import BoardGameFramework as BGF


main =
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view
    }


-- Model and basic initialisation


serverURL : String
serverURL = "ws://bgf.pigsaw.org"


type alias Model =
  { draftGameId: String
  , body: Body
  , history: List String
  }


type alias Body =
  { draftWords: String
  , draftTruth: Bool
  , draftWholeNumber: Int
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( { draftGameId = "sample-game-id"
    , body =
      { draftWords = "Hello world!"
      , draftTruth = True
      , draftWholeNumber = 27
      }
    , history = []
    }
  , Cmd.none
  )


-- Update the model with a message


type Msg =
  GameId String
  | OpenClick
  | Words String
  | Truth Bool
  | WholeNumber String
  | SendClick
  | CloseClick
  | Received String


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GameId id ->
      ( { model | draftGameId = id }
      , Cmd.none
      )

    OpenClick ->
      let
        url = serverURL ++ "/g/" ++ model.draftGameId
      in
      (model, BGF.Open url |> encode |> outgoing)

    Words w ->
      let
        body = model.body
      in
      ( { model | body = { body | draftWords = w }}
      , Cmd.none
      )

    Truth t ->
      let
        body = model.body
      in
      ( { model | body = { body | draftTruth = t }}
      , Cmd.none
      )

    WholeNumber nStr ->
      let
        body = model.body
        n =
          String.toInt nStr
          |> Maybe.withDefault model.body.draftWholeNumber
      in
      ( { model | body = { body | draftWholeNumber = n }}
      , Cmd.none
      )

    SendClick ->
      (model, BGF.Send model.body |> encode |> outgoing)

    CloseClick ->
      (model, BGF.Close |> encode |> outgoing)

    Received env ->
      ( { model
        | history = env :: model.history
        }
      , Cmd.none
      )


-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming toMessage


-- Ports to communicate with the framework


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


-- Turn an application request into something that can be sent out
-- through a port

encoder : Body -> Enc.Value
encoder body =
  Enc.object
  [ ("words", Enc.string body.draftWords)
  , ("truth", Enc.bool body.draftTruth)
  , ("wholenumber", Enc.int body.draftWholeNumber)
  ]


encode : BGF.Request Body -> Enc.Value
encode =
  BGF.encode encoder


-- Turn something that's come in from a port into a message we can
-- do something about... which will be just a string representation
-- of the thing

toMessage : Enc.Value -> Msg
toMessage v =
  Enc.encode 0 v |> Received


-- View


view : Model -> Html Msg
view model =
  div []
    [ viewControls model
    , viewHistory model
    ]


viewControls : Model -> Html Msg
viewControls model =
  div[]
    [ p [] [text """
        Choose a game ID, then click "Open" to connect to the server.
        "Send" to send the structured data to other clients in the same game.
        "Close" to close the connection.
        You can edit the structured data and send multiple times.
        """]
    , p []
      [ text serverURL
      , text "/g/"
      , input
        [ Attr.id "gameid"
      , Attr.type_ "text"
        , Attr.value model.draftGameId
        , Events.onInput GameId
        ] []
      , text " "
      , button [ Events.onClick OpenClick ] [ text "Open" ]
      , text " "
      , button [ Events.onClick CloseClick ] [ text "Close" ]
      ]
    , p []
      [ text "{", br [] []
      , span [Attr.style "margin-left" "1em"] [text "Words: "]
      , input
        [ Attr.type_ "text"
        , Attr.value model.body.draftWords
        , Events.onInput Words
        ] []
      , br [] []
      , span [Attr.style "margin-left" "1em"] [text "Truth: "]
      , input
        [ Attr.type_ "checkbox"
        , Attr.checked model.body.draftTruth
        , Events.onCheck Truth
        ] []
      , br [] []
      , span [Attr.style "margin-left" "1em"] [text "Whole number: "]
      , input
        [ Attr.type_ "text"
        , Attr.value (String.fromInt model.body.draftWholeNumber)
        , Events.onInput WholeNumber
        ] []
      , br [] []
      , text "}", br [] []
      ]
    , p [] [ button [ Events.onClick SendClick ] [ text "Send" ] ]
    ]


viewHistory : Model -> Html Msg
viewHistory model =
  div [] <|
    p [] [text "Messages appear here, latest first:"] ::
    List.map (\e -> p [] [text e]) model.history
   
