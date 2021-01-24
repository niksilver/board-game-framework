-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Box exposing
  ( encode, decoder
  , send, receive
  )


{-| Sometimes we don't want to send just one kind of value to
our peers, but several. If so, then we need to box and label each
type of value so that it can be correctly identified at the other end.
This module helps with that.

All the examples in this module follow on from the basic setup below,
in which we will
send two kinds of value: a card with a message (a `String`) and the size
of various piles of chips (a `List Int`). This will be JSON-encoded
through ports, and will be decoded as `Envelope`s.

    import Json.Encode as Enc
    import Json.Decode as Dec
    import BoardGameFramework as BGF
    import BoardGameFramework.Box as Box

    type Body =
      Card String
      | Chips (List Int)

    type Msg =
      Received (Result Dec.Error (BGF.Envelope Body))
      | ...

    port outgoing : Enc.Value -> Cmd msg
    port incoming : (Enc.Value -> msg) -> Sub msg

# JSON
@docs encode, decoder

# Sending and receiving
@docs send, receive
-}


import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF


-- JSON

{-| Box a value with a label.

    encodeCard : String -> Enc.Value
    encodeCard text =
      Enc.string text
      |> Box.encode "card"

    encodeChips : List Int -> Enc.Value
    encodeChips chips =
      Enc.list Enc.int chips
      |> Box.encode "chips"
-}
encode : String -> Enc.Value -> Enc.Value
encode name enc =
  Enc.object
  [ (name, enc)
  ]


{-| Create a decoder for values which are boxed with labels.
We don't need to use this if we're using the [`receive`](#receive)
function.

Given a decoder for a card and a decoder for chips, we can create
a `Decoder Body`:

    cardDecoder : Dec.Decoder String
    cardDecoder =
      Dec.string

    chipsDecoder : Dec.Decoder (List Int)
    chipsDecoder =
      Dec.list Dec.int

    bodyDecoder : Dec.Decoder Body
    bodyDecoder =
      Box.decoder
      [ ("card", Dec.map Card cardDecoder)
      , ("chips", Dec.map Chips chipsDecoder)
      ]
-}
decoder : List (String, Dec.Decoder body) -> Dec.Decoder body
decoder pairs =
  let
    fieldList =
      pairs
      |> List.map (\(name, dec) -> Dec.field name dec)
  in
  Dec.oneOf fieldList


-- Sending and receiving


{-| Send one type of value by boxing it up with a label, and thus
making it an acceptable envelope body. Parameters are

* The outbound port;
* The label;
* A function to encode the value;
* The value itself.

Here's how we can send a card value and some chips data through the
`outgoing` port.

    sendCardCmd : String -> Cmd Msg
    sendCardCmd =
      Box.send outgoing "card" encodeCard


    sendChipsCmd : List Int -> Cmd Msg
    sendChipsCmd =
      Box.send outgoing "chips" encodeChips

    -- Use the functions to send some data

    sendCardCmd "Tell us a secret"  -- Sends the card value to our peers
    sendChipsCmd [150, 0, 100]      -- Sends the chips data to our peers
-}
send : (Enc.Value -> Cmd msg) -> String -> (body -> Enc.Value) -> body -> Cmd msg
send outPort name enc =
  (enc >> encode name)
  |> BGF.send outPort


{-| Take a JSON-encoded value (which has been boxed up with a label)
and turn it into a `msg`. By supplying the first two parameters
we get a function (JSON `Value` to `msg`) which can be given
to the inbound port. Using this function means we don't have to use
[`decode`](#decode).

Using our running example, we can subscribe to a `Msg` like this:

    port incoming : (Enc.Value -> msg) -> Sub msg

    subscriptions : Model -> Sub Msg
    subscriptions _ =
      incoming myReceive

    myReceive : Enc.Value -> Msg
    myReceive =
      Box.receive
      Received
      [ ("card", Dec.map Card cardDecoder)
      , ("chips", Dec.map Chips chipsDecoder)
      ]

Now our usual `update` function can take `Received` envelopes of the
correct type.

Note that we don't need to use this `receive` function if
we're happy to create our own `Body` decoder:

    bodyDecoder : Dec.Decoder Body
    bodyDecoder =
      Box.decoder
      [ ("card", Dec.map Card cardDecoder)
      , ("chips", Dec.map Chips chipsDecoder)
      ]

    myReceive : Enc.Value -> Msg
    myReceive v =
      BGF.decode bodyDecoder v
      |> Received
-}
receive : (Result Dec.Error (BGF.Envelope body) -> msg) -> List (String, Dec.Decoder body) -> Enc.Value -> msg
receive tag pairs v =
  let
    bodyDecoder = decoder pairs
  in
  BGF.decode bodyDecoder v
  |> tag
