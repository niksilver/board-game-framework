-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Json.Encode as Enc
import Json.Decode as Dec
import Maybe
import Random
import Url

import UI
import Element as El
import Element.Background as Background
import Element.Font as Font
import BoardGameFramework as BGF


main : Program BGF.ClientId Model Msg
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
  { key : Nav.Key
  , url : Url.Url
  , draftGameId : String
  , draftMyName : String
  , myId : BGF.ClientId
  , gameId : Maybe BGF.GameId
  , players : Dict BGF.ClientId String
  , error : Maybe BGF.Error
  , connectivity : BGF.Connectivity
  }


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init myId url key =
  let
    fragStr = url.fragment |> Maybe.withDefault ""
    (maybeId, cmd) =
      case BGF.gameId fragStr of
        Ok id ->
          (Just id, openCmd id)
        Err _ ->
          (Nothing, Random.generate GeneratedGameId BGF.idGenerator)
  in
  ( { key = key
    , url = url
    , draftGameId = fragStr
    , draftMyName = ""
    , myId = myId
    , gameId = maybeId
    , players = Dict.singleton myId ""
    , error = Nothing
    , connectivity = BGF.Closed
    }
    , cmd
  )


-- The board game server: connecting and sending


serverURL : String
serverURL = "ws://bgf.pigsaw.org"


openCmd : BGF.GameId -> Cmd Msg
openCmd gameId =
  BGF.Open (serverURL ++ "/g/" ++ (BGF.fromGameId gameId))
  |> BGF.encode bodyEncoder
  |> outgoing


-- Our peer-to-peer messages


type alias Body =
  { id : BGF.ClientId
  , name : String
  }


type alias Envelope = BGF.Envelope Body


bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  Enc.object
  [ ("id" , Enc.string body.id)
  , ("name" , Enc.string body.name)
  ]


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  Dec.map2
    Body
    (Dec.field "id" Dec.string)
    (Dec.field "name" Dec.string)


-- Update the model with a message


type Msg =
  GeneratedGameId BGF.GameId
  | UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | DraftGameIdChange String
  | JoinClick
  | DraftMyNameChange String
  | ConfirmNameClick
  | Received (Result BGF.Error Envelope)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let
    withFragment gameId url =
      { url | fragment = Just (BGF.fromGameId gameId) }
  in
  case msg of
    GeneratedGameId id ->
      let
        url2 = model.url |> withFragment id |> Url.toString
      in
      ( model
      , Nav.pushUrl model.key url2
      )

    UrlRequested req ->
      -- The user has clicked on a link
      case req of
        Browser.Internal url ->
          init model.myId url model.key

        Browser.External url ->
          (model, Nav.load url)

    UrlChanged url ->
      -- URL may have been changed by this app or by the user,
      -- so we can't assume the URL fragment is a good game ID.
      case url.fragment of
        Nothing ->
          -- No fragment in URL, so start from scratch
          ( { model
            | url = url
            , draftGameId = ""
            , gameId = Nothing
            }
          , Random.generate GeneratedGameId BGF.idGenerator
          )

        Just frag ->
          case BGF.gameId frag of
            Err _ ->
              -- Not a valid gameId, so ignore it
              (model, Cmd.none)

            Ok gameId ->
              ( { model
                | url = url
                , draftGameId = gameId |> BGF.fromGameId
                , gameId = Just gameId
                }
              , openCmd gameId
              )


    DraftGameIdChange draftId ->
      ({model | draftGameId = draftId}, Cmd.none)

    JoinClick ->
      let
        url = model.url
        url2 = { url | fragment = Just model.draftGameId }
      in
      ( model
      , Nav.pushUrl model.key (Url.toString url2)
      )

    DraftMyNameChange draftName ->
      ({model | draftMyName = draftName}, Cmd.none)

    ConfirmNameClick ->
      -- We've confirmed our name. Tell our peers.
      ( { model
        | players =
            model.players
            |> Dict.insert model.myId model.draftMyName
        }
      , sendBodyCmd { id = model.myId, name = model.draftMyName }
      )

    Received envRes ->
      case envRes of
        Ok env ->
          { model | error = Nothing }
          |> updateWithEnvelope env

        Err desc ->
          ( { model
            | error = Just desc
            }
          , Cmd.none
          )


sendBodyCmd : Body -> Cmd Msg
sendBodyCmd body =
  BGF.Send body
  |> BGF.encode bodyEncoder
  |> outgoing


updateWithEnvelope : Envelope -> Model -> (Model, Cmd Msg)
updateWithEnvelope env model =
  case env of
    BGF.Welcome w ->
      -- When we're welcomed, we'll get a list of other client IDs.
      -- We'll put them in our players dict with unknown names, even
      -- though the players will send us their names very shortly.
      let
        myName = model.players |> Dict.get w.me |> Maybe.withDefault ""
        players1 = model.players |> Dict.insert model.myId myName
        insert cId dict = dict |> Dict.insert cId ""
      in
      ( { model
        | players = List.foldl insert players1 w.others
        }
      , Cmd.none
      )

    BGF.Peer p ->
      -- A peer will send us their name
      ( { model
        | players =
            model.players |> Dict.insert p.body.id p.body.name
        }
      , Cmd.none
      )

    BGF.Receipt r ->
      -- A receipt will be what we sent, so ignore it
      (model, Cmd.none)

    BGF.Joiner j ->
      -- When a client joins, record their ID and send them who we are
      let
        myName = model.players |> Dict.get model.myId |> Maybe.withDefault ""
      in
      ( { model
        | players =
            model.players |> Dict.insert j.joiner ""
        }
      , sendBodyCmd { id = model.myId, name = myName }
      )

    BGF.Leaver l ->
      -- When a client leaves remove their name from the players dict
      ( { model
        | players = model.players |> Dict.remove l.leaver
        }
      , Cmd.none
      )

    BGF.Connection conn ->
      -- The connection state has changed
      ( { model
        | connectivity = conn
        }
      , Cmd.none
      )


-- Subscriptions and ports


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming decode


decode : Enc.Value -> Msg
decode v =
  BGF.decode bodyDecoder v |> Received


-- View


view : Model -> Browser.Document Msg
view model =
  { title = "Lobby demo"
  , body =
      List.singleton
      <| UI.layout UI.miniPaletteWaterfall.background
      <| El.column [] <|
        [ viewLobbyTop model
        , viewNameSelection model.draftMyName model
        , viewFooter model
        ]
  }


viewLobbyTop : Model -> El.Element Msg
viewLobbyTop model =
  let
    mp = UI.miniPaletteThunderCloud
  in
  El.column
  [ El.padding (UI.scaledInt 2)
  , El.spacing (UI.scaledInt 3)
  , Background.color mp.background
  , Font.color mp.text
  ]
  [ UI.heading "Lobby demo" 3
  , viewJoin model
  ]


viewJoin : Model -> El.Element Msg
viewJoin model =
  let
    mp = UI.miniPaletteThunderCloud
  in
  El.row
  [ El.spacing (UI.scaledInt 3)
  ]
  [ El.column
    [ El.spacing (UI.scaledInt 1)
    , El.alignRight
    ]
    [ El.row
      [ El.spacing (UI.scaledInt 1) ]
      [ UI.inputText
        { onChange = DraftGameIdChange
        , text = model.draftGameId
        , placeholderText = "Game code"
        , label = "The code for this game is"
        , fontScale = 12
        , miniPalette = mp
        }
      , El.text " "
      , UI.button
        { onPress = Just JoinClick
        , enabled = joinEnabled model
        , label = "Join"
        , miniPalette = mp
        }
      ]
    , El.row [El.alignRight]
      [ viewError model |> El.el [El.alignRight]
      , El.text " "
      , viewConnectivity model |> El.el [El.alignRight]
      ]
    ]
    |> El.el [El.width (El.fillPortion 1), El.alignTop]
  , middleBlock
  , El.paragraph
    [ El.width (El.fillPortion 1)
    , El.alignTop
    ]
    [ El.text "Tell others to join you by "
    , El.text "typing the code into their box and hitting Join, or they can "
    , El.text " go to "
    , UI.link
      { url = Url.toString model.url
      , label = El.text (Url.toString model.url)
      }
    , El.text ". "
    ]
  ]


middleBlock : El.Element Msg
middleBlock =
  El.el [El.width (UI.scaledInt 4 |> El.px)] El.none


-- We can enable the Join button if (i) the draft is a valid game ID, and
-- (ii) either we're disconnected or the draft is of a different game ID.
joinEnabled : Model -> Bool
joinEnabled model =
  let
    disconnected = (model.connectivity /= BGF.Opened)
  in
  case model.gameId of
    Just gameId ->
      case BGF.gameId model.draftGameId of
        Ok newGameId ->
          (gameId /= newGameId) || disconnected

        Err _ ->
          False

    Nothing ->
      False


viewConnectivity : Model -> El.Element Msg
viewConnectivity model =
  case model.connectivity of
    BGF.Opened ->
      UI.greenLight "Connected"

    BGF.Connecting ->
      UI.redLight "Connecting"

    BGF.Closed ->
      UI.redLight "Disconnected"


viewNameSelection : String -> Model -> El.Element Msg
viewNameSelection draftMyName model =
  let
    mp = UI.miniPaletteWaterfall
  in
  El.row
  [ El.width El.fill
  , El.padding (UI.scaledInt 2)
  , El.spacing (UI.scaledInt 3)
  , Background.color mp.background
  , Font.color mp.text
  ]
  [ viewMyName draftMyName model
  , middleBlock
  , viewPlayers model
  ]


viewMyName : String -> Model -> El.Element Msg
viewMyName draftMyName model =
  let
    mp = UI.miniPaletteWaterfall
  in
  El.row
  [ El.spacing (UI.scaledInt 1) ]
  [ UI.inputText
    { onChange = DraftMyNameChange
    , text = draftMyName
    , placeholderText = "Enter name"
    , label = "Your name"
    , fontScale = 12
    , miniPalette = mp
    }
  , El.text " "
  , UI.button
    { onPress = Just ConfirmNameClick
    , enabled = goodName draftMyName
    , label = "Confirm"
    , miniPalette = mp
    }
  ]
  |> El.el [El.alignRight]
  |> El.el
    [ El.alignTop
    , El.width (El.fillPortion 1)
    ]


goodName : String -> Bool
goodName name =
  String.length (String.trim name) >= 3


viewPlayers : Model -> El.Element Msg
viewPlayers model =
  let
    players =
      model.players
      |> Dict.toList
      |> List.map
        (\(id, name) ->
          El.text (nicePlayerName model.myId id name)
          |> El.el [El.height (UI.fontSize * 3 // 2 |> El.px)]
        )
      |> El.column [El.centerX]
    heading =
      UI.heading "Players" 2
  in
  El.column
  [ El.centerX
  , El.alignTop
  , El.width (El.fillPortion 1)
  , El.spacing (UI.scaledInt 1)
  ]
  [ heading
  , players
  ]


nicePlayerName : String -> String -> String -> String
nicePlayerName myId id name =
  (if goodName name then name else "Unknown player")
  ++ (if id == myId then " (you)" else "")


viewError : Model -> El.Element Msg
viewError model =
  case model.error of
    Just (BGF.LowLevel desc) ->
        UI.amberLight ("Low level error: " ++ desc)

    Just (BGF.Json err) ->
      let
        desc = Dec.errorToString err
      in
      if String.length desc > 20 then
        UI.amberLight ("JSON error: " ++ (String.left 20 desc) ++ "...")
      else
        UI.amberLight ("JSON error: " ++ desc)

    Nothing ->
      El.none


viewFooter : Model -> El.Element Msg
viewFooter model =
  let
    url = model.url
    baseUrl = { url | fragment = Nothing }
    mp = UI.miniPaletteWaterfall
  in
  UI.link
  { url = Url.toString baseUrl
  , label = El.text "Click here to try a new game"
  }
  |> El.el [El.centerX]
  |> El.el
    [ Font.color mp.text
    , El.width El.fill
    ]
