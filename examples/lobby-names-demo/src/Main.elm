-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Encode as Enc
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
  , draftGameID: String
  , key: Nav.Key
  , url: Url.Url
  , myID : Maybe String
  , error : Maybe String
  }


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  case BGF.goodGameIDMaybe url.fragment of
    Just id ->
      ( { gameID = Just id
        , draftGameID = id
        , key = key
        , url = url
        , myID = Nothing
        , error = Nothing
        }
        , Cmd.none
      )

    Nothing ->
      ( { gameID = Nothing
        , draftGameID = ""
        , key = key
        , url = url
        , myID = Nothing
        , error = Nothing
        }
        , Random.generate GameID BGF.idGenerator
      )


-- Update the model with a message


type Msg =
  GameID String
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | DraftGameIDChange String
  | JoinClick
  | Received (Result String BGF.Envelope)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GameID id ->
      updateWithGameID id model

    UrlRequested req ->
      (model, Cmd.none)

    UrlChanged url ->
      (model, Cmd.none)

    DraftGameIDChange draftID ->
      ({model | draftGameID = draftID}, Cmd.none)

    JoinClick ->
      updateWithGameID model.draftGameID model

    Received envRes ->
      case envRes of
        Ok env ->
          updateWithEnvelope env model

        Err desc ->
          ({ model | error = Just desc }, Cmd.none)


updateWithGameID : String -> Model -> (Model, Cmd Msg)
updateWithGameID id model =
  let
    url = model.url
    url2 = { url | fragment = Just id }
  in
  ( { model
    | gameID = Just id
    , draftGameID = id
    , url = url2
    }
  , Cmd.batch
    [ Nav.pushUrl model.key (Url.toString url2)
    , BGF.Open (serverURL ++ "/g/" ++ id) |> BGF.encode |> outgoing
    ]
  )


updateWithEnvelope : BGF.Envelope -> Model -> (Model, Cmd Msg)
updateWithEnvelope env model =
  case env of
    BGF.Welcome w ->
      ({ model | myID = Just w.me }, Cmd.none)


-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming decodeEnvelope


-- Ports to communicate with the framework


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


decodeEnvelope : Enc.Value -> Msg
decodeEnvelope v =
  BGF.decodeEnvelope v |> Received


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Lobby"
  , body =
      List.concat
      [ viewJoin model
      , viewPlayers model
      , viewError model
      ]
  }


viewJoin : Model -> List (Html Msg)
viewJoin model =
  [ p []
    [ text "This is the code for this game. Tell others to join you by "
    , text "typing the code into their box and hitting Join, or they can "
    , text " go to "
    , a [Attr.href <| Url.toString model.url]
      [ text <| Url.toString model.url ], text ". "
    , text "You can join their game by typing their code into the box and "
    , text "hitting Join, or by going to the address they give you."
    ]
  , input
    [ Attr.type_ "text", Attr.size 30
    , Attr.value model.draftGameID
    , Events.onInput DraftGameIDChange
    ]
    []
  , button
    [ Attr.disabled <| not(BGF.isGoodGameID model.draftGameID)
    , Events.onClick JoinClick
    ]
    [text "Join"]
  ]


viewPlayers : Model -> List (Html Msg)
viewPlayers model =
  case model.myID of
    Just id ->
      [ p [] [ "Your ID: " ++ id |> text ]
      ]

    Nothing ->
      []


viewError : Model -> List (Html Msg)
viewError model =
  case model.error of
    Just desc ->
      [ p [] [ "Error: " ++ desc |> text ]
      ]

    Nothing ->
      []
