# The JavaScript layer

The Javascript layer is in `js/board-game-framework.js`. It provides
a connection layer between the client application and the server. It:
* offers an Open action to open a websocket;
* offers a Close action to close the websocket;
* passes a received envelope into the application;
* passes an error envelope into the application if there is a problem.
* attempts reconnection if the connection drops;
* passes a Closed envelope into the application if reconnection fails.


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
