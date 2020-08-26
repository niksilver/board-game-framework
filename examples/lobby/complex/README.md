# Complex lobby demo

This is to demonstrate how to use the `Lobby` module in a fairly
complex way. In the lobby we ask not just for a game ID, but
also the player's name and which team they would like to play on.
The "game" itself is just a screen confirming this information.

This application also uses
[`hcrj/composable-form`](https://package.elm-lang.org/packages/hecrj/composable-form/latest/)
to demonstrate integration with a form-building package.

## Files and compilation

* *src/Main.elm*. The main Elm app.
* *complex.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

## Compiling and running

Compile the Elm app using

```
elm make src/Main.elm --output=complex.js
```

and then use `elm reactor` to view `complex.html` to see it running.
You need reactor because it's a `Browser.application`,
which relies on running from a server, not the local filesystem.
