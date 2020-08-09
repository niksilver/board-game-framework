# The JavaScript layer

The Javascript layer is in `js/board-game-framework.js`.
It is designed to allow make server connectivity easier for
the application. It
* offers an Open action to open a websocket;
* offers a Close action to close the websocket;
* offers a Send action to send data to other players;
* will reconnect to the server if the websocket connection breaks;
* passes message envelopes from the server to the application;
* passes a connecton envelope to the application when the connection
  status changes;
* passes an error envelope to the application if there is a network problem.

The Elm library interacts with the JavaScript layer, so if you're
going to write in Elm there is no need to look further here.

A simple example of the JavaScript layer in use can be found in
[the simple JavaScript demo](https://niksilver.github.io/games/simple-js.html).

## Using the JavaScript layer

First create a new instance of the board game framework:
```js
var bgf = new BoardGameFramework();
```

You can tell the object to take an action by calling

```js
bgf.act(data)
```
where `data` is one of the following structures:

```js
{ instruction: "Open",
  url: "wss://some.server.name/g/some-game-id"
}
```
This says to open a connection to the given server, using `some-game-id`
as the ID of the game for the players.

```js
{ instruction: "Close"
}
```
This says to close the connection to the server.

```js
{ instruction: "Send",
  body: {some: ["arbitrary"], json: "Object" }
}
```
This will send some arbitrary JSON object to the server, as a game message
to all the players. The `act()` function will JSON.stringify the `body`
field.

When the board game framework object wants to send an envelope into
our application it calls its own `toApp(env)` function. So after
creating a `new BoardGameFramework()` object we should set that value:
```js
bgf.toApp = function(env) {
    // Put something here to process the envelope
}
```

## Envelopes

The `toApp()` function will be called with all envelopes from the game server.
See [the concepts doc](concepts.md) for details. But in brief these are
envelopes with the `Intent`:
* Welcome - when the client first joins;
* Joiner - when another client joins;
* Leaver - when a client leaves;
* Peer - when another client has sent a message;
* Receipt - when this client has sent a message and the server is
  sending it out to other clients as a Peer message.

Additionally `toApp()` will be called with one of these three envelopes when
something changes with the connection:
* `{connection: "connecting"}` when the JavaScript layer is connecting or
  (in the event of a lost connection) reconnecting;
* `{connection: "connected"}` when a connection is successfully opened;
* `{connection: "disconnected"}` when a connection is closed
  and the JavaScript is not trying to reconnect.
  This will happen only after `act()` has been
  called with a "Close" instruction.

Finally, `toApp()` can be called with
* `{error: "Some error message"}`. This will happen if there is a
  websocket error and it isn't going to reconnect, if there is an
  attempt to send a message without the websocket being first opened,
  or if `act()` receives an instruction it doesn't recognise.

## Testing

The tests use the simple
[tape testing framework](https://github.com/substack/tape)

Install tape:
```
npm install tape --save-dev
```

Run the tests:
```
node tests.js
```

You can get [nicer output with a
reporter](https://github.com/substack/tape#pretty-reporters).
Then something like:
```
node tests.js | ../node_modules/.bin/tap-spec
```
