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
  { gameId: Maybe String
  , draftGameId: String
  , key: Nav.Key
  , url: Url.Url
  , myId : Maybe String
  , draftMyName : String
  , myName : Maybe String
  , error : Maybe String
  }


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  case BGF.goodGameIdMaybe url.fragment of
    Just id ->
      ( { gameId = Just id
        , draftGameId = id
        , key = key
        , url = url
        , myId = Nothing
        , draftMyName = ""
        , myName = Nothing
        , error = Nothing
        }
        , Cmd.none
      )

    Nothing ->
      ( { gameId = Nothing
        , draftGameId = ""
        , key = key
        , url = url
        , myId = Nothing
        , draftMyName = ""
        , myName = Nothing
        , error = Nothing
        }
        , Random.generate GameId BGF.idGenerator
      )


-- Update the model with a message


type Msg =
  GameId String
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | DraftGameIdChange String
  | JoinClick
  | DraftMyNameChange String
  | ConfirmNameClick
  | Received (Result String BGF.Envelope)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GameId id ->
      updateWithGameId id model

    UrlRequested req ->
      let
        _ = Debug.log "URL requested " (Debug.toString req)
      in
      (model, Cmd.none)

    UrlChanged url ->
      let
        _ = Debug.log "URL changed " (Url.toString url)
      in
      (model, Cmd.none)

    DraftGameIdChange draftId ->
      ({model | draftGameId = draftId}, Cmd.none)

    JoinClick ->
      updateWithGameId model.draftGameId model

    DraftMyNameChange draftName ->
      ({model | draftMyName = draftName}, Cmd.none)

    ConfirmNameClick ->
      ({model | myName = String.trim model.draftMyName |> Just}, Cmd.none)

    Received envRes ->
      case envRes of
        Ok env ->
          updateWithEnvelope env model

        Err desc ->
          ({ model | error = Just desc }, Cmd.none)


updateWithGameId : String -> Model -> (Model, Cmd Msg)
updateWithGameId id model =
  let
    url = model.url
    url2 = { url | fragment = Just id }
  in
  ( { model
    | gameId = Just id
    , draftGameId = id
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
      ({ model | myId = Just w.me }, Cmd.none)


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
    , Attr.value model.draftGameId
    , Events.onInput DraftGameIdChange
    ] []
  , text " "
  , button
    [ Attr.disabled <| not(BGF.isGoodGameId model.draftGameId)
    , Events.onClick JoinClick
    ]
    [text "Join"]
  ]


viewPlayers : Model -> List (Html Msg)
viewPlayers model =
  case model.myId of
    Just id ->
      [ p []
        [ text "Your name: "
        , input
          [ Attr.type_ "text", Attr.size 15
          , Attr.value model.draftMyName
          , Events.onInput DraftMyNameChange
          ] []
        , text " "
        , button
          [ Attr.disabled <| not(goodName model.draftMyName)
          , Events.onClick ConfirmNameClick
          ]
          [ text "Confirm" ]
        , text " "
        , Maybe.withDefault "" model.myName |> text
        ]
      ]

    Nothing ->
      []


goodName : String -> Bool
goodName name =
  String.length (String.trim name) >= 3


viewError : Model -> List (Html Msg)
viewError model =
  case model.error of
    Just desc ->
      [ p [] [ "Error: " ++ desc |> text ]
      ]

    Nothing ->
      []
