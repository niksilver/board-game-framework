-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  GameId, gameId, fromGameId , idGenerator
  , Server, wsServer, wssServer, withPort, Address, withGameId, toUrlString
  , ClientId
  , Envelope(..), Connectivity(..), Error(..), open, send, close
  , encode, decode
  )

{-| Types and functions help create remote multiplayer board games
using the related framework. See
[https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)
for detailed documentation and example code.

# Game IDs
Enable players to a unique game ID, so they can join up with each other.
@docs GameId, gameId, fromGameId, idGenerator

# Connecting
@docs Server, wsServer, wssServer, withPort, Address, withGameId, toUrlString

# Basic actions: open, send, close
@docs open, send, close

# Receiving messages
Any message another client sends gets wrapped in envelope, and we get the
envelope. Communication under the hood is in JSON, so we need to say
how to decode our application's JSON messages into some suitable Elm type.
@docs ClientId, Envelope, Connectivity, Error, decode
-}


import String
import Random
import Json.Encode as Enc
import Json.Decode as Dec
import Result
import Url exposing (Url)

import Words


{-| A game ID represents a game that multiple players can join.
It's a string intended to be shared among intended players.
-}
type GameId = GameId String


{-| Turn a string into a game ID.
A good game ID will have a good chance of being unique and wil be easy
to communicate, especially in URLs.
This test passes if it's five to thirty characters long (inclusive)
and consists of just alphanumerics, dots, dashes, and forward slashes.

    gameId "pancake-road" == Ok "pancake-road"
    gameId "backgammon/pancake-road" == Ok "pancake-road"
    gameId "#345#" == Err "Bad characters"
    gameId "road" == Err "Too short"
-}
gameId : String -> Result String GameId
gameId str =
  let
    goodChar c =
      Char.isAlphaNum c || c == '-' || c == '.' || c == '/'
  in
  if String.length str < 5 then
    Err "Game ID too short"
  else if String.length str > 30 then
    Err "Game ID too long"
  else if String.all goodChar str then
    Ok (GameId str)
  else
    Err "Bad characters in game ID"


{-| Extract the game ID as a string.
-}
fromGameId : GameId -> String
fromGameId (GameId str) =
  str


{-| A random name generator for game IDs, which will be of the form
"_word_-_word_".

To create a `Cmd` that generates a random name, we can use code like this:
    import Random
    import BoardGameFramework as BGF


    -- Make sure our Msg can handle a generated game id
    Msg =
      ...
      GeneratedGameId GameId
      ...


    -- Our update function
    update : Msg -> Model -> (Model, Cmd)
    update msg model =
      case msg of
        ... ->
          (updatedModel, Random.generate GeneratedGameId BGF.idGenerator)

        GeneratedGameId gameId ->
          -- Use the generated game ID
-}
idGenerator : Random.Generator GameId
idGenerator =
  case Words.words of
    head :: tail ->
      Random.uniform head tail
      |> Random.list 2
      |> Random.map (\w -> String.join "-" w)
      |> Random.map GameId

    _ ->
      Random.constant (GameId "xxx")


{-| A board game server.
-}
type Server =
  Server
    { start : String
    , mPort : Maybe Int
    }


{-| Create a `Server` that uses a websocket connection (not a secure
websocket connection). For example
    wsServer "bgf.pigsaw.org"
will allow us to make connections of the form `ws://bgf.pigsaw.org/...`.
-}
wsServer : String -> Server
wsServer domain =
  Server
    { start = "ws://" ++ domain
    , mPort = Nothing
    }


{-| Create a `Server` that uses a secure websocket connection.
A call of the form
    wssServer "bgf.pigsaw.org"
will allow us to make connections of the form `wss://bgf.pigsaw.org/...`.
-}
wssServer : String -> Server
wssServer domain =
  Server
    { start = "wss://" ++ domain
    , mPort = Nothing
    }


{-| Explicitly set the port of a server, if we don't want to connect to
the default port. The default port is 80 for insecure connections and
443 for secure connections.
    wsServer "localhost" |> withPort 8080    -- ws://localhost:8080
-}
withPort : Int -> Server -> Server
withPort portInt (Server server) =
  Server
    { start = server.start
    , mPort = Just portInt
    }



{-| The address of a game which we can connect to.
-}
type Address =
  Address
    { start : String
    , mPort : Maybe Int
    , gameId : GameId
    }


{- | Create the address of an actual game we can connect to.

    -- If we have game ID `gid1` as `"voter-when"` and
    -- game ID `gid2` as `"poor-modern"` then...
    wsServer "localhost"
    |> withPort 8080
    |> withGameId gid1    -- We will join `ws://localhost:8080/g/voter-when`
    |> withGameId gid2    -- Changes to `ws://localhost:8080/g/poor-modern`
-}
withGameId : GameId -> Server -> Address
withGameId gId (Server server) =
  Address
    { start = server.start
    , mPort = server.mPort
    , gameId = gId
    }


toUrlString : Address -> String
toUrlString (Address addr) =
  let
    portStr =
      case addr.mPort of
        Just p ->
          ":" ++ String.fromInt p
        Nothing ->
          ""
  in
  addr.start ++ portStr ++ "/g/" ++ (fromGameId addr.gameId)


{-| The unique ID of any client.
-}
type alias ClientId = String


{-| A message from the server, or the connection layer.
See [the concepts document](https://github.com/niksilver/board-game-framework/blob/master/docs/concepts.md)
for many more details.

The envelopes are:
* A welcome when our client joins;
* A receipt containing any message we sent;
* A message sent by another client peer;
* Notice of another client joining;
* Notice of another client leaving;
* Change of status with the server connection.

The field names have consistent types and meaning:
* `me`: our client's own ID.
* `others`: the IDs of all other clients currently in the game.
* `from`: the ID of the client (not us) who sent the message.
* `to`: the IDs of the clients to whom a message was sent, including us.
* `joiner`: the ID of a client who has just joined.
* `leaver`: the ID of a client who has just left.
* `num`: the ID of the envelope. After a Welcomem envelope, nums will
  be consecutive.
* `time`: when the envelope was sent, in milliseconds since the epoch.
* `body`: the application-specific message sent by the client.
  The message is of type `a`.
-}
type Envelope a =
  Welcome {me: ClientId, others: List ClientId, num: Int, time: Int}
  | Receipt {me: ClientId, others: List ClientId, num: Int, time: Int, body: a}
  | Peer {from: ClientId, to: List ClientId, num: Int, time: Int, body: a}
  | Joiner {joiner: ClientId, to: List ClientId, num: Int, time: Int}
  | Leaver {leaver: ClientId, to: List ClientId, num: Int, time: Int}
  | Connection Connectivity


{-| The current connectivity state, received when it changes.

`Connecting` can also be interpretted as "reconnecting", because
if the connection is lost then the underlying JavaScript will try to
reconnect.

`Disconnected` will only be received if the client explicitly
asks for the connection to be closed; otherwise if a disconnection
is detected the JavaScript will try to reconnect.

Both `Connecting` and `Disconnected` mean there isn't a server connection,
but `Disconnected` means that the underlying JavaScript isn't attempting to
change that.
-}
type Connectivity =
  Connected
  | Connecting
  | Disconnected


{-| Errors reading the incoming envelope. If an error bubbles up from
the JavaScript library, or if the envelope intent is something unexpected,
that's a `LowLevel` error. If we can't decode
the JSON with the given decoder, that's a `Json` error, with the
specific error coming from the `Json.Decode` package.
-}
type Error =
  LowLevel String
  | Json Dec.Error


-- Singleton string list decoder.
-- Expect a singleton string list, and output the value
singletonStringDecoder : Dec.Decoder String
singletonStringDecoder =
  let
    singleDecoder list = case list of
      [elt] -> Dec.succeed elt
      _ -> Dec.fail "Didn't get string singleton"
  in
  Dec.list Dec.string
  |> Dec.andThen singleDecoder


{-| Decode an incoming envelope, which is initially expressed as JSON.
An envelope may include a body, which a message from our peers (other
clients) of some type `a`.
Since a body is also JSON, and specific to our application,
we need to provide a JSON decoder for that part.
It will decode JSON and produce an `a`.
If the decoding of the envelope is successful we will get an
`Ok (Envelope a)`. If there is a problem we will get an `Err Error`.

In this example we expect our envelope body to be a JSON object
containing a `"players"` field (which is a map of strings to strings)
and an `"entered"` field (which is a boolean).

    import Dict exposing (Dict)
    import Json.Decode as Dec
    import Json.Encode as Enc
    import BoardGameFramework as BGF


    type alias Body =
      { players : Dict String String
      , entered : Bool
      }


    type alias MyEnvelope = BGF.Envelope Body


    -- A JSON decoder which transforms our JSON object into a Body.
    bodyDecoder : Dec.Decoder Body
    bodyDecoder =
      let
        playersDec =
          Dec.field "players" (Dec.dict Dec.string)
        enteredDec =
          Dec.field "entered" Dec.bool
      in
      Dec.map2 Body
        playersDec
        enteredDec


    -- Parse an envelope, which is some JSON value `v`.
    result : Enc.value -> Result BGF.Error MyEnvelope
    result v =
      BGF.decode bodyDecoder v

In the above example we could also define `result` like this:

    result =
      BGF.decode bodyDecoder
-}
decode : Dec.Decoder a -> Enc.Value -> Result Error (Envelope a)
decode bodyDecoder v =
  let
    stringFieldDec field =
      Dec.field field Dec.string
      |> Dec.map (\val -> (field, val))
    intentDec = stringFieldDec "Intent"
    connectionDec = stringFieldDec "connection"
    errorDec = stringFieldDec "error"
    purposeDec = Dec.oneOf [intentDec, connectionDec, errorDec]
    purpose = Dec.decodeValue purposeDec v
  in
  case purpose of
    Ok ("Intent", "Welcome") ->
      let
        toRes = Dec.decodeValue (Dec.field "To" singletonStringDecoder) v
        fromRes = Dec.decodeValue (Dec.field "From" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        make to from num time =
          Welcome
          { me = to
          , others = from
          , num = num
          , time = time
          }
      in
        Result.map4 make toRes fromRes numRes timeRes
        |> Result.mapError Json

    Ok ("Intent", "Peer") ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        bodyRes = Dec.decodeValue (Dec.field "Body" bodyDecoder) v
        make to from num time body =
          Peer
          { from = from
          , to = to
          , num = num
          , time = time
          , body = body
          }
      in
        Result.map5 make toRes fromRes numRes timeRes bodyRes
        |> Result.mapError Json

    Ok ("Intent", "Receipt") ->
      let
        meRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        othersRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        bodyRes = Dec.decodeValue (Dec.field "Body" bodyDecoder) v
        make me others num time body =
          Receipt
          { me = me
          , others = others
          , num = num
          , time = time
          , body = body
          }
      in
        Result.map5 make meRes othersRes numRes timeRes bodyRes
        |> Result.mapError Json

    Ok ("Intent", "Joiner") ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        make to from num time =
          Joiner
          { joiner = from
          , to = to
          , num = num
          , time = time
          }
      in
        Result.map4 make toRes fromRes numRes timeRes
        |> Result.mapError Json

    Ok ("Intent", "Leaver") ->
      let
        fromRes = Dec.decodeValue (Dec.field "From" singletonStringDecoder) v
        toRes = Dec.decodeValue (Dec.field "To" (Dec.list Dec.string)) v
        numRes = Dec.decodeValue (Dec.field "Num" Dec.int) v
        timeRes = Dec.decodeValue (Dec.field "Time" Dec.int) v
        make to from num time =
          Leaver
          { leaver = from
          , to = to
          , num = num
          , time = time
          }
      in
        Result.map4 make toRes fromRes numRes timeRes
        |> Result.mapError Json

    Ok ("connection", "connected") ->
      Ok (Connection Connected)

    Ok ("connection", "connecting") ->
      Ok (Connection Connecting)

    Ok ("connection", "disconnected") ->
      Ok (Connection Disconnected)

    Ok ("error", str) ->
      Err (LowLevel str)

    Ok (field, val) ->
      Err (LowLevel <| "Unrecognised " ++ field ++ ": '" ++ val ++ "'")

    Err desc ->
      Err (Json desc)


-- Instruction to be sent through a port.
type Instruction a =
  Open Address
  | Send a
  | Close


-- Encode a `Instruction` to the server. It needs a JSON encoder for our
-- application-specific messages (type `a`) that get sent between peers.
encode : (a -> Enc.Value) -> Instruction a -> Enc.Value
encode encoder instr =
  case instr of
    Open addr ->
      Enc.object
        [ ("instruction", Enc.string "Open")
        , ("url", toUrlString addr |> Enc.string)
        ]

    Send body ->
      Enc.object
        [ ("instruction", Enc.string "Send")
        , ("body", encoder body )
        ]

    Close ->
      Enc.object
        [ ("instruction", Enc.string "Close")
        ]


open : (Enc.Value -> Cmd msg) -> Server -> GameId -> Cmd msg
open cmder server gId =
  server
  |> withGameId gId
  |> Open
  |> encode (\_ -> Enc.null)
  |> cmder


send : (Enc.Value -> Cmd msg) -> (a -> Enc.Value) -> a -> Cmd msg
send cmder encoder body =
  Send body
  |> encode encoder
  |> cmder


close : (Enc.Value -> Cmd msg) -> Cmd msg
close cmder =
  Close
  |> encode (\_ -> Enc.null)
  |> cmder
