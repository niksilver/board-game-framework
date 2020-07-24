-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENSE for details.


module BoardGameFramework exposing (
  GameId, gameId, fromGameId
  , idGenerator, isGoodGameId, isGoodGameIdMaybe, goodGameId, goodGameIdMaybe
  , ClientId
  , Envelope(..), Connectivity(..), Error(..), Request(..)
  , encode, decode
  )

{-| Types and functions help create remote multiplayer board games
using the related framework. See
[https://github.com/niksilver/board-game-framework](https://github.com/niksilver/board-game-framework)
for detailed documentation and example code.

# Basic actions: open, send, close
@docs Request, encode

# Receiving messages
Any message another client sends gets wrapped in envelope, and we get the
envelope. Communication under the hood is in JSON, so we need to say
how to decode our application's JSON messages into some suitable Elm type.
@docs Envelope, Connectivity, Error, decode

# Lobby
Enable players to gather and find a unique game ID
in preparation for starting a game.

You want something that is unique on that server and easy to communicate;
it will become part of the connection URL, so characters are limited
to alphanumerics, plus `.` (dot), `-` (hyphen) and `/`.
The `goodGameId` functions validate this.
There's a function to generate nice IDs with two random words, such
as `"cat-polygon"`, but you may like to add extra caution by
adding a game-specific prefix to make, say, `"backgammon/cat-ploygon"`.
Then the connection URL will be something like
`"wss://game.server.name/g/backgammon/cat-polygon"`.

Among the `goodGameId` functions, those that start with `is...` return
a `Bool` (rather than a `Maybe String`) and those that end with
`...Maybe` take a `Maybe String` (rather than a `String`).
@docs idGenerator, isGoodGameId, isGoodGameIdMaybe, goodGameId, goodGameIdMaybe
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
    gameId "#345#" == Err "Bad characters"    -- Bad characters
    gameId "road" == Err "Too short"          -- Too short
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


{-| A good game ID will have a good chance of being unique and wil be easy
to communicate, especially in URLs.
This test passes if it's at least five characters long and consists of just
alphanumerics, dots, dashes, and forward slashes.

    goodGameId "pancake-road" == Just "pancake-road"
    goodGameId "#345#" == Nothing    -- Bad characters
    goodGameId "road" == Nothing     -- Too short
-}
goodGameId : String -> Maybe String
goodGameId id =
  if isGoodGameId id then
    Just id
  else
    Nothing


{-| The boolean version of `goodGameId`. The clue is that it starts with
"is".

    isGoodGameId "pancake-road" == True
    isGoodGameId "#345#" == False    -- Bad characters
    isGoodGameId "road" == False     -- Too short
-}
isGoodGameId : String -> Bool
isGoodGameId id =
  (String.length id >= 5) &&
    String.all (\c -> Char.isAlphaNum c || c == '-' || c == '.' || c == '/') id


{-| Like `goodGameId`, but considers the input as a `Maybe String`.

    goodGameIdMaybe (Just "pancake-road") == Just "pancake-road"
    goodGameIdMaybe (Just "#345#") == Nothing    -- Bad characters
    goodGameIdMaybe (Just "road") == False       -- Too short
    goodGameIdMaybe Nothing == Nothing
-}
goodGameIdMaybe : Maybe String -> Maybe String
goodGameIdMaybe mId =
  case mId of
    Just id -> goodGameId id

    Nothing -> Nothing


{-| Like `goodGameId`, but considers the input as a `Maybe String`
and its output as a boolean.

    isGoodGameIdMaybe (Just "pancake-road") == True
    isGoodGameIdMaybe (Just "#345#") == False    -- Bad characters
    isGoodGameIdMaybe (Just "road") == False     -- Too short
    isGoodGameIdMaybe Nothing == False
-}
isGoodGameIdMaybe : Maybe String -> Bool
isGoodGameIdMaybe mId =
  case mId of
    Nothing -> False

    Just id -> isGoodGameId id


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
* `me`: a string indicating our client's own ID.
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
  Welcome {me: String, others: List String, num: Int, time: Int}
  | Receipt {me: String, others: List String, num: Int, time: Int, body: a}
  | Peer {from: String, to: List String, num: Int, time: Int, body: a}
  | Joiner {joiner: String, to: List String, num: Int, time: Int}
  | Leaver {leaver: String, to: List String, num: Int, time: Int}
  | Connection Connectivity


{-| The current connectivity state, sent when it changes.

`Connecting` can also be interpretted as "reconnecting", because
if the connection is lost then the underlying JavaScript will try to
reconnect.

`Closed` will only be received if the client explicitly
asks for the connection to be closed; otherwise if a closed connection
is detected the JavaScript will retry to reconnect.

Both `Connecting` and `Closed` mean there isn't a server connection,
but `Closed` means that the underlying JavaScript isn't attempting to
change that.
-}
type Connectivity =
  Opened
  | Connecting
  | Closed


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

    Ok ("connection", "opened") ->
      Ok (Connection Opened)

    Ok ("connection", "connecting") ->
      Ok (Connection Connecting)

    Ok ("connection", "closed") ->
      Ok (Connection Closed)

    Ok ("error", str) ->
      Err (LowLevel str)

    Ok (field, val) ->
      Err (LowLevel <| "Unrecognised " ++ field ++ ": '" ++ val ++ "'")

    Err desc ->
      Err (Json desc)


{-| Request to be sent through a port.
We can open a connection to a game, send a message, or close the connection.

When we open a connection we need to supply the full websocket
URL to the server with the game id.

When we send a message we need to encode the message (which is of type `a`)
as JSON.

In the example below we create an `openCmd` to open a connection,
and a `sendBodyCmd` to send a message of our own type `Body`.

    import Json.Encode as Enc
    import BoardGameFramework as BGF


    type alias Body =
      { players : Dict String String
      , entered : Bool
      }


    bodyEncoder : Body -> Enc.Value
    bodyEncoder body =
      Enc.object
      [ ("players" , Enc.dict identity Enc.string body.players)
      , ("entered" , Enc.bool body.entered)
      ]


    port outgoing : Enc.Value -> Cmd msg


    serverURL : String
    serverURL = "ws://bgf.pigsaw.org"


    openCmd : String -> Cmd msg
    openCmd gameId =
      BGF.Open (serverURL ++ "/g/" ++ gameId)
      |> BGF.encode bodyEncoder
      |> outgoing


    sendBodyCmd : Body -> Cmd msg
    sendBodyCmd body =
      BGF.Send body
      |> BGF.encode bodyEncoder
      |> outgoing

-}
type Request a =
  Open String
  | Send a
  | Close


{-| Encode a `Request` to the server. It needs a JSON encoder for our
application-specific messages (type `a`) that get sent between peers.

If we have defined an encoder `encoder` then it may be convenient to
define our own `encode` function like this:

    import Json.Encode as Enc
    import BoardGameFramework as BGF


    encode : BGF.Request a -> Enc.Value
    encode =
      BGF.encode encoder
-}
encode : (a -> Enc.Value) -> Request a -> Enc.Value
encode encoder req =
  case req of
    Open url ->
      Enc.object
        [ ("instruction", Enc.string "Open")
        , ("url", url |> Enc.string)
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
