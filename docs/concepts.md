# General concepts

This document describes general concepts of the board game framework,
These concepts are
described in general terms, mostly independent of programming language.

## Don't just read - try it!

While reading this documentation you can play around and see the ideas
in action.
Go to either [the simple JavaScript
demo](https://niksilver.github.io/games/simple-js.html)
or
[the equivalent Elm
demo](https://niksilver.github.io/games/simple-elm.html).
Play around with it. Bring it up in two or more browser tabs to see
what happens when multiple clients connect.
Try using different room names.
All the while, watch what messages get received by each client.

These simple applications are also a really good way to see what happens
in a real application, such as the [noughts and crosses
game](https://niksilver.github.io/games/ooxx.html). If you connect
the simple JavaScript or Elm demo to the noughts and crosses
game then you'll be able to see what messages it sends out.
Don't forget to use the same room name.

You can also use the simple
demos to send a JSON message which the game won't be able to interpret -
that might be useful if you want to see how your own application
handles a nonsensical message.

## Overview of concepts

Once a client connects to the server it can send and receive messages.
A client sends a simple message (almost certainly JSON).
The server wraps it in an envelope with some metadata
and sends that out to all the clients,
including the client which originally sent it.
The server also sends envelopes when clients leave and join the game.

Each envelope sent by the server has an "intent",
which describes the nature of the envelope contents.
These are the envelope intents that a client can receive:

* Welcome. Received by a client when it joins.
* Joiner. Received when another new client joins the game.
* Leaver. Received when another client leaves the game.
* Peer. Envelope containing a message sent by any client, including oneself.

A small JavaScript layer sits between a client application and the server
to make connectivity easier. It adds two other kinds of messages for clients:

* Connection. Provides a simple update when the connection status changes.
* Error. If there is some error with the connectivity.

## Connecting to the server

A server can host many distinct games at one time, each in its own named "room".
At the time of writing
there is a server which can be used freely at `bgf.pigsaw.org` (this
one happens to accept both SSL and non-SSL connections).

Each game on that server is identified
by a simple string - a room name - which brings together all the client
players. The room name is randomly generated by one of the clients and
is shared between friends. If the room name is, say, `closely-aside`
then the server connection needed is `wss://bgf.pigsaw.org/g/closely-aside`.

But that's within the game logic. The user will be playing the game
on some web page and will see a different URL. Typically this will
be something like `https://example.com/backgammon#closely-aside`.
This is a link friends can share. The game logic can look at the URL
fragment and use that to construct the server URL.

## Client IDs

When the JavaScript layer is initialised it creates a unique client
ID, which is a string: two long integers separated by a dot.
The unique ID only lasts until the page is reloaded.
The ID allows clients to identify and distinguish each other.

## Envelope basics

When a client sends a message to the server, the server wraps it in an
envelope and sends that envelope to all other clients in the same game,
including the client which sent it.

Suppose client `123.456` is in a game with two other clients, `222.234`
and `333.345`. If it sends some arbitrary game message that looks like this

```js
{ turn: 0
  spaces: 3
  letters: ["D", "K", "G"]
}
```

it will be wrapped and sent to the other clients like this:

```js
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Num: 8
  Time: 76487293
  Intent: "Peer"
  Receipt: false
  Body: { turn: 0
          spaces: 3
          letters: ["D", "K", "G"]
        }
}
```

* `From` is a singleton list with the sending client's ID;
* `To` is a list with the IDs of all other clients who are currently
   connected in that game;
* `Num` is an integer envelope number. The `Num` will increment
   for each new envelope the client receives.
* `Time` is the server time the message was sent, which is an integer
  number of milliseconds after 1 January 1970;
* `Intent` is what the envelope contains - in this case, a message from
   a client peer.
* `Receipt` says whether this message is an echo of one sent by this client.
* `Body` is the original message from the client.

The fields `From`, `To`, `Num`, `Time` and `Intent` appear in all
envelopes apart from Closed, which doesn't have any other fields.

*Note:* The Elm library adjusts these names slightly to exploit type safety
and consistency. See [the Elm API documentation](../README.md)
for details.

## Envelope details

A few more details about each envelope intent.

### Welcome

A `"Welcome"` envelope is received by a client immediately after it
connects. This enables the client to find out what its ID is and the
IDs of the other clients connected.
The `From` field is a list with the IDs of all the other clients.
The `To` field is a singleton list with the client's own ID.
Together, the `To` and `From` fields contain the IDs of all clients
currently connected.
There is no `Body`.
Additionally it will have `Num` and `Time` fields.

If a client has ID `123.456` and it joins a game with `222.234`
and `333.345` then the envelope it receives looks like this:

```js
{ From: ["222.234", "333.345"]
  To: ["123.456"]
  Time: 76487293
  Intent: "Welcome"
}
```

### Joiner

A `"Joiner"` envelope is received by all existing clients after a new one
connects.
It helps all existing clients update their record of current clients, if
they want to do that.
The `From` field is a singleton list with the new client's ID.
The `To` field is a list of all existing clients.
Together, the `To` and `From` fields contain the IDs of all clients
currently connected.
There is no `Body` field.
Additionally it will have `Num` and `Time` fields.

If client `123.456` connects to a game currently with clients `222.234`
and `333.345` then this is the format of the envelope those last two
clients receive:


```js
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Time: 76487293
  Intent: "Joiner"
}
```

The `Num` and `Time` fields will be the same in all Joiner envelopes,
and they will be the same as the `Num` and `Time` fields in the
new client's corresponding Welcome envelope.
This is to aid synchronisation, if needed.

### Leaver

A `"Leaver"` envelope is received by all existing clients when one
disconnects.
It helps all existing clients update their record of current clients, if
they want to do that.
The `From` field is a singleton list with the ID of the client that's left.
The `To` field is a list of all remaining clients.
This means that, unlike the `"Welcome"` and `"Joiner"` envelopes,
the up to date client list is in just the `To` field, not `To` and `From`
combined.
Additionally the envelope will have `Num` and `Time` fields.
There is no `Body` field.

If client `123.456` leaves a game with clients `222.234`
and `333.345` then this is the format of the envelope those last two
clients receive:

```js
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Time: 76487293
  Intent: "Leaver"
}
```

See below for how a client becomes a leaver.

### Peer

As explained above, when a client sends a message it is received by
those other clients as a Peer envelope, and the Receipt field is false.

Additionally, the sending client receives its own message back.
This received message is exactly the same one as all the other clients
receive, except that the Receipt field is true.

So suppose, as above,
client `123.456` is in a game with two other clients, `222.234`
and `333.345`. If it sends a game message that looks like this

```js
{ turn: 0
  spaces: 3
  letters: ["D", "K", "G"]
}
```

it will receive a Peer envelope that looks like this:

```js
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Num: 8
  Time: 76487293
  Intent: "Peer"
  Receipt: true
  Body: { turn: 0
          spaces: 3
          letters: ["D", "K", "G"]
        }
}
```

Just as with the Welcome/Joiner envelopes, the
Peer envelopes will all have the same values in the
`Num` and `Time` fields. This is to aid synchronisation.

### Connection messages

See documentation on the [Elm API](../README.md) and the
[Javascript library](javascript.md) for more on these,
as the details are specific to each library.

## Becoming leaver

If a client disconnects from the server for more than 5 seconds the
server will regard it as a leaver, and send out a Leaver envelope to
the remaining clients. The JavaScript layer will try to reconnect
if it detects a disconnection (unless it's been told to close the
connection, of course), so a quick network glitch shouldn't trigger
a leaver envelope. If it rejoins within 5 seconds then it's still
regarded as in the game and won't miss out on any envelopes.

However, if a disconnected client reconnects after the 5 second period
then it will receive a Welcome message. The other clients will see it
as first a leaver and then a joiner.

## Message ordering

The first message received by a client is its welcome message.
After that, any messages will be received in the order in which
the server receives them. However, that order is not certain.
For example, if client C1 sends message M1 at roughly the same time
as client C2 sends message M2, then it's not certain which message
the server picks up first.

However, the Num field is useful for tracking order.
Every envelope a client receives will have an incrementing Num,
and when the server sends out a batch of envelopes they will all have
the same Num: a Welcome envelope and its corresponding Joiner envelopes
will all have the same Num, and a batch of
Peer envelopes will all have the same Num.

The Num only resets for a game after all clients have left.
That means if several clients join a game, then all leave, then one of
them joins again, its Welcome message will almost certainly be lower
than the last Num it received before it left.

## Limits

The server puts a 60k limit on messages it receives.
It will close a client's connection if it breaches this limit.

Each game instance can have a maximum of 50 connected clients. Any more will
get a websocket connection that closes immediately with an appropriate
message.
