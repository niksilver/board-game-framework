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
  , fakeLobby
  )


{-| The lobby - selecting the game ID and handling URL changes.

The lobby is the first screen of any game, and allows the user to select
the game ID. It will also randomly generate a game ID on first loading.
But the game ID can also be selected by changing the URL,
so this module also handles changes through that route.

If a player needs to provide further information before entering a
game (perhaps a name, a team, a role, etc) then that should
be captured on a subsequent screen.

`Lobby` is designed assuming that a game will always have a lobby,
and `Maybe` have a playing state of type `s`.
(It won't have a playing state
if the player has not left the lobby with a valid game ID.)
Therefore after confirming a new game ID from the lobby
the [`update`](#update) function will also return
an initial playing state (of type `s`).
The way this initial playing state is created is defined in the
`init` field of the lobby's [`Config`](#Config).

# Defining
@docs Lobby, Config, Msg, lobby

# Updating
@docs update

# Querying
@docs url, urlString, draftGameId, okGameId

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


{-| The lobby is the gateway to the main game.
-}
type Lobby msg s =
  Lobby
    { init : BGF.GameId -> s
    , openCmd : BGF.GameId -> Cmd msg
    , msgWrapper : Msg -> msg
    , url : Url.Url
    , key : Key
    , draftGameId : String
    }


-- We have to use this hidden type to allow our tests to simulate having
-- a Nav.Key, which Elm doesn't allow us to generate outside a browser.
type Key =
  Real Nav.Key
  | Fake


{-| How the lobby interoperates with the main app. We need:
* A way to generate an initial game state, given a game ID;
* A function to generate the `Open` command to the server, given a game ID;
* How to wrap a lobby msg into an application-specific message (which
  we can catch at the top level of our application and then pass into the
  lobby).
-}
type alias Config msg s =
  { init : BGF.GameId -> s
  , openCmd : BGF.GameId -> Cmd msg
  , msgWrapper : Msg -> msg
  }


-- Messages


{-| A message to update the model of the lobby.
-}
type Msg =
  UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraft String
  | Confirm


{-| Default handler for links being clicked. External links are loaded,
internal links are ignored.

    import BoardGameFramework as BGF
    import BoardGameFramework.Lobby as Lobby

    type Msg =
      ToLobby Lobby.Msg
      | ...

    main : Program BGF.ClientId Model Msg
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


{-| Tell the lobby that the draft game ID has changed - for example, when
the user types another character into the lobby's text box, asking which
game they'd like to join.

You don't need to use this if you're using
this module's [`view`](#view) function, but do look at the source of
that function if you want to see how it's used.
-}
newDraft: (Msg -> msg) -> String -> msg
newDraft msgWrapper draft_ =
  msgWrapper <| NewDraft draft_


{-| Confirm that we should try to use the draft gameID as the actual game ID -
for example, when the user has clicked a Go button after typing in a game
ID. There is no need to check if the game ID is valid.

You don't need to use this if you're using
this module's [`view`](#view) function, but do look at the source of
that function if you want to see how it's used.
-}
confirm : (Msg -> msg) -> msg
confirm msgWrapper =
  msgWrapper <| Confirm


{-| Create a lobby which handles game ID and URL changes.
-}
lobby : Config msg s -> Url.Url -> Nav.Key -> (Lobby msg s, Maybe s, Cmd msg)
lobby config url_ key =
  Lobby
    { init = config.init
    , openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    , url = url_
    , key = Real key
    , draftGameId = ""
    }
  |> forNewUrl


-- Should only be exposed during testing.
fakeLobby : Config msg s -> Url.Url -> () -> (Lobby msg s, Maybe s, Cmd msg)
fakeLobby config url_ key =
  Lobby
    { init = config.init
    , openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    , url = url_
    , key = Fake
    , draftGameId = ""
    }
  |> forNewUrl


-- Process a lobby which has a new URL
forNewUrl : Lobby msg s -> (Lobby msg s, Maybe s, Cmd msg)
forNewUrl (Lobby lob) =
  case lob.url.fragment of
    Nothing ->
      ( Lobby
          { lob
          | draftGameId = ""
          }
      , Nothing
      , Random.generate GeneratedGameId BGF.idGenerator
        |> Cmd.map lob.msgWrapper
      )

    Just frag ->
      case BGF.gameId frag of
        Ok gameId ->
          ( Lobby
              { lob
              | draftGameId = frag
              }
          , Just <| lob.init gameId
          , lob.openCmd gameId
          )

        Err _ ->
          ( Lobby
              { lob
              | draftGameId = frag
              }
          , Nothing
          , Cmd.none
          )


pushUrl : Key -> String -> Cmd msg
pushUrl k url_ =
  case k of
    Real key ->
      Nav.pushUrl key url_

    Fake ->
      Cmd.none


-- Updating


{-| Handle any message for the lobby. Returns the new lobby, maybe a
new playing state (if a new game ID has been confirmed)
and any commands that need to be
issued (such as opening a connection to a new game).

The example below is the `update` function of some main app.
We defined our `Lobby` with a `msgWrapper` of
`ToLobby`, and our model maintains the game-in-progress state as
its `playing` field.

    update : Msg -> Model -> (Model, Cmd Msg)
    update msg model =
      case msg of
        ToLobby lMsg ->
          let
            (lobby, maybePlaying, cmd) = Lobby.update lMsg model.lobby
          in
          ( { model
            | lobby = lobby
            , playing = maybePlaying
            }
          , cmd
          )

        ... ->
-}
update : Msg -> Lobby msg s -> (Lobby msg s, Maybe s, Cmd msg)
update msg (Lobby lob) =
  case msg of
    UrlRequested req ->
      case req of
        Browser.Internal url_ ->
          if url_ == lob.url then
            ( Lobby lob
            , Nothing
            , Cmd.none
            )
          else
            Lobby { lob | url = url_ }
            |> forNewUrl

        Browser.External str ->
          ( Lobby lob
          , Nothing
          , Nav.load str
          )

    UrlChanged url_ ->
      Lobby { lob | url = url_ }
      |> forNewUrl

    GeneratedGameId gameId ->
      ( Lobby
          { lob
          | draftGameId = gameId |> BGF.fromGameId
          }
      , Nothing
      , Cmd.none
      )

    NewDraft draft_ ->
      ( Lobby
          { lob
          | draftGameId = draft_
          }
      , Nothing
      , Cmd.none
      )

    Confirm ->
      ( Lobby lob
      , Nothing
      , lob.draftGameId
        |> setFragment lob.url
        |> Url.toString
        |> pushUrl lob.key
      )


setFragment : Url.Url -> String -> Url.Url
setFragment url_ fragment =
  { url_ | fragment = Just fragment }


-- Querying


{-| Get the URL, which the `Lobby` is holding. This may be the URL of
the game lobby or the actual game.
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


{-| Get the (possibly incomplete) game ID that the player is entering
into the lobby UI.
This isn't necessary if you're using the
[`view`](#view) function.
-}
draft : Lobby msg s -> String
draft (Lobby lob) =
  lob.draftGameId


{-| See if the (possibly incomplete) game ID is a valid game ID.
Useful for knowing if we should enable or disable a Go button in the UI,
but it isn't necessary if you're using the
[`view`](#view) function.
-}
okDraft : Lobby msg s -> Bool
okDraft (Lobby lob) =
  case lob.draftGameId |> BGF.gameId of
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
