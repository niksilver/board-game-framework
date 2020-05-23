-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Encode as Enc
import Json.Decode as Dec
import Maybe
import Random
import Tuple
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


type alias Model =
  { gameId: Maybe String
  , draftGameId: String
  , key: Nav.Key
  , url: Url.Url
  , draftMyName : String
  , error : Maybe String
  , game : GameState
  }


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  case BGF.goodGameIdMaybe url.fragment of
    Just id ->
      ( { gameId = Just (id |> Debug.log "Init with id")
        , draftGameId = id
        , key = key
        , url = url
        , draftMyName = ""
        , error = Nothing
        , game = initialGameState
        }
        , openCmd id
      )

    Nothing ->
      ( { gameId = Nothing |> Debug.log "Init with nothing"
        , draftGameId = ""
        , key = key
        , url = url
        , draftMyName = ""
        , error = Nothing
        , game = initialGameState
        }
        , Random.generate GeneratedGameId BGF.idGenerator
      )


-- The board game server: connecting and sending


serverURL : String
serverURL = "wss://board-game-framework.nw.r.appspot.com"


openCmd : String -> Cmd Msg
openCmd gameId =
  BGF.Open (serverURL ++ "/g/" ++ gameId)
  |> BGF.encode bodyEncoder
  |> outgoing


-- State of the game


-- The game is just a bunch of players (including us), each with a name
type alias GameState =
  { myId : Maybe String
  , players : Dict String String
  }


initialGameState : GameState
initialGameState =
  { myId = Nothing
  , players = Dict.empty
  }


-- Our peer-to-peer messages


type alias Body =
  { myId: String
  , myName: String
  }


type alias Envelope = BGF.Envelope Body


bodyEncoder : Body -> Enc.Value
bodyEncoder {myId, myName} =
  Enc.object
  [ ("myId", Enc.string myId)
  , ("myName", Enc.string myName)
  ]


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  Dec.map2 Body
    (Dec.field "myId" Dec.string)
    (Dec.field "myName" Dec.string)


-- Update the model with a message


type Msg =
  GeneratedGameId String
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | DraftGameIdChange String
  | JoinClick
  | DraftMyNameChange String
  | ConfirmNameClick
  | Received (Result String Envelope)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GeneratedGameId id ->
      updateWithGameId id model

    UrlRequested req ->
      (model, Cmd.none)

    UrlChanged url ->
      -- URL may have been changed by this app or by the user.
      -- So we can't assume the URL fragment is a good game ID.
      let
        _ = Debug.log "URL changed " (Url.toString url)
        frag = url.fragment
        gameId = BGF.goodGameIdMaybe frag
        cmd =
          case gameId of
            Just id ->
              openCmd id
            Nothing ->
              Cmd.none
      in
      ( { model
        | gameId = frag
        , draftGameId = Maybe.withDefault "" frag
        , url = url
        }
      , cmd
      )

    DraftGameIdChange draftId ->
      ({model | draftGameId = draftId}, Cmd.none)

    JoinClick ->
      updateWithGameId model.draftGameId model

    DraftMyNameChange draftName ->
      ({model | draftMyName = draftName}, Cmd.none)

    ConfirmNameClick ->
      -- If we've confirmed our name, update our game state and tell our peers
      case model.game.myId of
        Just id ->
          let
            myName = String.trim model.draftMyName
            game = model.game
            players = game.players |> Dict.insert myName id
            game2 = { game | players = players }
            body = { myId = id, myName = myName }
          in
          ( { model | game = game2 }
          , BGF.Send body |> BGF.encode bodyEncoder |> outgoing
          )

        Nothing ->
          (model, Cmd.none)

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
  ( model
  , Nav.pushUrl model.key (Url.toString url2)
  )


updateWithEnvelope : Envelope -> Model -> (Model, Cmd Msg)
updateWithEnvelope env model =
  case env of
    BGF.Welcome w ->
      let
        game = model.game
        game2 = { game | myId = Just w.me }
      in
      ({ model | game = game2 }, Cmd.none)

    BGF.Peer p ->
      let
        _ = Debug.log "Body from peer: " p.body
      in
      (model, Cmd.none)


-- Subscriptions and ports


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming decodeEnvelope


decodeEnvelope : Enc.Value -> Msg
decodeEnvelope v =
  BGF.decodeEnvelope bodyDecoder v |> Received


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
  case model.game.myId of
    Just id ->
      let
        myName = Dict.get id model.game.players
      in
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
        , Maybe.withDefault "" myName |> text
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
