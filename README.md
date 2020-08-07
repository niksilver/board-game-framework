# Board game framework

Elm client library for the board game framework, which makes it
easy to write networked games with just client-side code.
If this is your first time here, it's best to
[look at the overview and examples](docs/README.md) before going further.

Key elements of any board game will be:
* Generating a random game ID for your players;
* Connecting to the server with that game ID;
* Exchanging data with the other clients.

You don't need to worry about disconnecting, but you can if you like.

You don't need to build your own server - there is currently an SSL server
available to you at `bgf.pigsaw.org` -
but if you would really like to, then you can
[check out the server
code](https://github.com/niksilver/board-game-framework-server).

# Writing your own game

The best way to see how to write your own board game is to look at the
examples. But here are some particular things to look out for.

## Integrating with the JavaScript layer

Every game will need to communicate with the server (and the other clients)
via ports. To embed our app into a web page we will need a simple
HTML and JavaScript shell page.
For a good simple example take a look at [the HTML for the lobby names
code](https://github.com/niksilver/board-game-framework/blob/master/examples/lobby-names/lobby-names.html).

The key parts of this HTML and JavaScript shell are:
* Include the board game framework's JavaScript layer,
  [`board-game-framework.js`](https://github.com/niksilver/board-game-framework/tree/master/examples/simple-data-demo/lib).
* Create a new instance of the board game framework.
* Initialise the Elm app, including our client ID as a flag.
* Set up the inbound and outboard Elm ports.

Then in our Elm code we need to define a ports module and its ports,
like this:

```elm
port outgoing : Enc.Value -> Cmd msg
port incoming : (Enc.Value -> msg) -> Sub msg
```

`outgoing` allows us to send some game-specific message (encoded as JSON)
to the other clients. `incoming` allows us to subscribe to incoming
envelopes from the server. These envelopes may contain messages
from other clients (which we'll have to decode from JSON to Elm values)
or messages about the state of the server connection.

## Connecting and disconnecting to the server

To connect to a game, our client code needs to know the name of the
server, and a unique game ID that will bring together all the players:

```elm
import BoardGameFramework as BGF

server : BGF.Server
server = BGF.wssServer "bgf.pigsaw.org"

openCmd : BGF.GameId -> Cmd Msg
openCmd id =
  BGF.open outgoing server id
```

Now we can use the `openCmd` function to issue a `Cmd Msg` to connect
to the server with some game ID.

The game ID is typically a simple string which is easy to communicate
to other players, and each to remember.
The API provides a function for randomly generating nice game IDs
as two English words separated by a hyphen.

To disconnect from the server we simply call

```elm
BGF.close outgoing
```

## Sending a message

To send a message to the other clients we need to be able to encode
that message. The message is any Elm type of our choosing, and we
need to be able to encode that into JSON.
All messages go to all clients (even to ourselves, because
we'll get a receipt).

Here's an example of some type `Body` and how we might encode it:

```elm
import Json.Encode as Enc
import BoardGameFramework as BGF

type alias Body =
  { id : String
  , name : String
  }

bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  Enc.object
  [ ("id" , Enc.string body.id)
  , ("name" , Enc.string body.name)
  ]
```

Now we can define a convenience function to send a `Body` message:

```elm
sendCmd : Body -> Cmd Msg
sendCmd body =
  BGF.send outgoing bodyEncoder body
```

## Receiving messages

To receive messages we use our inbound `incoming` port defined
above, plus a JSON decoder:

```elm
import Json.Decode as Dec
import BoardGameFramework as BGF

bodyDecoder : Dec.Decoder Body
bodyDecoder =
  Dec.map2
    Body
    (Dec.field "id" Dec.string)
    (Dec.field "name" Dec.string)
```

But incoming messages are more than just our `Body` type - they are
`Envelope`s of data. If the envelope contains a message from another
client (or a receipt of a `Body` we've sent) it will come with metadata.
We might also receive an envelope that tells us about leavers, joiners, and
changed connection states. So we can define an envelope specifically for
our `Body` type:

```elm
type alias MyEnvelope = BGF.Envelope Body
```

When we use our JSON decoder to decode an envelope we may get error.
That might be because it doesn't recognise the JSON it received, or there
might be some other low-level error. So the result of that decoding
will be `Result BGF.Error MyEnvelope`. To feed that into our application
we can usefully make it part of our usual `Msg` type:


```elm
type Msg =
  -- Some message tags not shown
  -- ...
  | Received (Result BGF.Error MyEnvelope)
```

And given all of that, we can now create a `subscriptions` function
that listens to the `incoming` port, decodes an envelope, and packages
it up as a `Msg` for our model.

```elm
subscriptions : Model -> Sub Msg
subscriptions model =
  incoming receive

receive : Enc.Value -> Msg
receive v =
  BGF.decode bodyDecoder v
  |> Received
```

All we need to do now is make sure our application actually subscribes
to the `subscription` function.

# Credits

This framework has been inspired by the online version of
Codenames at [horsepaste.com](https://www.horsepaste.com/). Try it.
