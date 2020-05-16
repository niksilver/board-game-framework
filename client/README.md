# Board game framework

Elm client library for the board game framework, which makes it
easy to write networked games with just client-side code.

The principles of the framework are as follows:
Clients group together in a game using a common ID.
A client can send a message, which goes to all other clients, and the
server will additionally notify clients of any leavers and joiners.
Under the hood, communication is via websockets, so it is quite rapid,
although not suitable for real-time gaming.
There is no game-specific intelligence in the server.
Instead, all that is held by the clients.
This allows you to write a networked game simply by focusing on the
client code, and not worrying (too much) about the server.

The guts can be found at
* [https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)

