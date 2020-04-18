# Board game framework

A simple framework for building networked board games.

Clients (players) connect to a server. Each one joins a group, which
is the instance of a shared game. Clients are expected to maintain
the state of the game. All the server does is bounce any incoming
message from the sending client to all the other clients in the group.
Thus a message may be "This is my move", or "Please give me an
up to date state of the game", or anything else.

Inspired by the [open source version of Codenames](https://github.com/jbowens/codenames/).
