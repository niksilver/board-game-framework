# Paper, scissors, rock

[Play this game online.](https://niksilver.github.io/games/psr.html)
It is an example game made with the Elm
[board game framework](https://github.com/niksilver/board-game-framework/).

The game demonstrates two things:
* Each player has a hidden state - their hand is revealed only when both
  players have made their choice.
* Participants have roles, which can change. The game is for exactly two players;
  others are observers until one player leaves, at which point an observer
  can opt to become a player.

## Main files and compilation

* *src/Main.elm*. The main Elm app.
* *psr.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

Compile the Elm app using

```
elm make src/Main.elm --output=psr.js
```

and then use `elm reactor` to view `psr.html` to see it running.
You need reactor because it's a `Browser.application`,
which relies on running from a server, not the local filesystem.

## Application design

This section describes the general design of the application. Read it in conjunction
with the
[general board game framework
documentation](https://github.com/niksilver/board-game-framework/tree/master/docs).
Apart from the game concepts the sections below correspond to sections in
the `Main.elm` code.

### Game concepts

In paper, scissors, rock two players make a shape with their hand at the same time.
Paper beats rock, rock beats scissors, scissors beats paper.

As usual, any client must first choose their room (where they will find their friends
to play against). And in this version of the game we also then ask each client to
choose a name. Then they can enter the game proper.

A client must assume one of two roles: either a player (maximum two) or an observer.
A player can step down and become an observer. An observer can choose to be a player
if there is a vacancy.

A player can choose a shape only when there is another player.
As we cannot guarantee that both players will choose their shape at the same time
we allow each player to choose their shape in their own time, and we only show the players'
shapes once the second player has made their choice.

If either player has chosen a shape they can choose to "play again".

A player gets one points for a win. All clients have a score, even observers, because
anyone can switch roles

### The model and main types

First we'll look at the types for playing the main game, then step back and look
at the whole `Model`.

The playing state itself is just a collection of clients,
represented by the framework's
`Clients e` type. In this case we use `Clients Profile`, where `Profile` simply
maintains the `name`, `role` and `score` of each client. A client's role is
represented by the `Role` type, which is either `Observer` or `Player`.
If they're a player then they must have a `Hand` which is either `Closed` or `Showing`
some `Shape`.

(Note that `Clients Profile`, plural, is a collection of clients, while
`Client Profile`, singular, is one client. Sometimes we'll call the collection of
clients a "list", but it's not ordered.)

Now let's step back and look at the model from the top.

The `Model` has three fields. `myId` is always relevant, as it's given to all clients
as soon as they initialise. The `lobby` field is always relevant as it allows the
client to enter a room and change rooms, and it carries the configuration of that logic
specific to this implementation. Finally, we track our client's `progress` with
our `Progress` type.

Our client's progress is always in one of three states: `InLobby` is where we are
choosing a room; `ChoosingName` is after that; and finally we are `Playing`.
For `ChoosingName` we keep track of the name we've typed so far.
We also want the list of clients because at this
point we have joined the room and we have the client list
ready for when we show the playing screen.
For `Playing` we also keep the list of all clients, and also our name.
Keeping our name is useful because if we change room we can take our name with us.

Finally it's worth mentioning two more types. `NamedClient` is used simply when
we want to communicate to other clients the name we've chosen.
`Client PlayerProfile` is
useful when we want to deal with not just a client which might be an observer or a
player, but when we want to deal with a client that we know is a player, and therefore
has a hand.

### Message types

The `Msg` that's sent into the top level `update` function has the following variants:
* `ToLobby` is a wrapper for any message that needs to pass into the `lobby`.
* `NewDraftName` and `ConfirmedName` are for when we're typing our name into the text
  box and clicking the button to confirm it.
* `Received` carries any envelope received from the outside world. This might be
  a game message or something about our connectivity status.
  We'll discuss it a bit more below.
* The other `Confirmed...` variants indicate buttons pressed in the game:
  becoming an observer, becoming a player, choosing a hand shape, and clicking for
  another game.

The `Body` type describes a game-specific data sent between clients.
In this game we send changes to the playing state, and then (after calculating the
effect of a change) the playing state itself.
* `MyNameMsg` tells clients that we have a name
  for a client. A client is only added to the client list when it's got a name.
* `MyRoleMsg` is to announce that a client has changed their role. This includes
  when a player has played their hand - they might go from `Player Closed` to
  `Player (Showing Scissors)` for example.
* `ClientListMsg` is an update of the entire playing state, which is
  simply `Clients Profile`. But since this state needs to be synchronised between all
  the clients this is a `Sync (Clients Profile)`.
  See the `Sync` module for more there.

As mentioned above, the `Received` type tells us about a received an envelope.
The envelope itself can carry a `Body`, so it's of type `Envelope Body`. But since
it's been decoded from JSON it might also be a JSON decoding `Error`. So in fact
the `Received` message carries a `Result Error (Envelope Body)`.

### Client functions

The framework's `Clients` module allows us to handle a collection of clients specific
to our application. In our case we have `Client Profile`, which describes
a single client with a name, a role and a score (as well as its ID, which is implicit
in any `Client e`). `Clients Profile` describes a collection of these. We also
have `Client PlayerProfile` which describes a client we know to be a player;
this has a name, a hand and a score. Likewise a collection of these is a
`Clients PlayerProfile`.

Our client functions allow game-specific capabilities. There is some logic that
tries to ensure there are never more than two players in any `Clients Profile`,
which might happen when an observer becomes a player, or when a new client joins
(because they might have a player role). This logic could have been avoided
if we'd been rigid about "making impossible states impossible" and used something
with more structure than just a collection of `Clients`, but I judged that extra
structure as too much.

### Initialisation

Our application initialises with our client ID, but it also defines how our lobby
works, so most of the initialisation functions deal with that.

Our lobby copes with three situations as follows:
* `initBase`. With no other information our game progress puts us in the lobby.
* `initGame`. If we have a room name then we need to choose our name.
* `change`. If we change room then we'll take our name with us (or continue entering
  it if we're not yet playing).

The lobby also needs to be told how to open a server connection and how to
recognise its own messages that have been wrapped at this application level.

### Game connectivity

The code here simply defines how to open a connection to the server for a
particular room.

### Peer-to-peer messages

This section deals with receiving JSON values from an incoming port
and turning them into `Msg`s,
and sending application values to an outgoing port.

Since we have three types of data to send (a client with a name, a client whose
role has changed, and the latest playing state) we box up each type with
a label.
The `BoardGameFramework.Box` module does all the heavy lifting here, so take a look
at the documentation there for details.

### JSON encoders and decoders

Functions here primarily encode and decode the three data types we send to the
server: `NameForClient`, `RoleForClient` and `Sync (Clients Profile)`.
Therefore we have an `encode...` function and a `...Decoder` for each.

The standard Elm JSON modules are used, but we also rely on the
`encode` and `decoder` functions in both `BoardGameFramework.Clients`
`BoardGameFramework.Sync`.

### Updating the model

The section on updating the model is our standard Elm architecture `update` function
plus its supporting functions.
`update` itself passes off more complex decision-making into lower-level
`update...` functions, each of which returns the desired `(Model, Cmd Msg)` type.

`update` deals with these `Msg` cases:
* `ToLobby` is a message for our `Lobby`, so we unwrap it, ask the lobby to do
  its work, and update ourselves accordingly.
* `NewDraftName` is telling us a user has typed another character as their name
  during the `ChoosingName` stage.
* `ConfirmedName` is when they've confirmed it.
  If they confirm a name we're okay with then we'll send it to the other clients.
* `Received` carries an envelope from the server. We expect it to have been been JSON-decoded
  okay.
* The remaining `Confirmed...` messages are when a client clicks a button
  during the main game.

Then there are the lower-level functions.

`updateWithEnvelope` processes an envelope received from the server.
* We generally ignore a Welcome envelope, because we need a name before we allow
  ourselves into the client list of the main game. But if we switch from one
  room to another during the main game (when we have a name) then we'll get a
  welcome for that new room. So in that case we announce ourselves.
* We process a Peer envelope (with a `Body`) separately.
* A Joiner envelope is received any client when another one joins. We want to tell
  them the latest playing state. (We shouldn't get this message if we're `InLobby`, but
  we have to deal with that case anyway.)
* If we get a Leaver envelope we'll remove that client and send an updated playing
  state to everyone.
* We ignore connection information and other low-level errors.

`updateWithBody` processes one of the three kinds of data types sent between clients.
* For a client announcing themselves with a name we add them to our client list and
  send out that latest one.
* For a client with a role (or hand) change we pass that to a lower-level function.
* For an updated playing state, we simply resolve that with what we have already
  and retain whatever is correct.

`updateRoleFromServer` is for when an envelope from the server
has told us about a client's role changing.
By contrast `updateMyRole` is for when we have clicked a button
changing our role (or hand), in which case we'll want to send a message to the
server announcing this.

(A note on scoring: When a player changes their hand either player might win
that round and score a point. But we'll only award the point when we receive the
role change from the server. Otherwise there's a chance of awarding it twice -
when we click a button and when we get the envelope back from the server.)

`updateAnotherRound` is when some clicks "Play again". Within the function
`resetHand` will do this by making each `Player`'s hand closed.
Then we run that over all the clients within its `Sync` enclosure.
And now that we've calculated the new playing state we can send it to all the
other clients.


### The view

The view functions should be fairly standard. We use
[`elm-ui`](https://package.elm-lang.org/packages/mdgriffith/elm-ui/latest/) to
help us with the layout.

## Credits

* Paper image by [Alexander Skowalsky, HU ](https://thenounproject.com/search/?q=paper&i=979371)
* Scissors image by [Abid Muhammad, ID](https://www.pngitem.com/middle/hJmhwTi_sheet-of-paper-icon-paper-sheet-icon-hd/)
* Rock image by [Lemon Liu, NZ](https://thenounproject.com/term/stone/117090/)
