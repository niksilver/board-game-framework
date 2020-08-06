# Board game framework: Overview

A simple framework for building networked board games. All the game
intelligence is in the clients; the server simply provides the
communication.

Clients (players) connect to a server using websockets.
Each one joins a group, which is an instance of a shared game.
Clients are expected to maintain the state of the game.
All the server does is bounce any incoming message from a sending
client to all the other clients in the same game.
Thus a message may be saying "This is my move", or "Here is the
latest game state", or anything else.

Clients are intended to be written in Elm, but there is also a simple
JavaScript example.

* [Concepts](docs/concepts.md)
* [Elm API](../README.md)
* Example code:
  * A very simple JavaScript-only demo.
    * [Source code](https://github.com/niksilver/board-game-framework/tree/master/examples/simple-data-demo)
    * Live demo
  * The same thing, but demonstrating use of the Elm API.
    * [Source code](https://github.com/niksilver/board-game-framework/tree/master/examples/simple-data-demo)
    * Live demo
  * An example of clients joining in a lobby.
    * [Source code](https://github.com/niksilver/board-game-framework/tree/master/examples/lobby-names-demo)
    * Live demo
  * Multi-player noughts and crosses (aka tic tac toe).
    * [Source code](https://github.com/niksilver/board-game-framework/tree/master/examples/noughts-and-crosses)
    * Live demo
* [Details of the lower-level JavaScript layer](docs/javascript.md)
* [Server design principles](docs/server.md)
* [Server code](https://github.com/niksilver/board-game-framework-server/)

Inspired by the [open source version of Codenames](https://github.com/jbowens/codenames/).
