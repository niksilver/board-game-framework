# General concepts

This document describes general concepts, regardless of what
layer of the system we're looking at. These concepts are
described in general terms, independent of programming language.

## Overview of concepts

Once a client connects to the server it can send and receive messages.
A client sends a simple message (almost certainly JSON).
The server wraps it in an envelope with some metadata,
and sends that out to all the clients,
including the client which originally sent it.
The server also sends envelopes when clients leave and join the game.

Each envelope sent by the server has an "intent",
which describes the nature of the envelope contents.
These are the envelope intents that a client can receive:

* Welcome. Received by a client when it joins.
* Joiner. Received by a client when a new client joins the game.
* Leaver. Received by a client when a client leaves the game.
* Peer. Containing a message sent by another client.
* Receipt. Containing the client's own message when it sends one.

A JavaScript small layer sits between a client application and the server
to make connectivity easier. It adds two other kinds of messages for clients:

* Connection. Provides a simple update when the connection status changes.
* Error. If there is some error either decoding JSON or with the connection.

## Connecting to the server

When a client connects to the server for the first time it is given a
unique ID, which is a string: two long integers separated by a dot.
The unique ID only lasts until the page is reloaded.

## Envelope basics

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
  Num: 8
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
* `Num` is an integer envelope number. The `Num` will increment
   for each new envelope the client receives.
* `Time` is the server time the message was sent, which is an integer
  number of milliseconds after 1 January 1970;
* `Intent` is what the envelope contains - in this case, a message from
   a client peer.
* `Body` is the original message from the client.

The fields `From`, `To`, `Num`, `Time` and `Intent` appear in all
envelopes apart from Closed, which doesn't have any other fields.

The Elm library adjusts the names slightly to help with type safety
and consistency between these types.

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

If a client is given ID `123.456` when it joins a game with `222.234`
and `333.345` then the envelope it receives looks like this:


```
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


```
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Time: 76487293
  Intent: "Joiner"
}
```

The `Num` and `Time` fields will be the same in all Joiner envelopes,
and they will be the same as the `Num` and `Time` fields in the
new client's Welcome envelope. This is to aid synchronisation, if needed.

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


```
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Time: 76487293
  Intent: "Leaver"
}
```

### Peer

See details above for what's in a Peer envelope.

### Receipt

When a client sends a message, not only to the other clients receive
a Peer envelope, but it receives the its own message back as a Receipt
envelope. When a client receives a Receipt envelope it is exactly
the same as the Peer envelope received by others, except that the
`Intent` field has the value `Receipt`.

So suppose, as above,
client `123.456` is in a game with two other clients, `222.234`
and `333.345`. If it sends a game message that looks like this

```
{ turn: 0
  spaces: 3
  letters: ["D", "K", "G"]
}
```

it will receive a Receipt that looks like something like this:

```
{ From: ["123.456"]
  To: ["222.234", "333.345"]
  Num: 8
  Time: 76487293
  Intent: "Receipt"
  Body: { turn: 0
          spaces: 3
          letters: ["D", "K", "G"]
        }
}
```
Just as with the Welcome/Joiner envelopes, the corresponding
Peer/Receipt envelopes will all have the same values in the
`Num` and `Time` fields. This is to aid synchronisation.


### Connection messages

See documentaton on the Elm and Javascript libraries for more on these,
as the details are specific to each library.

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
will all have the same Num, and a Receipt envelope and its corresponding
Peer envelopes will all have the same Num.

## Limits

The server puts a 60k limit on messages it receives.
It will close a client's connection if it breaches this limit.

Each game instance can have a maximum of 50 connected clients. Any more will
get a websocket connection that closes immediately with an appropriate
message.
