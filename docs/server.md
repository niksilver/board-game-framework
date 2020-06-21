# Server design

There are three core components in the Go code:

* The client reads input from the end user and sends messages (envelopes)
  out to the end user. One client per end user client connection.
  When it receives a message it passes it into the hub, and the hub
  tells it what messages to send out to the end user.
* A hub is a focal point for all clients in a given game. For example,
  If a message comes in from a client it sends it as a peer message
  to all other clients and as a receipt to the original client.
  It also handles joiner and leaver messages.
* The superhub looks after the relationship between clients and hubs.
  When a new client joins it gets its hub from the superhub. When a
  client disconnects it tells the superhub.

## Message flow

Flow of (envelope) messages (e.g. from the end user) is strictly
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
nums incrementing, without gaps. If a client finds it is disconnected
unwantedly then it should try to reconnect with a "lastnum" key, which
tells the server the last num it successfully received. As long as the
hub can fulfill this connection request (i.e. it still has envelopes from
that num onwards for that client ID) then the connection will be
successful and the new client will receive envelopes in continuation.
But if the client cannot fulfill the connection request then the request
is rejected and the connection is closed. The client will have to reconnect
as a new client (presumably using the same client ID).

This reconnection logic is managed between the hub and the superhub.
When the hub sends a message to any client it also stores the message
in a buffer.
When a client tells the hub it's disconnected the hub shuts down the client
but continues to remember it as a disconnected client. The hub will continue
to buffer messages for the disconnected client just as it does for
connected clients.

Also when the client shuts down it tells the superhub. The superhub
then starts a timer, allowing a few seconds for a reconnection by another
(logical) client using the same client ID. When the timer expires the
superhub sends a signal to the hub. When the hub receives that signal it takes
appropriate action: if there has been a reconnection since then it ignores
it, but if there hasn't been a reconnection then the hub forgets the
client and tells the other clients there has been a leaver.

## Nums and hubs

A new hub starts up when the first client in a new game connects.
The first message it sends has num 0. When the last client in that game
disconnects then the hub shuts down.
Therefore if several end users connect to a hub they will get increments
nums in their envelopes, but if all clients disconnect and don't reconnect
in good time, then those nums will start again from zero.

In practice what this means is that if an end user connects for one session,
disconnects, then reconnects without continuation for a second session,
then the nums in the second session might be lower than the nums in the
first session. However, the client can be sure that within one session
all nums will be incrementing without gaps.

## Fulfilling connection requests

Above, we said that a hub can fulfill a connection request if the client
connects with a lastnum and the hub has buffered envelopes for that
client (ID) to be able to continue sending later envelopes without
interruption. Of course, there is another situation where a hub can
fulfill a connection request: if the client doesn't send a lastnum.
This is just how an end user connects for the first time.

This allows us to explain an exceptional situation which should never
occur in practice but which you can manufacture if you want.
If one client connects, and then a second
client connects with the same ID and the hub can fulfill the connection
request, then the first client will be ejected - the first client will
be made a leaver (other clients will get a leaver message) and the
second client will join as a joiner (joiner and welcome messages will
be sent).

This rule helps ensure that there is only ever one end user with a
given client ID.
