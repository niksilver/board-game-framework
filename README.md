# Board game framework

A simple framework for building networked board games. All the game
intelligence is in the clients; the server simply provides the
communication.

Clients (players) connect to a server using websockets.
Each one joins a group, which is an instance of a shared game.
Clients are expected to maintain the state of the game.
All the server does is bounce any incoming message from a sending
client to all the other clients in the same game (instance).
Thus a message may be saying "This is my move", or "Please give me an
up to date state of the game", or anything else.

Inspired by the [open source version of Codenames](https://github.com/jbowens/codenames/).

## Connecting to the server

When a client connects to the server for the first time it is given a
unique ID, which is a string. The unique ID persists with the client,
even beyond any end of the game.

The ID is stored in a cookie related to a websocket connection, not
an HTTP connection, so you won't find it in the usual place in the browser.

## Sending a message

When a client sends a message to the server, the server wraps it in an
envelope and sends that envelope to all other clients in the same game.

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
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Time: 76487293
  Intent: "Peer"
  Body: { turn: 0
          spaces: 3
          letters: ["D", "K", "G"]
        }
}
```
* `From` is a singleton list with the sending client's ID;
* `To` is a list with the IDs of all other clients who are currently
   connected in that game;
* `Time` is the server time the message was sent, which is an integer
  number of seconds after 1 January 1970;
* `Intent` is what the envelope contains - in this case, a message from
   a client peer.
* `Body` is the original message from the client.

## Intents

Most envelopes carry a message from another client, which is found in
the envelope `Body`. The intent of such an envelope is `"Peer"`.
There are other intents, too.

A `"Welcome"` envelope is received by a client immediately after it
connects. This enables the client to find out what its ID is.
The `From` field is a list with the IDs of all the other clients.
The `To` field is a singleton list with the client's own ID.
Together, the `To` and `From` fields contain the IDs of all clients
currently connected.
There is no `Body`.
This is the format of the envelope sent to client `123.456` after it joins:


```
{ From: ["222.234", "333.345"]
  To: ["123.456"]
  Time: 76487293
  Intent: "Welcome"
}
```

A `"Joiner"` envelope is received by all existing clients after a new one
connects.
It helps all existing clients update their record of current clients, if
they want to do that.
The `From` field is a singleton list with the new client's ID.
The `To` field is a list of all existing clients.
Together, the `To` and `From` fields contain the IDs of all clients
currently connected.
There is no `Body` field.
If client `123.456` connects to a game currently with clients `222.234`
and `333.345` then this is the format of the envelope those last two
clients receive:


```
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Time: 76487293
  Intent: "Joiner"
}
```

Note that it's possible for a two clients to join a game with the same ID.
This will happen if a user opens another browser window and connects
to the same game, because that second browser window will reuse the ID
cookie. In these cases the `From` and `To` fields in the "welcome" and
"joiner" envelopes can still be appended to create a complete list of
clients, and no client ID will be duplicated.

(To allow a user to connect multiple times and get different IDs they
should use private browser windows for the second and subsequent
connections.)

