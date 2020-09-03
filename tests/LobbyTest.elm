module LobbyTest exposing (..)


import Expect exposing (Expectation)
import Test exposing (..)

import Url
import Browser

import BoardGameFramework.Lobby as Lobby exposing (Lobby)


type Msg =
  ToLobby Lobby.Msg


type GameState = TheGame


lobbyConfig =
  { init = \_ -> TheGame
  , openCmd = \_ -> Cmd.none
  , msgWrapper = ToLobby
  }


updateTest : Test
updateTest =
  describe "update"
  [ describe "UrlRequested"
    [ describe "Clicking new game URL gives new game" <|
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
          |> Lobby.update msg
      in
      [ test "A" <|
        \_ -> Expect.equal url2 <| Lobby.url lobby2

      , test "B" <|
        \_ -> Expect.equal "round-fish" <| Lobby.draft lobby2

      , test "C" <|
        \_ -> Expect.equal (Just TheGame) <| game2
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
          |> Lobby.update msg
      in
      [ test "A" <|
        \_ -> Expect.equal url2 <| Lobby.url lobby2

      , test "B" <|
        \_ -> Expect.equal "ro" <| Lobby.draft lobby2

      , test "C" <|
        \_ -> Expect.equal Nothing <| game2
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
          |> Lobby.update msg
      in
      [ test "A" <|
        \_ -> Expect.equal url2 <| Lobby.url lobby2

      , test "B" <|
        \_ -> Expect.equal "" <| Lobby.draft lobby2

      , test "C" <|
        \_ -> Expect.equal Nothing <| game2
      -- Cannot test cmd2
      ]

    , describe "Clicking same game URL gives nothing" <|
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
          |> Lobby.update msg
      in
      [ test "A" <|
        \_ -> Expect.equal url1 <| Lobby.url lobby2

      , test "B" <|
        \_ -> Expect.equal "square-bananas" <| Lobby.draft lobby2

      , test "C" <|
        \_ -> Expect.equal Nothing <| game2
      ]

    ]
  ]
