# Lobby names demo

This is to demonstrate how multiple players might join together in lobby
and give their screen names before all entering the game.
Interesting features are:
* The game ID is randomly generated;
* Once one player decides the game should start, it starts for everyone;
* Players who join after the game starts are presented as observers.

There is not actual game - it's just a list of players and observers.

## Files and compilation

* *src/Main.elm*. The main Elm app.
* *lobby-names-elm.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

Compile the Elm app with this command:

```
elm make src/Main.elm --output=lobby-names.js
```

and then go to lobby-names.html to see it running.
