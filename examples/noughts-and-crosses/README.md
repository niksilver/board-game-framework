# Noughts and crosses

Also known a tic tac toe.

Perhaps the most interesting thing about this implementation is what
information is sent between clients---it's the board, but also more.
We have to be careful about multiple players seeing the same board and both
selecting different cells at the same time. For this reason we also send
the move number (always incrementing), whose turn it is next,
and we look at the envelope num when the message comes in.
If we receive a duplicate move number we prefer the one with the lowest
envelope num, as that was sent out earlier.

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
