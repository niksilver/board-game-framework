# Lobby names demo

This is to demonstrate how multiple players might gather together in a lobby
and give their screen names before all entering the game.
Interesting features are:
* The game ID is randomly generated;
* Once one player decides the players should enter the game, the
  game state changes for everyone;
* Anyone who joins after the players have entered just see a list of players.

After entering, there is no actual game - it's just a live list of players.

## Files and compilation

* *src/Main.elm*. The main Elm app.
* *lobby-names-elm.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

## Compiling and running

Compile the Elm app with this command:

```
elm make src/Main.elm --output=lobby-names.js
```

and then use `elm reactor` to view `lobby-names.html` to see it running.
You need reactor because it's a `Browser.application`,
which relies on running from a server, not the local filesystem.
