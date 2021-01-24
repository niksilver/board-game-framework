-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework.Lobby exposing (
  Lobby, Config, Msg, lobby
  -- Messages
  , urlRequested, urlChanged, newDraft, confirm
  -- Updating
  , update
  -- Querying
  , url, urlString, draft, okDraft
  -- Viewing
  , view
  -- Only expose this for testing
  -- , fakeLobby
  )


{-| The lobby is the first screen of any game, and allows the user to enter
the game room. It will also randomly generate a room name on first loading.
ut
But the room can also be selected by changing the URL,
so this module also handles changes through that route.

If a player needs to provide further information before entering a
game (perhaps a name, a team, a role, etc) then that should
be captured on a subsequent screen, after leaving the lobby.

A lobby needs a [`Config`](#Config). An important part of this is to define the
logic of lobby, such as what to do with the game state when the room changes,
and understanding how to wrap its own lobby-specific messages for handling by the
main application.

See the [simple lobby example](https://github.com/niksilver/board-game-framework/tree/master/examples/lobby-simple)
for how this all fits together in practice, and the
[lobby second-screen example](https://github.com/niksilver/board-game-framework/tree/master/examples/lobby-second-screen)
for how to allow someone to enter their additional information (eg their name)
after leaving the lobby but before entering the game itself.

# Defining
@docs Lobby, Config, Msg, lobby

# Messages
@docs urlRequested, urlChanged, newDraft, confirm

# Updating
@docs update

# Querying
@docs url, urlString, draft, okDraft

# Viewing
@docs view
-}


import Browser
import Browser.Navigation as Nav
import Html as Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Random
import Url

import BoardGameFramework as BGF


-- Defining


{-| The lobby is the first step into the main game. It may lead directly into a game
or to interim screens that first ask the user for more information.

A `Lobby` is further defined by two types. The `msg` is the main application message
type; the lobby will need to wrap its own messages in this type to pass into (and out of)
the main application. `s` is the state of the game.
-}
type Lobby msg s =
  Lobby
    { initBase : s
    , initGame : BGF.Room -> s
    , change : BGF.Room -> s -> s
    , openCmd : BGF.Room -> Cmd msg
    , msgWrapper : Msg -> msg
    , url : Url.Url
    , key : Key
    , draftRoom : String
    }


-- We have to use this hidden type to allow our tests to simulate having
-- a Nav.Key, which Elm doesn't allow us to generate outside a browser.
type Key =
  Real Nav.Key
  | Fake


{-| How the lobby interoperates with the main app. We need:
* The base game state, given no information;
* A way to generate the game state if we've just got the room name;
* A way to generate the game state if the room has changed but we're already
  in another game state;
* A function to generate the [`open`](../BoardGameFramework#open)
  command to the server, given a room name;
* How to wrap a lobby `msg` into an application-specific message.
  We can the catch it at the top level of our application and then pass into the
  lobby.

The `initGame` function will be used if, say, the user arrives at the game with a
URL including the room name.

The `change` function will be used if, say, the user switches room in the middle of a
game. If we've allowed them to choose a name we might want to reuse that as they enter
the new game.
-}
type alias Config msg s =
  { initBase : s
  , initGame : BGF.Room-> s
  , change : BGF.Room-> s -> s
  , openCmd : BGF.Room-> Cmd msg
  , msgWrapper : Msg -> msg
  }


-- Messages


{-| A message to update the model of the lobby. We will capture this
in our main application and pass it into [`update`](#update).
For example:

    import BoardGameFramework.Lobby as Lobby

    type Msg =
      ToLobby Lobby.Msg
      | ...

    type PlayingState =
      InLobby
      | ...

    lobbyConfig : Lobby.Config Msg PlayingState
    lobbyConfig =
      { initBase = ...
      , initGame = ...
      , change = ...
      , openCmd = ...
      , msgWrapper = ToLobby
      }

    update : Msg -> Model -> (Model, Cmd Msg)
    update msg model =
      case msg of
        ToLobby lobbyMsg ->
          let
            (lobby, playing, cmd) = Lobby.update lobbyMsg model.playing model.lobby
          in
          ...
-}
type Msg =
  UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | GeneratedRoom BGF.Room
  | NewDraft String
  | Confirm


{-| Default handler for links being clicked. External links are loaded,
internal links are ignored.

    import BoardGameFramework as BGF
    import BoardGameFramework.Lobby as Lobby

    type Msg =
      ToLobby Lobby.Msg
      | ...

    main =
      Browser.application
      { init = init
      , update = update
      , subscriptions = subscriptions
      , onUrlRequest = Lobby.urlRequested ToLobby
      , onUrlChange = Lobby.urlChanged ToLobby
      , view = view
      }
-}
urlRequested : (Msg -> msg) -> Browser.UrlRequest -> msg
urlRequested msgWrapper request =
  msgWrapper <| UrlRequested request


{-| Default handler for when the URL has changed in the browser.
This is called before any page rendering.
See [`urlRequested`](#urlRequested) for an example of this being used.
-}
urlChanged : (Msg -> msg) -> Url.Url -> msg
urlChanged msgWrapper url_ =
  msgWrapper <| UrlChanged url_


{-| Tell the lobby that the draft room name has changed - for example, when
the user types another character into the lobby's text box asking which
room they'd like to join.

You don't need to use this if you're using
this module's [`view`](#view) function, but do look at the source of
that function if you want to see how it's used.
-}
newDraft: (Msg -> msg) -> String -> msg
newDraft msgWrapper draft_ =
  msgWrapper <| NewDraft draft_


{-| Confirm that we should try to use the draft
room name as the actual room name -
for example, when the user has clicked a Go button after typing in a
name. There is no need to check if the room name is valid.

You don't need to use this if you're using
this module's [`view`](#view) function, but do look at the source of
that function if you want to see how it's used.
-}
confirm : (Msg -> msg) -> msg
confirm msgWrapper =
  msgWrapper <| Confirm


{-| Create a lobby which handles room and URL changes.
We use this when we initialise our applicaton.
-}
lobby : Config msg s -> Url.Url -> Nav.Key -> (Lobby msg s, s, Cmd msg)
lobby config url_ key =
  Lobby
    { initBase = config.initBase
    , initGame = config.initGame
    , change = config.change
    , openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    , url = url_
    , key = Real key
    , draftRoom = ""
    }
  |> forNewUrlAtInit


-- Should only be exposed during testing.
fakeLobby : Config msg s -> Url.Url -> () -> (Lobby msg s, s, Cmd msg)
fakeLobby config url_ key =
  Lobby
    { initBase = config.initBase
    , initGame = config.initGame
    , change = config.change
    , openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    , url = url_
    , key = Fake
    , draftRoom = ""
    }
  |> forNewUrlAtInit


-- Process a lobby which has a new URL, when we're not in a game
forNewUrlAtInit : Lobby msg s -> (Lobby msg s, s, Cmd msg)
forNewUrlAtInit (Lobby lob) =
  case lob.url.fragment of
    Nothing ->
      ( Lobby
          { lob
          | draftRoom = ""
          }
      , lob.initBase
      , Random.generate GeneratedRoom BGF.roomGenerator
        |> Cmd.map lob.msgWrapper
      )

    Just frag ->
      case BGF.room frag of
        Ok room ->
          ( Lobby
              { lob
              | draftRoom = frag
              }
          , lob.initGame room
          , lob.openCmd room
          )

        Err _ ->
          ( Lobby
              { lob
              | draftRoom = frag
              }
          , lob.initBase
          , Cmd.none
          )


-- Process a lobby which has a new URL, when we're already in a game
forNewUrlInGame : s -> Lobby msg s -> (Lobby msg s, s, Cmd msg)
forNewUrlInGame state (Lobby lob) =
  case lob.url.fragment of
    Nothing ->
      forNewUrlAtInit (Lobby lob)

    Just frag ->
      case BGF.room frag of
        Ok room ->
          {--          if BGF.fromGameId gameId == lob.draftGameId then
            ( Lobby lob
            , state
            , Cmd.none
            )
          else--}
            ( Lobby
                { lob
                | draftRoom = frag
                }
            , lob.change room state
            , lob.openCmd room
            )

        Err _ ->
          forNewUrlAtInit (Lobby lob)


pushUrl : Key -> String -> Cmd msg
pushUrl k url_ =
  case k of
    Real key ->
      Nav.pushUrl key url_

    Fake ->
      Cmd.none


-- Updating


{-| Handle any message for the lobby. Returns the new lobby, the latest game state
and any commands that need to be
issued (such as opening a connection to a new game).
It will apply its logic in line with the [`Config`](#Config) that the lobby was defined with.

The example below is the `update` function of some main app.
We defined our lobby `Config` with a `msgWrapper` of
`ToLobby`. Our model maintains the game-in-progress state as
its `playing` field.

    update : Msg -> Model -> (Model, Cmd Msg)
    update msg model =
      case msg of
        ToLobby lobbyMsg ->
          let
            (lobby, playing, cmd) = Lobby.update lobbyMsg model.playing model.lobby
          in
          ( { model
            | lobby = lobby
            , playing = playing
            }
          , cmd
          )

        ... ->
-}
update : Msg -> s -> Lobby msg s -> (Lobby msg s, s, Cmd msg)
update msg state (Lobby lob) =
  case msg of
    UrlRequested req ->
      case req of
        Browser.Internal url_ ->
          if url_ == lob.url then
            ( Lobby lob
            , state
            , Cmd.none
            )
          else
            -- If a new URL is requested we need to process that, but also
            -- make sure it appears in the browser's location bar.
            let
              (Lobby lob2, state2, cmd) =
                Lobby { lob | url = url_ }
                |> forNewUrlInGame state
            in
            ( Lobby lob2
            , state2
            , Cmd.batch
              [ cmd
              , pushUrl lob.key (Url.toString lob2.url)
              ]
            )

        Browser.External str ->
          ( Lobby lob
          , state
          , Nav.load str
          )

    UrlChanged url_ ->
      Lobby { lob | url = url_ }
      |> forNewUrlInGame state

    GeneratedRoom room ->
      ( Lobby
          { lob
          | draftRoom = room |> BGF.fromRoom
          }
      , state
      , Cmd.none
      )

    NewDraft draft_ ->
      ( Lobby
          { lob
          | draftRoom = draft_
          }
      , state
      , Cmd.none
      )

    Confirm ->
      ( Lobby lob
      , state
      , lob.draftRoom
        |> setFragment lob.url
        |> Url.toString
        |> pushUrl lob.key
      )


setFragment : Url.Url -> String -> Url.Url
setFragment url_ fragment =
  { url_ | fragment = Just fragment }


-- Querying


{-| Get the URL, which the `Lobby` is holding. This may be the URL of
the game lobby (if we're still in the lobby) or of
the actual game (if we've successfully left the lobby).
-}
url : Lobby msg s -> Url.Url
url (Lobby lob) =
  lob.url


{-| Get the URL as a string.
-}
urlString : Lobby msg s -> String
urlString (Lobby lob) =
  lob.url
  |> Url.toString


{-| Get the (possibly incomplete) room name that the player is entering
into the lobby UI.
This isn't necessary if you're using the
[`view`](#view) function.
-}
draft : Lobby msg s -> String
draft (Lobby lob) =
  lob.draftRoom


{-| See if what the player has typed into the lobby is a valid room name.
Useful for knowing if we should enable or disable a Go button in the UI,
but it isn't necessary if you're using the
[`view`](#view) function.
-}
okDraft : Lobby msg s -> Bool
okDraft (Lobby lob) =
  case lob.draftRoom |> BGF.room of
    Ok _ ->
      True

    Err _ ->
      False


-- Viewing


{-| View the lobby form.

You need to provide the label text (for outside the text box),
the placeholder text (for within the text box), and the button text.
For styling, the whole is in an HTML `div` of class `bgf-label`.
-}
view :
  { label : String
  , placeholder : String
  , button : String
  }
  -> Lobby msg s -> Html msg
view config (Lobby lob) =
  Html.div
  [ Attr.class "bgf-lobby"
  ]
  [ Html.label [] [ Html.text config.label ]
  , Html.input
    [ Events.onInput (newDraft lob.msgWrapper)
    , Attr.value (draft <| Lobby lob)
    ]
    []
  , Html.button
    [ Events.onClick (confirm <| lob.msgWrapper)
    , Attr.disabled (not <| okDraft <| Lobby lob)
    ]
    [ Html.label [] [ Html.text config.button ]
    ]
  ]
