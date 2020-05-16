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


main =
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view
    }


-- Model and basic initialisation


serverURL : String
serverURL = "wss://board-game-framework.nw.r.appspot.com"


type alias Model =
  { draftGameID: String
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
  ( { draftGameID = "sample-game-id"
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
  GameID String
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
    GameID id ->
      ( { model | draftGameID = id }
      , Cmd.none
      )

    OpenClick ->
      (model, Open model.draftGameID |> encode |> outgoing)

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
        n = String.toInt nStr |> Maybe.withDefault model.body.draftWholeNumber
      in
      ( { model | body = { body | draftWholeNumber = n }}
      , Cmd.none
      )

    SendClick ->
      (model, Send model.body |> encode |> outgoing)

    CloseClick ->
      (model, Close |> encode |> outgoing)

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


type Request a =
  Open String
  | Send Body
  | Close


-- Turn an application request into something that can be sent out
-- through a port

encode : Request String -> Enc.Value
encode req =
  case req of
    Open gameID ->
      Enc.object
        [ ("instruction", Enc.string "Open")
        , ("url", "wss://board-game-framework.nw.r.appspot.com/g/" ++ gameID |> Enc.string)
        ]

    Send body ->
      Enc.object
        [ ("instruction", Enc.string "Send")
        , ("body"
          , Enc.object
            [ ("words", Enc.string body.draftWords)
            , ("truth", Enc.bool body.draftTruth)
            , ("wholenumber", Enc.int body.draftWholeNumber)
            ]
          )
        ]

    Close ->
      Enc.object
        [ ("instruction", Enc.string "Close")
        ]

-- Turn something that's come in from a port into a message we can
-- do something about.

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
      , input
        [ Attr.id "gameid"
      , Attr.type_ "text"
        , Attr.value model.draftGameID
        , Events.onInput GameID
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
    p [] [text "Application messages appear here, latest first:"] ::
    List.map (\e -> p [] [text e]) model.history
   
