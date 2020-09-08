-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Wrap exposing
  ( encode, decoder
  , send, receive
  )


import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF


encode : String -> Enc.Value -> Enc.Value
encode name enc =
  Enc.object
  [ (name, enc)
  ]


decoder : List (String, Dec.Decoder body) -> Dec.Decoder body
decoder pairs =
  let
    fieldList =
      pairs
      |> List.map (\(name, dec) -> Dec.field name dec)
  in
  Dec.oneOf fieldList


send : (Enc.Value -> Cmd msg) -> String -> (body -> Enc.Value) -> body -> Cmd msg
send outPort name enc =
  (enc >> encode name)
  |> BGF.send outPort


receive : (Result BGF.Error (BGF.Envelope body) -> msg) -> List (String, Dec.Decoder body) -> Enc.Value -> msg
receive tag pairs v =
  let
    bodyDecoder = decoder pairs
  in
  BGF.decode bodyDecoder v
  |> tag
