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
        Expect.all
        [ \lob -> Expect.equal url2 <| Lobby.url lob
        , \lob -> Expect.equal "round-fish" <| Lobby.draftGameId lob
        ]
        lobby2
    ]
  ]
