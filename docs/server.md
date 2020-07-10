# Server design

There are three core components in the Go code:

* The client reads input from the end user and sends messages (envelopes)
  out to the end user. One client per end user client connection.
  When it receives a message it passes it into the hub.
  The hub also tells the client what messages to send out to the end user.
* A hub is a focal point for all clients in a given game. For example,
  If a message comes in from a client it sends it as a peer message
  to all other clients and as a receipt to the original client.
  It also handles welcome, joiner and leaver messages.
* The superhub looks after the relationship between clients and hubs.
  When a new client joins it gets its hub from the superhub.
  When a client disconnects it tells the superhub.

## Client initialisation

When the client starts it announces itself to the hub, and waits for
either a initial queue of messages or an error. In the event of an
error the websocket connection fails. Otherwise the websocket connection
is created and the client starts its send and receive goroutines.

## Message flow

After client initialisation, the
flow of messages (e.g. from the end user) is strictly
(i) into the client's receiveExt goroutine,
(ii) into the hub's receiveInt goroutine,
(iii) into the client's sendExt goroutine.

The only way the sendExt goroutine can communicate with the receiveExt
goroutine is by closing the websocket connection. receiveExt will then
pick this up and trigger a shutdown.

If receiveExt notices its connection is closed it sends a message to the
hub. The hub tells sendExt by closing the message channel between them.
Then the client can shut down.

## Clients in the hub

The hub tracks clients, and whether they are connected or disconnected.
It's important to track disconnected clients because we want to save messages
for them in case the end user reconnects.

## Reconnections

In theory only a client decides whether it should disconnect. However,
in practice network failures or unhappy loadbalancers can also cut the
connection. Therefore the server has to handle the situation that a
disconnected client is a mistake that the client will try to fix.

Every envelope has a "num" (an integer), which increments with each message.
As long as it is connected, a client will always see envelope
nums incrementing, without a gap in numbering.
If a client finds it is disconnected
unwantedly then it should try to reconnect with a "lastnum" key, which
tells the server the last num it successfully received, and that it would
like to continue receiving envelopes from the next num onwards. As long as the
hub can fulfill this request (i.e. it still has envelopes from
that num onwards for that client ID) then the connection will be
successful and the new client will receive envelopes in continuation.
But if the hub cannot fulfill the request then the connection fails.
The client will have to reconnect
without a lastnum (and presumably using the same client ID) to start
as a new client.

In the server, this
reconnection logic is managed between the hub and the superhub.
When the hub sends a message to any client it also stores the message
in a buffer.
When a client tells the hub it has been disconnected
the hub shuts down the client
but continues to remember it as a disconnected client. The hub will continue
to buffer messages for the disconnected client just as it does for
connected clients.

Also when the client shuts down it tells the superhub. The superhub
then starts a timer, allowing a few seconds for a reconnection by another
client using the same client ID. When the timer expires the
superhub sends a signal to the hub. When the hub receives that signal it takes
appropriate action: if there has been a reconnection since then it ignores
it, but if there hasn't been a reconnection then the hub forgets the
client and tells the other clients there has been a leaver.

## Fulfilling connection requests

What's implicit in all the above is that a hub can fulfill a connection
request in one of two circumstances.

* A client connects without
  a lastnum, in which case it gets a welcome message, and other clients
  are told about a new joiner.
* A client connects with a lastnum,
  and the hub had buffered messages from the next num onwards for that
  client ID. In this case the new client joins without any welcome or joiner
  messages, and it just receives envelopes with the next num onwards.
  If there was a previous client connected with that client ID then it
  gets disconnected. This last detail shouldn't happen in practice,
  but can be manufactured.
  This rule helps ensure that there is only ever one end user with a
  given client ID.

## Ordering of nums

A new hub starts up when the first client in a new game connects.
The first message it sends has num 0. When the last client in that game
disconnects then the hub shuts down.
Therefore if several end users connect to a hub they will get incrementing
nums in their envelopes, but if all clients disconnect and don't reconnect
in good time, then the num count is forgotten. The next client that joins
that game will get a num count starting from 0 again.

In practice what this means is that if an end user connects for one session,
disconnects, then reconnects without continuation for a second session,
then the nums in the second session might start off lower than the nums in the
first session. However, a client can be sure that within one session
all nums will be incrementing without gaps.

