# Board game framework

Elm client library for the board game framework, which makes it
easy to write networked games with just client-side code. See also:
* [Concepts](docs/concepts.md)
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
* [Details of the lower-level JavaScript layer](docs/javascript.md)
* [Server design principles](docs/server.md)
* [Server code](https://github.com/niksilver/board-game-framework-server/)

The principles of the framework are as follows:
Clients join a game using a common ID.
A client can send a message, which goes to all other clients.
The server will additionally notify clients of any leavers and joiners.
Under the hood, communication is via websockets, so it is quite rapid,
although not suitable for real-time gaming.
There is no game-specific intelligence in the server;
instead, all that is held by the clients.
This allows you to write a networked game simply by focusing on the
client code, and not worrying (too much) about the server.

Key elements of any board game will be:
* Generating a random game ID for your players;
* Connecting to the server with that game ID;
* Exchanging data with the other clients.

You don't need to worry about disconnecting, but you can if you like.

You don't need to build your own server---there is currently one
available to you---but if you would really like to, then you can
[check out the server
code](https://github.com/niksilver/board-game-framework-server).

# Writing your own game

The best way to see how to write your own board game is to look at the
examples. But here are some particular things to look out for.

## Integrating with the JavaScript layer

Every game will need to communicate with the server (and the other clients)
via ports. To embed your app into a web page you will need this code, where
`lobby-names.js` is the JavaScript file your Elm code has been compiled into:

```html
    <!-- Load the Javascript library for our board game framework -->
    <script type="text/javascript" src="lib/board-game-framework.js"></script>
    <!-- Load our Elm app -->
    <script type="text/javascript" src="lobby-names.js"></script>
    </head>
    <body>
        <script>var app = Elm.Main.init();</script>
    </body>
    <script type="text/javascript">
        // Set up an instance of our connectivity library
        var bgf = new BoardGameFramework();

        // Link incoming envelopes to our app
        bgf.toApp = function(env) {
            app.ports.incoming.send(env);
        };

        // List out for data coming out of our Elm app
        app.ports.outgoing.subscribe(function(data) {
            bgf.act(data);
        });
    </script>
```
See this repository for
[the JavaScript layer `board-game-framework.js`](https://github.com/niksilver/board-game-framework/tree/master/examples/simple-data-demo/lib).

In your Elm code you need to define a ports module and its ports, like this:

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

To connect to a game, a client needs use an appropriate URL. This is
something like

```
ws://bgf.pigsaw.org/g/blue-elegant
```

The `ws:` says it's a secure websocket. (Use `wss` for a secure websocket
connection, if the server offers one.)
`bgf.pigsaw.org` is the domain name of the server.
That particular name is a public server
and is currently available for anyone to use, but you could deploy your own
server anywhere. `/g/` is required for all games. `blue-elegant` is
some randomly-generated string for our unique game; it's the game ID.
All clients connecting to that URL will see each other in the same game.

To open a connection you issue an `Open` instruction. For example:

```elm
import BoardGameFramework as BGF


openCmd : String -> Cmd Msg
openCmd url =
  BGF.Open url
  |> BGF.encode bodyEncoder
  |> outgoing
```

Here, `bodyEncoder` is a function we have defined to encode our
game-specific messages into JSON, and remember that `outgoing`
is the outbound port we defined earlier.

To disconnect from the server you can do something similar:

```elm
import BoardGameFramework as BGF


closeCmd : Cmd Msg
closeCmd =
  BGF.Close
  |> BGF.encode bodyEncoder
  |> outgoing
```

## Sending a message

To send a message you need to be able to encode
that message, which is some type of our choosing, into JSON.
All messages go to all clients (even to yourself, because
you'll get a receipt).

Here's an example of some type `Body` and how you might encode it:

```elm
import Json.Encode as Enc
import BoardGameFramework as BGF


type alias Body =
  { players : Dict String String
  }


bodyEncoder : Body -> Enc.Value
bodyEncoder body =
  Enc.object
  [ ("players" , Enc.dict identity Enc.string body.players)
  ]
```

Now you can define a function to send it:

```elm
sendBodyCmd : Body -> Cmd Msg
sendBodyCmd body =
  BGF.Send body
  |> BGF.encode bodyEncoder
  |> outgoing
```

## Receiving messages

To receive messages you need to create an inbound port and a JSON
decoder, which will decode the messages that were encoded as we saw
above:


```elm
import Json.Decode as Dec
import BoardGameFramework as BGF


port incoming : (Enc.Value -> msg) -> Sub msg


bodyDecoder : Dec.Decoder Body
bodyDecoder =
  let
    playersDec =
      Dec.field "players" (Dec.dict Dec.string)
  in
    Dec.map Body
      playersDec
```

But incoming messages are more than just our `Body` type - they are
`Envelope`s of data. If the envelope contains a message from another
client (or a receipt of a `Body` we've sent) it will come with metadata.
But an envelope can also tell you about leavers, joiners, and
changed connection states. So we can define an envelope specifically for
our `Body` type:

```elm
type alias Envelope = BGF.Envelope Body
```

When we use our JSON decoder to decode an envelope you may get error.
That might be because it doesn't recognise the JSON it received, or there
might be some other low-level error. So the result of that decoding
will be `Result BGF.Error Envelope`. To feed that into our application
you can usefully make it part of our usual `Msg` type:


```elm
type Msg =
  -- Some message tags not shown
  -- ...
  | Received (Result BGF.Error Envelope)
```

And given all of that, you can now create a `subscriptions` function
that listens to the `incoming` port, decodes the envelopes, and packages
them up as a `Msg` for our model.

```elm
subscriptions : Model -> Sub Msg
subscriptions model =
  incoming decode


decode : Enc.Value -> Msg
decode v =
  BGF.decode bodyDecoder v |> Received
```
All you need to do now is make sure your application actually subscribes
to the `subscription` function.

# Credits

This framework has been inspired by the online version of
Codenames at [horsepaste.com](https://www.horsepaste.com/). Try it.
