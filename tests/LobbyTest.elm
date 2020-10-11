module LobbyTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Url
import Browser

import BoardGameFramework.Lobby as Lobby exposing (Lobby)


type Msg =
  ToLobby Lobby.Msg


type GameState =
  NoGame
  | GameState1
  | GameState2


lobbyConfig =
  { initBase = NoGame
  , initGame = \_ -> GameState1
  , change =
    \gameId state ->
      case state of
        NoGame -> Debug.todo "Should not get here"
        GameState1 -> GameState2
        GameState2 -> GameState1
  , openCmd = \_ -> Cmd.none
  , msgWrapper = ToLobby
  }


lobbyTest : Test
lobbyTest =
  describe "lobbyTest"
  [ test "Initialising with a good game ID should bring us into the game" <|
    \_ ->
      let
        url =
          { protocol = Url.Https
          , host = "some.example.com"
          , port_ = Nothing
          , path = "/mygame"
          , query = Nothing
          , fragment = Just "square-bananas"
          }
        (lobby, game, cmd) = Lobby.fakeLobby lobbyConfig url ()
      in
      Expect.equal GameState1 game

  , test "Initialising with a bad game ID should not bring us into the game" <|
    \_ ->
      let
        url =
          { protocol = Url.Https
          , host = "some.example.com"
          , port_ = Nothing
          , path = "/mygame"
          , query = Nothing
          , fragment = Just "sq"
          }
        (lobby, game, cmd) = Lobby.fakeLobby lobbyConfig url ()
      in
      Expect.equal NoGame game

  , test "Initialising with no game ID should not bring us into the game" <|
    \_ ->
      let
        url =
          { protocol = Url.Https
          , host = "some.example.com"
          , port_ = Nothing
          , path = "/mygame"
          , query = Nothing
          , fragment = Nothing
          }
        (lobby, game, cmd) = Lobby.fakeLobby lobbyConfig url ()
      in
      Expect.equal NoGame game

  ]

urlRequestedTest : Test
urlRequestedTest =
  describe "urlRequestedTest"
  [ describe "When in old game, clicking new game URL gives new game" <|
    let
      url1 =
        { protocol = Url.Https
        , host = "some.example.com"
        , port_ = Nothing
        , path = "/mygame"
        , query = Nothing
        , fragment = Just "square-bananas"
        }
      (lobby1, game1, cmd1) = Lobby.fakeLobby lobbyConfig url1 ()
      url2 =
        { url1
        | fragment = Just "round-fish"
        }
      req2 = Browser.Internal url2
      (ToLobby msg) = Lobby.urlRequested ToLobby req2
      (lobby2, game2, cmd2) =
        lobby1
        |> Lobby.update msg GameState1
    in
    [ test "A" <|
      \_ -> Expect.equal url2 <| Lobby.url lobby2

    , test "B" <|
      \_ -> Expect.equal "round-fish" <| Lobby.draft lobby2

    , test "C" <|
      \_ -> Expect.equal GameState2 <| game2
    ]

  , describe "Clicking game URL with bad frag gives Lobby with frag as draft" <|
    let
      url1 =
        { protocol = Url.Https
        , host = "some.example.com"
        , port_ = Nothing
        , path = "/mygame"
        , query = Nothing
        , fragment = Just "square-bananas"
        }
      (lobby1, game1, cmd1) = Lobby.fakeLobby lobbyConfig url1 ()
      url2 =
        { url1
        | fragment = Just "ro"
        }
      req2 = Browser.Internal url2
      (ToLobby msg) = Lobby.urlRequested ToLobby req2
      (lobby2, game2, cmd2) =
        lobby1
        |> Lobby.update msg GameState1
    in
    [ test "A" <|
      \_ -> Expect.equal url2 <| Lobby.url lobby2

    , test "B" <|
      \_ -> Expect.equal "ro" <| Lobby.draft lobby2

    , test "C" <|
      \_ -> Expect.equal NoGame <| game2
    ]

  , describe "Clicking game URL no frag gives Lobby (with new ID cmd)" <|
    let
      url1 =
        { protocol = Url.Https
        , host = "some.example.com"
        , port_ = Nothing
        , path = "/mygame"
        , query = Nothing
        , fragment = Just "square-bananas"
        }
      (lobby1, game1, cmd1) = Lobby.fakeLobby lobbyConfig url1 ()
      url2 =
        { url1
        | fragment = Nothing
        }
      req2 = Browser.Internal url2
      (ToLobby msg) = Lobby.urlRequested ToLobby req2
      (lobby2, game2, cmd2) =
        lobby1
        |> Lobby.update msg GameState1
    in
    [ test "A" <|
      \_ -> Expect.equal url2 <| Lobby.url lobby2

    , test "B" <|
      \_ -> Expect.equal "" <| Lobby.draft lobby2

    , test "C" <|
      \_ -> Expect.equal NoGame game2
    -- Cannot test cmd2
    ]

  , describe "Clicking same game URL gives same game state" <|
    let
      url1 =
        { protocol = Url.Https
        , host = "some.example.com"
        , port_ = Nothing
        , path = "/mygame"
        , query = Nothing
        , fragment = Just "square-bananas"
        }
      (lobby1, game1, cmd1) = Lobby.fakeLobby lobbyConfig url1 ()
      req2 = Browser.Internal url1
      (ToLobby msg) = Lobby.urlRequested ToLobby req2
      (lobby2, game2, cmd2) =
        lobby1
        |> Lobby.update msg GameState1
    in
    [ test "A" <|
      \_ -> Expect.equal url1 <| Lobby.url lobby2

    , test "B" <|
      \_ -> Expect.equal "square-bananas" <| Lobby.draft lobby2

    , test "C" <|
      \_ -> Expect.equal GameState1 <| game2
    ]

  ]

updateTest : Test
updateTest =
  describe "updateTest"
  [ describe "When in old game, changing the URL in the location bar triggers the change function" <|
    let
      url1 =
        { protocol = Url.Https
        , host = "some.example.com"
        , port_ = Nothing
        , path = "/mygame"
        , query = Nothing
        , fragment = Just "square-bananas"
        }
      (lobby1, game1, cmd1) = Lobby.fakeLobby lobbyConfig url1 ()
      url2 =
        { url1
        | fragment = Just "round-fish"
        }
      (ToLobby msg) = Lobby.urlChanged ToLobby url2
      (lobby2, game2, cmd2) =
        lobby1
        |> Lobby.update msg GameState1
    in
    [ test "A" <|
      \_ -> Expect.equal url2 <| Lobby.url lobby2

    , test "B" <|
      \_ -> Expect.equal "round-fish" <| Lobby.draft lobby2

    , test "C" <|
      \_ -> Expect.equal GameState2 <| game2
    ]

  , describe "When in old game, entering the same URL in the location bar doesn't trigger the change function" <|
    let
      url1 =
        { protocol = Url.Https
        , host = "some.example.com"
        , port_ = Nothing
        , path = "/mygame"
        , query = Nothing
        , fragment = Just "square-bananas"
        }
      (lobby1, game1, cmd1) = Lobby.fakeLobby lobbyConfig url1 ()
      (ToLobby msg) = Lobby.urlChanged ToLobby url1
      (lobby2, game2, cmd2) =
        lobby1
        |> Lobby.update msg GameState1
    in
    [ test "A" <|
      \_ -> Expect.equal url1 <| Lobby.url lobby2

    , test "B" <|
      \_ -> Expect.equal "square-bananas" <| Lobby.draft lobby2

    , test "C" <|
      \_ -> Expect.equal GameState1 <| game2
    ]

  ]
