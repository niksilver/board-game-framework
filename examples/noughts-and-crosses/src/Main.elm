-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Array exposing (Array)
import Bitwise
import Browser
import Browser.Navigation as Nav
import Json.Encode as Enc
import Json.Decode as Dec
import Random
import Url

import Element as El
import Element.Background as Background
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import BoardGameFramework as BGF

import UI
import Images


-- Basic setup


main : Program BGF.ClientId Model Msg
main =
  Browser.application
  { init = init
  , update = update
  , subscriptions = subscriptions
  , onUrlRequest = \req -> Ignore
  , onUrlChange = UrlChanged
  , view = view
  }


-- Main type definitions


type alias Model =
  { url : Url.Url
  , key : Nav.Key
  , myId : BGF.ClientId
  , screen : Screen
  }


type Screen =
  Entrance EntranceState
  | Playing PlayingState


type alias EntranceState =
  { draftGameId : String }


type alias PlayingState =
  { gameId : BGF.GameId
  , seed : Int
  , playerCount : Int
  , moveNumber : Int
  , envNum : Int
  , turn : Mark
  , board : Array (Maybe Mark)
  , winner : Winner
  }


type Mark = XMark | OMark


type Winner = InProgress | WonBy (Maybe Mark)


type Msg =
  UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraftGameId String
  | ConfirmGameId String
  | CellClicked Int
  | Received (Result BGF.Error (BGF.Envelope Body))
  | ClickedPlayAgain
  | Ignore


-- Game connectivity


server : BGF.Server
server = BGF.wsServer "bgf.pigsaw.org"


openCmd : BGF.GameId -> Cmd Msg
openCmd =
  BGF.open outgoing server


sendCmd : Body -> Cmd Msg
sendCmd =
  BGF.send outgoing bodyEncoder


-- Peer-to-peer messages


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  incoming receive


receive : Enc.Value -> Msg
receive v =
  BGF.decode bodyDecoder v |> Received


-- The structure of the messages we'll send between players
type alias Body =
  { moveNumber : Int
  , turn : Mark
  , board : Array (Maybe Mark)
  }


bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  let
    markEnc turn =
      case turn of
        XMark -> Enc.string "X"
        OMark -> Enc.string "O"
    boardMarkEnc piece =
      case piece of
        Just XMark -> Enc.string "X"
        Just OMark -> Enc.string "O"
        Nothing -> Enc.string " "
    boardEnc =
      Enc.array boardMarkEnc
  in
    Enc.object
    [ ("moveNumber", Enc.int body.moveNumber)
    , ("turn", markEnc body.turn)
    , ("board", boardEnc body.board)
    ]


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  let
    stringToMark s =
      case s of
        "X" -> XMark
        _ -> OMark
    stringToBoardMark s =
      case s of
        "X" -> Just XMark
        "O" -> Just OMark
        _ -> Nothing
    markDecoder = Dec.map stringToMark Dec.string
    boardMarkDecoder = Dec.map stringToBoardMark Dec.string
    boardDecoder = Dec.array boardMarkDecoder
  in
  Dec.map3
    Body
    (Dec.field "moveNumber" Dec.int)
    (Dec.field "turn" markDecoder)
    (Dec.field "board" boardDecoder)


-- Initial state


init : BGF.ClientId -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init myId url key =
  let
    (screen, cmd) = initialScreen url key
  in
  ( { url = url
    , key = key
    , myId = myId
    , screen = screen
    }
  , cmd
  )


initialScreen : Url.Url -> Nav.Key -> (Screen, Cmd Msg)
initialScreen url key =
  let
    frag = url.fragment |> Maybe.withDefault ""
  in
  case BGF.gameId frag of
    Ok gameId ->
      ( Playing
        { gameId = gameId
        , seed = makeSeed gameId 0
        , playerCount = 1
        , moveNumber = 0
        , envNum = 2^31-1
        , turn = XMark
        , board = cleanBoard
        , winner = InProgress
        }
      , openCmd gameId
      )

    Err _ ->
      case url.fragment of
        Just str ->
          ( Entrance { draftGameId = frag }
          , Cmd.none
          )

        Nothing ->
          ( Entrance { draftGameId = frag }
          , Random.generate GeneratedGameId BGF.idGenerator
          )


-- Create a randomish seed for a seed... almost certainly not a great algorithm
makeSeed : BGF.GameId -> Int -> Int
makeSeed gameId moveNumber =
  let
    extend chr i =
      Char.toCode chr
      |> (*) 2
      |> Bitwise.xor i
  in
  gameId
  |> BGF.fromGameId
  |> String.foldl extend moveNumber


-- Updating the model


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UrlChanged url ->
      let
        (screen, cmd) = initialScreen url model.key
      in
      ( { model | screen = screen }
      , cmd
      )

    GeneratedGameId gameId ->
      ( model |> setDraftGameId (BGF.fromGameId gameId)
      , Cmd.none
      )

    NewDraftGameId draft ->
      case model.screen of
        Entrance _ ->
          ( model |> setDraftGameId draft
          , Cmd.none
          )

        Playing _ ->
          (model, Cmd.none)

    ConfirmGameId id ->
      ( model
      , id |> setFragment model.url |> Url.toString |> Nav.pushUrl model.key
      )

    CellClicked i ->
      case model.screen of
        Playing state ->
          let
            -- We set the envNum to a large int, because we'll only really
            -- trust the move when it comes back as a receipt... or perhaps
            -- is beaten by a slightly earlier peer message. So we'll pick
            -- up the envelope num from whichever envelope comes in first.
            board2 = Array.set i (Just state.turn) state.board
            state2 =
              { state
              | moveNumber = state.moveNumber + 1
              , envNum = 2^31-1
              , turn = next state.turn
              , board = board2
              , winner = winner board2
              }
          in
          ( { model | screen = Playing state2 }
          , sendCmd
            { moveNumber = state2.moveNumber
            , turn = state2.turn
            , board = state2.board
            }
          )

        Entrance _ ->
          (model, Cmd.none)

    Received envRes ->
      case model.screen of
        Entrance _ ->
          (model, Cmd.none)

        Playing state ->
          case envRes of
            Ok env ->
              let
                (state2, cmd) = updateWithEnvelope env state
              in
              ( { model | screen = Playing state2 }
              , cmd
              )

            Err desc ->
              let
                _ = Debug.log "Error" desc
              in
              (model, Cmd.none)

    ClickedPlayAgain ->
      case model.screen of
        Playing state ->
          let
            state2 =
              { state
              | moveNumber = state.moveNumber + 1
              , seed = makeSeed state.gameId state.moveNumber
              , envNum = 2^31-1
              , board = cleanBoard
              , winner = InProgress
              }
          in
          ( { model | screen = Playing state2 }
          , sendCmd
            { moveNumber = state2.moveNumber
            , turn = state2.turn
            , board = state2.board
            }
          )

        Entrance _ ->
          (model, Cmd.none)

    Ignore ->
      (model, Cmd.none)


setDraftGameId : String -> Model -> Model
setDraftGameId draft model =
  { model
  | screen = Entrance { draftGameId = draft  }
  }



setFragment : Url.Url -> String -> Url.Url
setFragment url fragment =
  { url | fragment = Just fragment }


setUrl : Url.Url -> Model -> Model
setUrl url model =
  { model | url = url }


-- Game mechanics


cleanBoard : Array (Maybe Mark)
cleanBoard =
  Array.repeat 9 Nothing


next : Mark -> Mark
next turn =
  case turn of
    XMark -> OMark
    OMark -> XMark


winner : Array (Maybe Mark) -> Winner
winner board =
  let
    wonBy =
      wins 0 1 2 board
      |> orElse (wins 3 4 5 board)
      |> orElse (wins 6 7 8 board)
      |> orElse (wins 0 3 6 board)
      |> orElse (wins 1 4 7 board)
      |> orElse (wins 2 5 8 board)
      |> orElse (wins 0 4 8 board)
      |> orElse (wins 2 4 6 board)
  in
  case wonBy of
    Just mark ->
      WonBy (Just mark)

    Nothing ->
      if markCount board == 9 then
        WonBy Nothing
      else
        InProgress


wins : Int -> Int -> Int -> Array (Maybe Mark) -> Maybe Mark
wins i j k board =
  let
    a = Array.get i board
    b = Array.get j board
    c = Array.get k board
  in
  case a of
    Just (Just mark) ->
      if a == b && b == c then
        Just mark
      else
        Nothing

    _ ->
      Nothing


-- Return mY if it's Just something, or else return mX. Used like this:
--     mX |> orElse mY
-- Kind of the inverse of andThen.
orElse : Maybe a -> Maybe a -> Maybe a
orElse mY mX =
  case mX of
    Just _ ->
      mX

    Nothing ->
      mY


-- Count the number of marks in the array
markCount : Array (Maybe Mark) -> Int
markCount board =
  let
    add mMark count =
      case mMark of
        Just _ -> count + 1
        Nothing -> count
  in
  Array.foldl add 0 board


-- Responding to incoming information


updateWithEnvelope : BGF.Envelope Body -> PlayingState -> (PlayingState, Cmd Msg)
updateWithEnvelope env state =
  case env of
    BGF.Welcome w ->
      -- When we're welcomed we can count all the players in the game
      let
        pCount = 1 + List.length w.others
      in
      ( { state | playerCount = pCount }
      , Cmd.none
      )

    BGF.Receipt r ->
      ( updateBoard r.num r.body state
      , Cmd.none
      )

    BGF.Peer p ->
      ( updateBoard p.num p.body state
      , Cmd.none
      )

    BGF.Joiner j ->
      -- When someone joins we need to tell them the state of board
      let
        pCount = 1 + List.length j.to
      in
      ( { state | playerCount = pCount }
      , sendCmd
        { moveNumber = state.moveNumber
        , turn = state.turn
        , board = state.board
        }
      )

    BGF.Leaver l ->
      -- When someone leaves we need to update ourselves with who's left
      let
        pCount = List.length l.to
      in
      ( { state | playerCount = pCount }
      , Cmd.none
      )

    BGF.Connection conn ->
      (state, Cmd.none)


-- We will only update the playing state with the given board if it
-- is a higher move number, or if it's the same move number
-- and a lower envelope num.
updateBoard : Int -> Body -> PlayingState -> PlayingState
updateBoard envNum body state =
  let
    bodyHasHigherMoveNumber = body.moveNumber > state.moveNumber
    sameMoveNumbers = body.moveNumber == state.moveNumber
    bodyHasLowerEnvNum = envNum < state.envNum
  in
  if bodyHasHigherMoveNumber || (sameMoveNumbers && bodyHasLowerEnvNum) then
    { state
    | moveNumber = body.moveNumber
    , envNum = envNum
    , turn = body.turn
    , board = body.board
    , winner = winner body.board
    }
  else
    state


-- View


borderWidth = 20
cellWidth = 200
gridColour = El.rgb 0.8 0.1 1.0
cellColour = El.rgb 0.3 0.3 0.3


view : Model -> Browser.Document Msg
view model =
  { title = "Noughts and crosses"
  , body =
    List.singleton
      <| UI.layout UI.miniPaletteThunderCloud
      <| case model.screen of
        Entrance draftGameId ->
          viewEntrance draftGameId

        Playing state ->
          viewPlay state
  }


viewEntrance : EntranceState -> El.Element Msg
viewEntrance state =
  let
    enabled =
      case state.draftGameId |> BGF.gameId of
        Ok _ ->
          True
        Err _ ->
          False
  in
  El.paragraph
  []
  [ UI.inputText
    { onChange = NewDraftGameId
    , text = state.draftGameId
    , placeholderText = "Game ID"
    , label = "Game ID"
    , fontScale = 12
    , miniPalette = UI.miniPaletteThunderCloud
    }
  , UI.button
    { onPress = Just (ConfirmGameId state.draftGameId)
    , label = "Go"
    , enabled = enabled
    , miniPalette = UI.miniPaletteThunderCloud
    }
  ]


viewPlay : PlayingState -> El.Element Msg
viewPlay state =
  El.column []
  [ viewGrid state
  , viewWhoseTurnOrWinner state
  , viewPlayerCount state
  ]


viewGrid : PlayingState -> El.Element Msg
viewGrid state =
  El.column []
  [ viewGridBar
  , viewRow 0 state
  , viewGridBar
  , viewRow 3 state
  , viewGridBar
  , viewRow 6 state
  , viewGridBar
  ]


viewGridBar : El.Element Msg
viewGridBar =
  El.row
  [ El.width (4*borderWidth + 3*cellWidth |> El.px)
  , Background.color gridColour
  ]
  [ El.text ""
  ]


viewRow : Int -> PlayingState -> El.Element Msg
viewRow i state =
  El.row
  [ El.paddingEach
    { top = 0
    , left = borderWidth
    , bottom = 0
    , right = borderWidth
    }
  , El.spacing borderWidth
  , Background.color gridColour
  ]
  [ viewCell (i + 0) state
  , viewCell (i + 1) state
  , viewCell (i + 2) state
  ]


viewCell : Int -> PlayingState -> El.Element Msg
viewCell i state =
  case Array.get i state.board |> Maybe.withDefault Nothing of
    Nothing ->
      viewClickableCell i state

    Just mark ->
      let
        seed = state.seed + i |> Random.initialSeed
        ((ref, _), desc) =
          case mark of
            XMark -> (Images.stepX seed, "X")
            OMark -> (Images.stepO seed, "O")
      in
      El.image [ El.width (El.px cellWidth) , El.height (El.px cellWidth)]
      { src = ref.src
      , description = desc
      }


viewClickableCell : Int -> PlayingState -> El.Element Msg
viewClickableCell i state =
  let
    cellEvent =
      case state.winner of
        InProgress ->
          [Events.onClick <| CellClicked i]

        WonBy _ ->
          []
  in
  El.text "[_]"
  |> El.el
    [ El.width (El.px cellWidth)
    , El.height (El.px cellWidth)
    , Background.color cellColour
    ]
  |> El.el cellEvent


viewWhoseTurnOrWinner : PlayingState -> El.Element Msg
viewWhoseTurnOrWinner state =
  case state.winner of
    WonBy mMark ->
      viewWinner mMark

    InProgress ->
      case state.turn of
        XMark ->
          El.text "X to play"

        OMark ->
          El.text "O to play"


viewWinner : Maybe Mark -> El.Element Msg
viewWinner mMark =
  let
    winText =
      case mMark of
        Just XMark ->
          "X wins the game! "

        Just OMark ->
          "O wins the game! "

        Nothing ->
          "It's a draw! "
  in
  El.paragraph []
  [ El.text winText
  , El.text "Click to play again"
    |> El.el [ Font.underline ]
    |> El.el [ Events.onClick <| ClickedPlayAgain ]
  ]


viewPlayerCount : PlayingState -> El.Element Msg
viewPlayerCount state =
  case state.playerCount of
    1 ->
      El.text "There are no other players online"

    2 ->
      El.text "There is one other player online"

    p ->
      El.text <| "There are " ++ (String.fromInt p) ++ " other players online"
