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
  { gameId : Maybe String
  , draftGameId : String
  , key : Nav.Key
  , url : Url.Url
  , myId : Maybe String
  , draftMyName : String
  , error : Maybe String
  , players : Dict String String
  }


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init _ url key =
  case BGF.goodGameIdMaybe url.fragment of
    Just id ->
      ( { gameId = Just (id |> Debug.log "Init with id")
        , draftGameId = id
        , key = key
        , url = url
        , myId = Nothing
        , draftMyName = ""
        , error = Nothing
        , players = Dict.empty
        }
        , openCmd id
      )

    Nothing ->
      ( { gameId = Nothing |> Debug.log "Init with nothing"
        , draftGameId = ""
        , key = key
        , url = url
        , myId = Nothing
        , draftMyName = ""
        , error = Nothing
        , players = Dict.empty
        }
        , Random.generate GeneratedGameId BGF.idGenerator
      )


-- Whenever we change the game ID we need to empty out the game state
newGameId : Maybe String -> Model -> Model
newGameId gameId model =
  if gameId == model.gameId then
    model
  else
    { model
    | gameId = gameId
    , players = Dict.empty
    }


-- The board game server: connecting and sending


serverURL : String
serverURL = "wss://board-game-framework.nw.r.appspot.com"


openCmd : String -> Cmd Msg
openCmd gameId =
  BGF.Open (serverURL ++ "/g/" ++ gameId)
  |> BGF.encode bodyEncoder
  |> outgoing


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
        goodGameId = BGF.goodGameIdMaybe frag
        cmd =
          case goodGameId of
            Just id ->
              openCmd id
            Nothing ->
              Cmd.none
      in
      ( { model
        | draftGameId = Maybe.withDefault "" frag
        , url = url
        }
        |> newGameId frag
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
      case model.myId of
        Just id ->
          let
            myName = String.trim model.draftMyName
            players = model.players |> Dict.insert id myName
          in
          ( { model | players = players }
          , sendMyNameCmd id myName
          )

        Nothing ->
          (model, Cmd.none)

    Received envRes ->
      case envRes of
        Ok env ->
          updateWithEnvelope env model

        Err desc ->
          ({ model | error = Just desc }, Cmd.none)


sendMyNameCmd : String -> String -> Cmd Msg
sendMyNameCmd myId myName =
  BGF.Send { myId = myId, myName = myName }
  |> BGF.encode bodyEncoder
  |> outgoing


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
      -- When we're welcomed, note the client ID we've been given
      -- and record it in our player table.
      let
        _ = Debug.log "Got welcome" w
        players = model.players |> Dict.insert w.me ""
      in
      ( { model
        | myId = Just w.me
        , players = players
        }
      , Cmd.none)

    BGF.Peer p ->
      -- A peer will send us their client ID and name
      let
        _ = Debug.log "Got peer" p
        players = model.players |> Dict.insert p.body.myId p.body.myName
      in
      ({ model | players = players }, Cmd.none)

    BGF.Joiner j ->
      -- When a client joins, (a) record their ID, and (b) tell them our name
      let
        _ = Debug.log "Got joiner" j
        players = model.players |> Dict.insert j.joiner ""
      in
        case model.myId of
          Just id ->
            let
              myName = players |> Dict.get id |> Maybe.withDefault ""
            in
            ( { model | players = players }
            , sendMyNameCmd id myName
            )

          Nothing ->
            ( { model | players = players }
            , Cmd.none
            )



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
      , viewMyName model
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


viewMyName : Model -> List (Html Msg)
viewMyName model =
  case model.myId of
    Just id ->
      let
        myName = Dict.get id model.players
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
        ]
      ]

    Nothing ->
      []


goodName : String -> Bool
goodName name =
  String.length (String.trim name) >= 3


viewPlayers : Model -> List (Html Msg)
viewPlayers model =
  model.players
  |> Dict.toList
  |> List.map
    (\(id, name) ->
      nicePlayerName model.myId id name
      |> text
      |> List.singleton
      |> p []
    )


nicePlayerName : Maybe String -> String -> String -> String
nicePlayerName myId id name =
  (if goodName name then name else "Unknown player")
  ++ (if Just id == myId then " (you)" else "")


viewError : Model -> List (Html Msg)
viewError model =
  case model.error of
    Just desc ->
      [ p [] [ "Error: " ++ desc |> text ]
      ]

    Nothing ->
      []
