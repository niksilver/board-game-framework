# Simple data demo (Elm version)

This is a simple demo to show:
* We can connect to specific game via a server;
* We can send structured data to other clients;
* We can disconnect from the server.

The structured data received is a simple JSON object, but it
is not used or interpreted in any way. It's just displayed as a string.

This simple application is also useful for testing other apps, as it
allows us to see raw JSON messages coming into a client in a game.

There is another version of the application using just JavaScript.

* *src/Main.elm*. The main Elm app.
* *simple-elm.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration.
  Load this in a browswer to see the Elm version.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

Compile the Elm app with this command:

```
elm make src/Main.elm --output=simple-elm.js
```

and then go to simple-elm.html to see it running.
