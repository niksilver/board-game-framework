# Simple data demo (JavaScript version)

This is a simple demo to show:
* We can connect to specific game via a server;
* We can send structured data to other clients;
* We can disconnect from the server.

The structured data received is a simple JSON object, but it
is not used or interpreted in any way. It's just displayed as a string.

This simple application is also useful for testing other apps, as it
allows us to see raw JSON messages coming into a client in a game.

There is another version of this app, in Elm, using the Elm
`BoardGameFramework` module.

## JavaScript version

* *simple-js.html*. JavaScript app. Load this in a browswer
  to see it working.
* *lib/board-game-framework.js*. A copy of the framework library it uses.
