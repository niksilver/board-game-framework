# Noughts and crosses

Also known a tic tac toe.

## Files and compilation

* *src/Main.elm*. The main Elm app.
* *ooxx.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

## Compiling and running

Compile the Elm app with this command:

```
elm make src/Main.elm --output=ooxx.js
```

and then use `elm reactor` to view `ooxx.html` to see it running.
You need reactor because it's a `Browser.application`,
which relies on running from a server, not the local filesystem.
