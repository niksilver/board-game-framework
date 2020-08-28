# Lobby demo with a second screen

This is to demonstrate how to use the `Lobby` module in a slightly
more interesting way. The lobby screen still just asks for a game ID,
but when it gets a valid ID it then asks for more information before
allowing the player in - their name and which team they will play on.
The "game" itself is just a screen confirming this information.

This application also uses
[`hcrj/composable-form`](https://package.elm-lang.org/packages/hecrj/composable-form/latest/)
for that later information.

## Files and compilation

* *src/Main.elm*. The main Elm app.
* *second-screen.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

## Compiling and running

Compile the Elm app using

```
elm make src/Main.elm --output=second-screen.js
```

and then use `elm reactor` to view `second-screen.html` to see it running.
You need reactor because it's a `Browser.application`,
which relies on running from a server, not the local filesystem.
