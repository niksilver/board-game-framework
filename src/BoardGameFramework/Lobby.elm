-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework.Lobby exposing (
  Lobby, Config, Msg, lobby
  -- Messages
  , urlRequested, urlChanged, newDraftMsg, confirm
  -- Updating
  , update, newDraft
  -- Querying
  , url, urlString, draft, okDraft
  -- Only expose this for testing
  , fakeLobby
  )


{-| Managing the lobby - selecting the game ID and handling URL changes.

There are no view functions in this module. You should write your own
view function for the user to enter their own game ID. But this also allows
you to add any other information onto the lobby page, such as the player's
name, or which team they way to play on. It also allows you to use any
form and validation libraries you like.

# Defining
@docs Lobby, Config, Msg, lobby

# Messages
@docs urlRequested, urlChanged, newDraftMsg, confirm

# Updating
@docs update

# Querying
@docs url, urlString, draftGameId, okGameId
-}


import Browser
import Browser.Navigation as Nav
import Random
import Url

import BoardGameFramework as BGF


-- Type definitions


{-| The lobby is the gateway to the main game.
It maintains the game ID
(from what the user types, before they start the main game,
or from the URL), and hence the URL, too.
It also issues any commands resulting from a game ID (or URL) change.
-}
type Lobby msg =
  Lobby
    { openCmd : BGF.GameId -> Cmd msg
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
type alias Config msg =
  { openCmd : BGF.GameId -> Cmd msg
  , msgWrapper : Msg -> msg
  }


{-| A message to update the model of the lobby.
-}
type Msg =
  UrlRequested Browser.UrlRequest
  | UrlChanged Url.Url
  | GeneratedGameId BGF.GameId
  | NewDraft String
  | Confirm


-- Creating a lobby


{-| Create a lobby.
-}
lobby : Config msg -> Url.Url -> Nav.Key -> (Lobby msg, Maybe BGF.GameId, Cmd msg)
lobby config url_ key =
  Lobby
    { openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    , url = url_
    , key = Real key
    , draftGameId = ""
    }
  |> forNewUrl


-- Should only be exposed during testing.
fakeLobby : Config msg -> Url.Url -> () -> (Lobby msg, Maybe BGF.GameId, Cmd msg)
fakeLobby config url_ key =
  Lobby
    { openCmd = config.openCmd
    , msgWrapper = config.msgWrapper
    , url = url_
    , key = Fake
    , draftGameId = ""
    }
  |> forNewUrl


-- Process a lobby which has a new URL
forNewUrl : Lobby msg -> (Lobby msg, Maybe BGF.GameId, Cmd msg)
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
          , Just gameId
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


-- Messages


{-| Default handler for links being clicked. External links are loaded,
internal links are ignored.
-}
urlRequested : (Msg -> msg) -> Browser.UrlRequest -> msg
urlRequested msgWrapper request =
  msgWrapper <| UrlRequested request


{-| Default handler for when the URL has changed in the browser.
This is called before any page rendering.
-}
urlChanged : (Msg -> msg) -> Url.Url -> msg
urlChanged msgWrapper url_ =
  msgWrapper <| UrlChanged url_


{-| Create a message that says the draft game ID has changed -
for example, when
the user types another character into the lobby's text box, asking which
game they'd like to join.
This can then be sent to [`update`](#update).
-}
newDraftMsg: (Msg -> msg) -> String -> msg
newDraftMsg msgWrapper draft_ =
  msgWrapper <| NewDraft draft_


{-| Confirm that we should try to use the draft gameID as the actual game ID -
for example, when the user has clicked a Go button after typing in a game
ID. There is no need to check if the game ID is valid.
-}
confirm : (Msg -> msg) -> msg
confirm msgWrapper =
  msgWrapper <| Confirm


-- Updating


{-| Handle any message for the lobby. Returns the new lobby, maybe a
new game (if the game ID has changed) and any commands that need to be
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
            (lobby, playing, cmd) = Lobby.update lMsg model.lobby
          in
          ( { model
            | lobby = lobby
            , playing = playing
            }
          , cmd
          )

        ... ->
-}
update : Msg -> Lobby msg -> (Lobby msg, Maybe BGF.GameId, Cmd msg)
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
      ( newDraft draft_ (Lobby lob)
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


{-| Update the draft game ID in the lobby. This is equivalent to the
two step process of generating a [`newDraftMsg`](#newDraftMsg) and
passing it into [`update](#update).
-}
newDraft: String -> Lobby msg -> Lobby msg
newDraft draft_ (Lobby lob) =
  Lobby
    { lob | draftGameId = draft_ }


pushUrl : Key -> String -> Cmd msg
pushUrl k url_ =
  case k of
    Real key ->
      Nav.pushUrl key url_

    Fake ->
      Cmd.none


setFragment : Url.Url -> String -> Url.Url
setFragment url_ fragment =
  { url_ | fragment = Just fragment }


-- Querying


{-| Get the URL, which the `Lobby` is holding. This may be the URL of
the game lobby or the actual game.
-}
url : Lobby msg -> Url.Url
url (Lobby lob) =
  lob.url


{-| Get the URL as a string.
-}
urlString : Lobby msg -> String
urlString (Lobby lob) =
  lob.url
  |> Url.toString


{-| Get the (possibly incomplete) game ID that the player is entering
into the lobby UI.
-}
draft : Lobby msg -> String
draft (Lobby lob) =
  lob.draftGameId


{-| See if the (possibly incomplete) game ID is a valid game ID.
Useful for knowing if we should enable or disable a Go button in the UI.
-}
okDraft : Lobby msg -> Bool
okDraft (Lobby lob) =
  case lob.draftGameId |> BGF.gameId of
    Ok _ ->
      True

    Err _ ->
      False
