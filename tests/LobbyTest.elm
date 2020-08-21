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
  { stateMaker = \_ -> TheGame
  , openCmd = \_ -> Cmd.none
  , msgWrapper = ToLobby
  }


updateTest : Test
updateTest =
  describe "update"
  [ describe "UrlRequested"
    [ test "Clicking new game URL gives new game" <|
      \_ ->
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
        requireAll
        [ Expect.equal url2 <| Lobby.url lobby2
        , Expect.equal "round-fish" <| Lobby.draftGameId lobby2
        , Expect.equal (Just TheGame) <| game2
        ]

    , test "Clicking game URL with bad frag gives Lobby with frag as draft" <|
      \_ ->
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
        requireAll
        [ Expect.equal url2 <| Lobby.url lobby2
        , Expect.equal "ro" <| Lobby.draftGameId lobby2
        , Expect.equal Nothing <| game2
        ]

    , test "Clicking game URL no frag gives Lobby (with new ID cmd)" <|
      \_ ->
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
        requireAll
        [ Expect.equal url2 <| Lobby.url lobby2
        , Expect.equal "" <| Lobby.draftGameId lobby2
        , Expect.equal Nothing <| game2
        -- Cannot test cmd2
        ]

    , test "Clicking same game URL gives nothing" <|
      \_ ->
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
        requireAll
        [ Expect.equal url1 <| Lobby.url lobby2
        , Expect.equal "square-bananas" <| Lobby.draftGameId lobby2
        , Expect.equal Nothing <| game2
        ]

    ]
  ]


requireAll : List Expectation -> Expectation
requireAll exps =
  case exps of
    head :: tail ->
      if head == Expect.pass then
        requireAll tail

      else
        head

    [] ->
      Expect.pass
