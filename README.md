# Board game framework

Elm client library for the board game framework, which makes it
easy to write networked games with just client-side code.

The principles of the framework are as follows:
Clients join a game using a common ID.
A client can send a message, which goes to all other clients.
The server will additionally notify clients of any leavers and joiners.
Under the hood, communication is via websockets, so it is quite rapid,
although not suitable for real-time gaming.
There is no game-specific intelligence in the server;
instead, all that is held by the clients.
This allows you to write a networked game simply by focusing on the
client code, and not worrying (too much) about the server.

Key elements of any board game will probably be:
* Generating a random game ID for your players;
* Connecting to the server with that game ID;
* Exchanging data with the other clients.

You don't need to worry about disconnecting, but you can if you like.

For more detailed documentation see [the online
docs](https://github.com/niksilver/board-game-framework/docs/README.md)

You do not need to build your own server---the library makes one
available to you---but if really would like to, then you can
[check out the server
code](https://github.com/niksilver/board-game-framework-server).

