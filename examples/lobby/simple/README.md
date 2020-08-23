# Simple lobby demo

This is to demonstrate how to use the `Lobby` module in the simplest way,
just asking for a game ID and entering the game. The "game" itself is
just a screen confirming the game ID.

## Files and compilation

* *src/Main.elm*. The main Elm app.
* *simple.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

## Compiling and running

Compile the Elm app using

```
elm make src/Main.elm --output=simple.js
```

and then use `elm reactor` to view `lobby-names.html` to see it running.
You need reactor because it's a `Browser.application`,
which relies on running from a server, not the local filesystem.
