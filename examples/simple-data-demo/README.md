# Simple data demo

This is a simple demo to show:
* We can connect to specific game via a server;
* We can send structured data to other clients;
* We can disconnect from the server.

The structured data received is a simple JSON object, but it
is not used or interpreted in any way. It's just displayed as a string.

There are two versions of the application: in JavaScript, and in Elm.

## JavaScript version

* *data-demo-js.html*. JavaScript app. Run this to see the JavaScript version.
* *lib/boardgameframework.js*. A copy of the framework library it uses.

## Elm version

* *Main.elm*. The main Elm app.
* *data-demo-elm.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration.
* *lib/boardgameframework.js*. A copy of the JavaScript framework library
  used by the shell page.

Compile the Elm app with this command:

```
elm make Main.elm --output=data-demo-elm.js
```

and then go to data-demo-elm.html to see it running.
