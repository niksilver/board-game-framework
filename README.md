# Board game framework

A simple framework for building networked board games. All the game
intelligence is in the clients; the server simply provides the
communication.

Clients (players) connect to a server. Each one joins a group, which
is the instance of a shared game. Clients are expected to maintain
the state of the game. All the server does is bounce any incoming
message from a sending client to all the other clients in the group.
Thus a message may be "This is my move", or "Please give me an
up to date state of the game", or anything else.

Inspired by the [open source version of Codenames](https://github.com/jbowens/codenames/).

## Connecting to the server

When a client connects to the server for the first time it is given a
unique ID. The unique ID persists with the client, even beyond any end
of the game.

The ID is stored in a cookie related to a websocket connection, not
an HTTP connection.

## Sending a message

When a client sends a message to the server it is wrapped in an
envelope and sent to all other clients in the same game.

Suppose client `123.456` is in a game with two other clients, `222.234`
and `333.345`. If it sends some arbitrary game message that looks like this

```
{ turn: 0
  spaces: 3
  letters: ["D", "K", "G"]
}
```

it will be wrapped and sent to the other clients like this:

```
{ From: "123.456"
  To: ["222.234", "333.345"]
  Time: 76487293
  Msg: { turn: 0
         spaces: 3
         letters: ["D", "K", "G"]
       }
}
```
`From` is the sending client's ID; `To` is the ID of all other clients who
are currently connected in that game; `Time` is the server time the
message was sent, which is an integer number of seconds after 1 January 1970;
`Msg` is the original message from the client.

