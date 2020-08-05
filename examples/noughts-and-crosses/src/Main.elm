-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


port module Main exposing (..)


import Array exposing (Array)
import Bitwise
import Browser
import Browser.Events as BEvents
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


main : Program Enc.Value Model Msg
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
  , width : Int
  , screen : Screen
  }


type Screen =
  Entrance EntranceState
  | Playing PlayingState


type alias EntranceState =
  { draftGameId : String }


type alias PlayingState =
  { gameId : BGF.GameId
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
  | Resized Int
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


-- Peer-to-peer messages (plus browser resizing)


port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
  [ incoming receive
  , BEvents.onResize resize
  ]


receive : Enc.Value -> Msg
receive v =
  BGF.decode bodyDecoder v |> Received


resize : Int -> Int -> Msg
resize width _ =
  Resized width


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


init : Enc.Value -> Url.Url -> Nav.Key -> (Model, Cmd Msg)
init v url key =
  let
    (screen, cmd) = initialScreen url key
    flags = decodeFlags v
  in
  ( { url = url
    , key = key
    , myId = flags.myId
    , width = flags.width
    , screen = screen
    }
  , cmd
  )


type alias Flags =
  { width : Int
  , myId : String
  }


flagsDecoder : Dec.Decoder Flags
flagsDecoder =
  Dec.map2
    Flags
    (Dec.field "width" Dec.int)
    (Dec.field "myId" Dec.string)


decodeFlags : Enc.Value -> Flags
decodeFlags v =
  Dec.decodeValue flagsDecoder v
  |> Result.withDefault { width = 1000, myId = "Unknown" }


initialScreen : Url.Url -> Nav.Key -> (Screen, Cmd Msg)
initialScreen url key =
  let
    frag = url.fragment |> Maybe.withDefault ""
  in
  case BGF.gameId frag of
    Ok gameId ->
      ( Playing
        { gameId = gameId
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


-- Create a randomish seed for a seed... almost certainly not a great
-- algorithm. gameOffset is a number that should be vary for each successive
-- game with the same game ID, but constant throughout out each game. This
-- is to ensure the images are different for successive games, but remain
-- constant within a game.
makeSeed : BGF.GameId -> Int -> Int
makeSeed gameId gameOffset =
  let
    extend chr i =
      Char.toCode chr
      |> (*) 2
      |> Bitwise.xor i
  in
  gameId
  |> BGF.fromGameId
  |> String.foldl extend gameOffset


-- Make a number that points us to a Ref for an X or O image
makeRefInt : PlayingState -> Int -> Int
makeRefInt state cellNum =
  let
    gameOffset = state.moveNumber - (markCount state.board)
  in
  makeSeed state.gameId gameOffset
  |> (+) (cellNum * (gameOffset + 1))
  |> abs


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

    Resized width ->
      ( { model
        | width = width
        }
      , Cmd.none
      )

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
gridColour = El.rgba 0.4 0.4 0.4 0.5
cellColour = El.rgba 0.5 0 0 0.5


view : Model -> Browser.Document Msg
view model =
  -- Background by Mike Maguire on Flickr
  -- https://www.flickr.com/photos/mikespeaks/39023133891/
  { title = "Noughts and crosses"
  , body =
    List.singleton
      <| El.layout
        [ El.padding (UI.scaledInt 2)
        , Font.size UI.fontSize
        , Background.image "images/background.jpg"
        ]
      <| case model.screen of
        Entrance draftGameId ->
          viewEntrance draftGameId

        Playing state ->
          viewPlay state model.width
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
    , miniPalette = UI.miniPaletteBlack
    }
  , UI.button
    { onPress = Just (ConfirmGameId state.draftGameId)
    , label = "Go"
    , enabled = enabled
    , miniPalette = UI.miniPaletteBlack
    }
  ]


viewPlay : PlayingState -> Int -> El.Element Msg
viewPlay state width =
  if width <= 1000 then
    El.column []
    [ viewWhoseTurnOrWinner state
    , viewGrid state
    , viewPlayerCount state
    ]
  else
    let
      stickerPad =
        El.el
        [ El.paddingEach { top = 100, left = 30, right = 0, bottom = 0 }
        ]
    in
    El.row [ El.width El.fill ]
    [ viewGrid state
    , El.column
      [ El.width El.fill
      , El.alignTop
      ]
      [ viewWhoseTurnOrWinner state |> stickerPad
      , viewPlayerCount state |> stickerPad
      ]
    ]


viewGrid : PlayingState -> El.Element Msg
viewGrid state =
  El.column []
  [ viewHBar
  , viewRow 0 state
  , viewHBar
  , viewRow 3 state
  , viewHBar
  , viewRow 6 state
  , viewHBar
  ]


viewHBar : El.Element Msg
viewHBar =
  El.row
  [ El.width (4*borderWidth + 3*cellWidth |> El.px)
  , Background.color gridColour
  ]
  [ El.text ""
  ]


viewVBar : El.Element Msg
viewVBar =
  El.row
  [ El.width (borderWidth |> El.px)
  , El.height (cellWidth |> El.px)
  , Background.color gridColour
  ]
  [ El.text ""
  ]


viewRow : Int -> PlayingState -> El.Element Msg
viewRow i state =
  El.row []
  [ viewVBar
  , viewCell (i + 0) state
  , viewVBar
  , viewCell (i + 1) state
  , viewVBar
  , viewCell (i + 2) state
  , viewVBar
  ]


viewCell : Int -> PlayingState -> El.Element Msg
viewCell i state =
  case Array.get i state.board |> Maybe.withDefault Nothing of
    Nothing ->
      viewClickableCell i state

    Just mark ->
      let
        refNum = makeRefInt state i
        (ref, desc) =
          case mark of
            XMark -> (Images.xRef refNum, "X")
            OMark -> (Images.oRef refNum, "O")
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
          UI.biggerStickerText "X to play"

        OMark ->
          UI.biggerStickerText "O to play"


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
  El.row [ El.spacing 30 ]
  [ UI.biggerStickerText winText
  , El.text "Click to play again"
    |> El.el [ El.pointer, Font.underline ]
    |> El.el [ Events.onClick <| ClickedPlayAgain ]
    |> UI.sticker
  ]


viewPlayerCount : PlayingState -> El.Element Msg
viewPlayerCount state =
  case state.playerCount of
    1 ->
      UI.stickerText "There are no other players online"

    2 ->
      UI.stickerText "There is one other player online"

    p ->
      "There are " ++ (String.fromInt p) ++ " other players online"
      |> UI.stickerText
