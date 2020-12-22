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
import BoardGameFramework.Lobby as Lobby exposing (Lobby)

import UI
import Marks exposing (Mark(..))
import Images


-- Basic setup


main : Program Enc.Value Model Msg
main =
  Browser.application
  { init = init
  , update = update
  , subscriptions = subscriptions
  , onUrlRequest = Lobby.urlRequested ToLobby
  , onUrlChange = Lobby.urlChanged ToLobby
  , view = view
  }


-- Main type definitions


type alias Model =
  { width : Int
  , lobby : Lobby Msg PlayingState
  , playing : PlayingState
  }


type PlayingState =
  InLobby
  | InGame GameState


type alias GameState =
  { gameId : BGF.GameId
  , connectivity : BGF.Connectivity
  , playerCount : Int
  , moveNumber : Int
  , envNum : Int
  , turn : Mark
  , board : Array (Maybe Mark)
  , winner : Winner
  , refX : (Images.Ref, String)
  }


type Winner = InProgress | WonBy (Maybe Mark)


type Msg =
  ToLobby Lobby.Msg
  | Resized Int
  | CellClicked Int
  | Received (Result Dec.Error (BGF.Envelope Body))
  | ClickedPlayAgain
  | ShowRefX (Images.Ref, String)


-- Game connectivity


server : BGF.Server
server = BGF.wssServer "bgf.pigsaw.org"


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
    flags = decodeFlags v
    (lobby, playing, cmd) = Lobby.lobby lobbyConfig url key
  in
  ( { width = flags.width
    , lobby = lobby
    , playing = playing
    }
  , cmd
  )


lobbyConfig : Lobby.Config Msg PlayingState
lobbyConfig =
  { initBase = InLobby
  , initGame = initialGameState
  , change = \gameId _ -> initialGameState gameId
  , openCmd = openCmd
  , msgWrapper = ToLobby
  }


type alias Flags =
  { width : Int
  }


flagsDecoder : Dec.Decoder Flags
flagsDecoder =
  Dec.map
    Flags
    (Dec.field "width" Dec.int)


decodeFlags : Enc.Value -> Flags
decodeFlags v =
  Dec.decodeValue flagsDecoder v
  |> Result.withDefault { width = 1000 }


initialGameState : BGF.GameId -> PlayingState
initialGameState gameId =
  InGame
    { gameId = gameId
    , connectivity = BGF.Connected
    , playerCount = 1
    , moveNumber = 0
    , envNum = 2^31-1
    , turn = XMark
    , board = cleanBoard
    , winner = InProgress
    , refX = backgroundRefX
    }


backgroundRefX : (Images.Ref, String)
backgroundRefX =
  ( { src = ""
    , name = "Mike Maguire"
    , link = "https://www.flickr.com/photos/mikespeaks/39023133891/"
    }
  , "Background"
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
makeRefInt : GameState -> Int -> Int
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
    ToLobby lMsg ->
      let
        (lobby, playing, cmd) = Lobby.update lMsg model.playing model.lobby
      in
      ( { model
        | lobby = lobby
        , playing =
            case playing of
              InGame _ -> playing
              InLobby -> model.playing
        }
      , cmd
      )

    Resized width ->
      ( { model
        | width = width
        }
      , Cmd.none
      )

    CellClicked i ->
      case model.playing of
        InGame state ->
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
          ( { model | playing = InGame state2 }
          , sendCmd
            { moveNumber = state2.moveNumber
            , turn = state2.turn
            , board = state2.board
            }
          )

        InLobby ->
          (model, Cmd.none)

    Received envRes ->
      case model.playing of
        InLobby ->
          (model, Cmd.none)

        InGame state ->
          case envRes of
            Ok env ->
              let
                (state2, cmd) = updateWithEnvelope env state
              in
              ( { model | playing = InGame state2 }
              , cmd
              )

            Err desc ->
              -- We'll ignore errors
              (model, Cmd.none)

    ClickedPlayAgain ->
      case model.playing of
        InGame state ->
          let
            state2 =
              { state
              | moveNumber = state.moveNumber + 1
              , envNum = 2^31-1
              , board = cleanBoard
              , winner = InProgress
              }
          in
          ( { model | playing = InGame state2 }
          , sendCmd
            { moveNumber = state2.moveNumber
            , turn = state2.turn
            , board = state2.board
            }
          )

        InLobby ->
          (model, Cmd.none)

    ShowRefX refX ->
      case model.playing of
        InLobby ->
          (model, Cmd.none)

        InGame state ->
          let
            state2 = { state | refX = refX }
          in
          ( { model | playing = InGame state2 }
          , Cmd.none
          )


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


updateWithEnvelope : BGF.Envelope Body -> GameState -> (GameState, Cmd Msg)
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
      ( { state | connectivity = conn }
      , Cmd.none
      )

    BGF.Error _ ->
      -- We'll ignore errors
      ( state
      , Cmd.none
      )


-- We will only update the playing state with the given board if it
-- is a higher move number, or if it's the same move number
-- and a lower envelope num.
updateBoard : Int -> Body -> GameState -> GameState
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


clearance = UI.scaledInt 2
bigClearance = UI.scaledInt 4
borderWidth = 20
cellWidth = 200
gridColour = El.rgba 0.4 0.4 0.4 0.5
cellColour = El.rgba 0.5 0 0 0.5


padderTop : El.Element msg -> El.Element msg
padderTop =
  El.el
  [ El.paddingEach
    { top = 0
    , left = clearance
    , right = 0
    , bottom = clearance
    }
  ]


padderBottom : El.Element msg -> El.Element msg
padderBottom =
  El.el
  [ El.paddingEach
    { top = clearance
    , left = 0
    , right = 0
    , bottom = 0
    }
  ]


padderBigTop : El.Element msg -> El.Element msg
padderBigTop =
  El.el
  [ El.paddingEach
    { top = bigClearance
    , left = clearance
    , right = 0
    , bottom = 0
    }
  ]


view : Model -> Browser.Document Msg
view model =
  -- Background by Mike Maguire on Flickr
  -- https://www.flickr.com/photos/mikespeaks/39023133891/
  { title = "Noughts and crosses"
  , body =
    List.singleton
      <| El.layout
        [ El.padding clearance
        , Font.size UI.fontSize
        , Background.image "images/background.jpg"
        ]
      <| case model.playing of
        InLobby ->
          viewEntrance model.lobby

        InGame state ->
          viewPlay model state
  }


viewEntrance : Lobby Msg PlayingState -> El.Element Msg
viewEntrance lobby =
  El.column
  [ El.spacing clearance ]
  [ viewInstructions
  , viewGameIdBox lobby
  ]


viewInstructions : El.Element Msg
viewInstructions =
  "Noughts and crosses (also known as tic tac toe). " ++
  "Use the game ID below and click Go to start. Or enter a game ID " ++
  "from a friend and click Go to join their game."
  |> El.text
  |> List.singleton
  |> El.paragraph []
  |> UI.sticker
  |> UI.rotate -0.01


viewGameIdBox : Lobby Msg PlayingState -> El.Element Msg
viewGameIdBox lobby =
  El.row
  [ El.spacing (UI.scaledInt -1) ]
  [ El.text""
  , UI.inputText
    { onChange = Lobby.newDraft ToLobby
    , text = Lobby.draft lobby
    , placeholderText = "Game ID"
    , label = "Game ID"
    , fontScale = 12
    , miniPalette = UI.miniPaletteWhite
    }
  , UI.button
    { onPress = Just (Lobby.confirm ToLobby)
    , label = "Go"
    , enabled = Lobby.okDraft lobby
    , miniPalette = UI.miniPaletteWhite
    }
  , El.text""
  ]
  |> UI.sticker
  |> UI.rotate 0.02


viewPlay : Model -> GameState -> El.Element Msg
viewPlay model state =
  if model.width <= 1200 then
    -- Narrow layout
    El.column [ El.centerX ]
    [ viewWhoseTurnOrWinner state |> padderTop
    , viewInvitation model |> padderTop
    , viewGrid state
    , El.row [ El.spacing clearance ]
      [ viewPlayerCount state |> El.el [ El.alignTop ]
      , El.column [ El.alignTop ]
        [ viewRef state
        , viewConnectivity state |> padderBottom
        ]
      ] |> padderBottom
    ]

  else
    -- Wide layout
    El.row [ El.width El.fill ]
    [ viewGrid state
    , El.column
      [ El.width El.fill
      , El.alignTop
      ]
      [ viewWhoseTurnOrWinner state |> padderBigTop
      , viewInvitation model |> padderBigTop
      , El.row [ El.spacing 30 ]
        [ viewPlayerCount state
        , viewConnectivity state
        ] |> padderBigTop
      , viewRef state |> padderBigTop
      ]
    ]


viewGrid : GameState -> El.Element Msg
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


viewRow : Int -> GameState -> El.Element Msg
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


viewCell : Int -> GameState -> El.Element Msg
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
      El.image
      [ El.width (El.px cellWidth)
      , El.height (El.px cellWidth)
      , Events.onMouseEnter (ShowRefX (ref, "Image"))
      , Events.onMouseLeave (ShowRefX backgroundRefX)
      ]
      { src = ref.src
      , description = desc
      }


viewClickableCell : Int -> GameState -> El.Element Msg
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


viewWhoseTurnOrWinner : GameState -> El.Element Msg
viewWhoseTurnOrWinner state =
  case state.winner of
    WonBy mMark ->
      viewWinner mMark

    InProgress ->
      case state.turn of
        XMark ->
          UI.bigStickerText "X to play" |> UI.rotate -0.06

        OMark ->
          UI.bigStickerText "O to play" |> UI.rotate -0.06


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
  [ UI.bigStickerText winText |> UI.rotate -0.06
  , El.text "Click to play again"
    |> El.el [ El.pointer, Font.underline ]
    |> El.el [ Events.onClick <| ClickedPlayAgain ]
    |> UI.sticker
    |> UI.rotate 0.04
  ]


viewInvitation : Model -> El.Element Msg
viewInvitation model =
  El.paragraph []
  [ El.text "Tell your friends to join you at "
  , El.link
    [ El.pointer, Font.underline ]
    { url = model.lobby |> Lobby.urlString
    , label = model.lobby |> Lobby.urlString |> El.text
    }
  ]
  |> UI.smallSticker
  |> UI.rotate -0.01


viewConnectivity : GameState -> El.Element Msg
viewConnectivity state =
  case state.connectivity of
    BGF.Connected ->
      El.none

    BGF.Connecting ->
      El.text "Connecting"
      |> UI.smallSticker
      |> UI.rotate -0.03

    BGF.Disconnected ->
      El.text "Disconnected"
      |> UI.smallSticker
      |> UI.rotate -0.03


viewPlayerCount : GameState -> El.Element Msg
viewPlayerCount state =
  case state.playerCount of
    1 ->
      UI.stickerText "No other players online"
      |> UI.rotate 0.05

    2 ->
      UI.stickerText "One other player online"
      |> UI.rotate 0.05

    p ->
      (p - 1 |> String.fromInt) ++ " other players online"
      |> UI.stickerText
      |> UI.rotate 0.05


viewRef : GameState -> El.Element Msg
viewRef state =
  let
    (ref, prefix) = state.refX
  in
  El.link
  [ El.pointer, Font.underline ]
  { url = ref.link
  , label = prefix ++ " by " ++ ref.name |> El.text
  }
  |> UI.smallSticker
  |> UI.rotate -0.04
