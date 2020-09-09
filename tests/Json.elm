module Json exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)

import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework exposing (..)


-- General function for later use


simpleDecoder : Dec.Decoder { colour : String }
simpleDecoder =
  Dec.map (\s -> {colour = s}) <|
    Dec.field "colour" Dec.string


-- Decode


decodeTest : Test
decodeTest =
  describe "decode test"

    [ describe "Decode Welcome" <|
      [ test "Good Welcome" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234", "333.345"])
            , ("To", Enc.list Enc.string ["123.456"])
            , ("Num", Enc.int 28)
            , ("Time", Enc.int 7654321)
            , ("Intent", Enc.string "Welcome")
            ]
        in
        \_ ->
          case decode simpleDecoder j of
            Ok (Welcome data) ->
              Expect.all
              [ \d -> Expect.equal "123.456" d.me
              , \d -> Expect.equal ["222.234", "333.345"] d.others
              , \d -> Expect.equal 28 d.num
              , \d -> Expect.equal 7654321 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDecodeGivesError "To is not a list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.int 123)
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDecodeGivesError "To is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.int [123, 222])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDecodeGivesError "To is empty list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string [])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDecodeGivesError "To is a list of right type, but too long" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDecodeGivesError "From is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.int [222, 333])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDecodeGivesError "From is wrong type" <|
          Enc.object
          [ ("From", Enc.int 1000)
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 7654321)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDecodeGivesError "Num is wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.string "Twenty eight")
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDecodeGivesError "Time is wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.string "7654321")
          , ("Intent", Enc.string "Welcome")
          ]

      ]

    , describe "Decode Peer" <|
      [ test "Good Peer" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 29)
            , ("Time", Enc.int 8765432)
            , ("Intent", Enc.string "Peer")
            , ("Body", Enc.object [("colour", Enc.string "Red")])
            ]
        in
        \_ ->
          case decode simpleDecoder j of
            Ok (Peer data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.from
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 29 d.num
              , \d -> Expect.equal 8765432 d.time
              , \d -> Expect.equal {colour = "Red"} d.body
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDecodeGivesError "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", Enc.object [("colour", Enc.string "Red")])
          ]

      , testDecodeGivesError "Body shouldn't parse" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", Enc.object [("Xolor", Enc.string "Red")])
          ]
        ]

    , describe "Decode Receipt" <|
      [ test "Good Receipt" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 30)
            , ("Time", Enc.int 8765432)
            , ("Intent", Enc.string "Receipt")
            , ("Body", Enc.object [("colour", Enc.string "Red")])
            ]
        in
        \_ ->
          case decode simpleDecoder j of
            Ok (Receipt data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.me
              , \d -> Expect.equal ["123.456", "333.345"] d.others
              , \d -> Expect.equal 30 d.num
              , \d -> Expect.equal 8765432 d.time
              , \d -> Expect.equal {colour = "Red"} d.body
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDecodeGivesError "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 30)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Receipt")
          , ("Body", Enc.object [("colour", Enc.string "Red")])
          ]

      , testDecodeGivesError "Body shouldn't parse" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 30)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Receipt")
          , ("Body", Enc.object [("Xolor", Enc.string "Red")])
          ]

      ]

    , describe "Decode Joiner" <|
      [ test "Good Joiner" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 31)
            , ("Time", Enc.int 6543210)
            , ("Intent", Enc.string "Joiner")
            ]
        in
        \_ ->
          case decode simpleDecoder j of
            Ok (Joiner data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.joiner
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 31 d.num
              , \d -> Expect.equal 6543210 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDecodeGivesError "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 31)
          , ("Time", Enc.int 6543210)
          , ("Intent", Enc.string "Joiner")
          ]

       ]

    , describe "Decode Leaver" <|
      [ test "Good Leaver" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 32)
            , ("Time", Enc.int 987654)
            , ("Intent", Enc.string "Leaver")
            ]
        in
        \_ ->
          case decode simpleDecoder j of
            Ok (Leaver data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.leaver
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 32 d.num
              , \d -> Expect.equal 987654 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDecodeGivesError "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 32)
          , ("Time", Enc.int 987654)
          , ("Intent", Enc.string "Leaver")
          ]

       ]

    , describe "Decode connection" <|
      [ test "Good opened" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "connected") ]
          |> decode simpleDecoder
          |> Expect.equal (Ok (Connection Connected))

      , test "Good connecting" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "connecting") ]
          |> decode simpleDecoder
          |> Expect.equal (Ok (Connection Connecting))

      , test "Good closed" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "disconnected") ]
          |> decode simpleDecoder
          |> Expect.equal (Ok (Connection Disconnected))

      , test "Bad connection (string)" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "garbage") ]
          |> decode simpleDecoder
          |> expectErrorString "Unrecognised connection value: 'garbage'"

      , testDecodeGivesError "Bad connection (non-string)" <|
          Enc.object [ ("connection", Enc.int 667) ]

      ]

    , describe "Decode error" <|
      [
        test "Good error" <|
        \_ ->
          Enc.object [ ("error", Enc.string "This is my error") ]
          |> decode simpleDecoder
          |> Expect.equal (Ok (Error "This is my error"))

      , testDecodeGivesError "Error isn't a string" <|
          Enc.object [ ("error", Enc.int 333) ]

      ]

    , describe "Nonsense envelope" <|
      [ test "Intent not recognised" <|
        \_ ->
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234"])
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Time", Enc.int 987654)
          , ("Intent", Enc.string "Peculiar")
          ]
          |> decode simpleDecoder
          |> expectErrorString "Unrecognised Intent value: 'Peculiar'"

      , testDecodeGivesError "Not of recognised format" <|
          Enc.object
          [ ("Frim", Enc.list Enc.string ["222.234"])
          , ("Tx", Enc.list Enc.string ["123.456"])
          , ("Tome", Enc.int 987654)
          , ("Ontint", Enc.string "Peculiar")
          ]

      , testDecodeGivesError "Envelope isn't an object" <|
          Enc.int 222

      ]

    ]


testDecodeGivesError : String -> Enc.Value -> Test
testDecodeGivesError desc json =
  test desc <|
  \_ ->
    case decode simpleDecoder json of
      Err _ ->
        Expect.pass
      Ok env ->
        Expect.fail <| "Wrongly parsed Ok: " ++ (Debug.toString env)


-- Decoder


decoderTest : Test
decoderTest =
  describe "decoder test"

    [ describe "Decoder for Welcome" <|
      [ test "Good Welcome" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234", "333.345"])
            , ("To", Enc.list Enc.string ["123.456"])
            , ("Num", Enc.int 28)
            , ("Time", Enc.int 7654321)
            , ("Intent", Enc.string "Welcome")
            ]
        in
        \_ ->
          case Dec.decodeValue (decoder simpleDecoder) j of
            Ok (Welcome data) ->
              Expect.all
              [ \d -> Expect.equal "123.456" d.me
              , \d -> Expect.equal ["222.234", "333.345"] d.others
              , \d -> Expect.equal 28 d.num
              , \d -> Expect.equal 7654321 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDoesNotFitDecoder "To is not a list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.int 123)
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDoesNotFitDecoder "To is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.int [123, 222])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDoesNotFitDecoder "To is empty list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string [])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDoesNotFitDecoder "To is a list of right type, but too long" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDoesNotFitDecoder "From is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.int [222, 333])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDoesNotFitDecoder "From is wrong type" <|
          Enc.object
          [ ("From", Enc.int 1000)
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 7654321)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDoesNotFitDecoder "Num is wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.string "Twenty eight")
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testDoesNotFitDecoder "Time is wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.string "7654321")
          , ("Intent", Enc.string "Welcome")
          ]

      ]

    , describe "Decoder for Peer" <|
      [ test "Good Peer" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 29)
            , ("Time", Enc.int 8765432)
            , ("Intent", Enc.string "Peer")
            , ("Body", Enc.object [("colour", Enc.string "Red")])
            ]
        in
        \_ ->
          case Dec.decodeValue (decoder simpleDecoder) j of
            Ok (Peer data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.from
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 29 d.num
              , \d -> Expect.equal 8765432 d.time
              , \d -> Expect.equal {colour = "Red"} d.body
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDoesNotFitDecoder "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", Enc.object [("colour", Enc.string "Red")])
          ]

      , testDoesNotFitDecoder "Body shouldn't parse" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", Enc.object [("Xolor", Enc.string "Red")])
          ]
        ]

    , describe "Decoder for Receipt" <|
      [ test "Good Receipt" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 30)
            , ("Time", Enc.int 8765432)
            , ("Intent", Enc.string "Receipt")
            , ("Body", Enc.object [("colour", Enc.string "Red")])
            ]
        in
        \_ ->
          case Dec.decodeValue (decoder simpleDecoder) j of
            Ok (Receipt data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.me
              , \d -> Expect.equal ["123.456", "333.345"] d.others
              , \d -> Expect.equal 30 d.num
              , \d -> Expect.equal 8765432 d.time
              , \d -> Expect.equal {colour = "Red"} d.body
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDoesNotFitDecoder "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 30)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Receipt")
          , ("Body", Enc.object [("colour", Enc.string "Red")])
          ]

      , testDoesNotFitDecoder "Body shouldn't parse" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 30)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Receipt")
          , ("Body", Enc.object [("Xolor", Enc.string "Red")])
          ]

      ]

    , describe "Decoder for Joiner" <|
      [ test "Good Joiner" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 31)
            , ("Time", Enc.int 6543210)
            , ("Intent", Enc.string "Joiner")
            ]
        in
        \_ ->
          case Dec.decodeValue (decoder simpleDecoder) j of
            Ok (Joiner data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.joiner
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 31 d.num
              , \d -> Expect.equal 6543210 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDoesNotFitDecoder "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 31)
          , ("Time", Enc.int 6543210)
          , ("Intent", Enc.string "Joiner")
          ]

       ]

    , describe "Decoder for Leaver" <|
      [ test "Good Leaver" <|
        let
          j =
            Enc.object
            [ ("From", Enc.list Enc.string ["222.234"])
            , ("To", Enc.list Enc.string ["123.456", "333.345"])
            , ("Num", Enc.int 32)
            , ("Time", Enc.int 987654)
            , ("Intent", Enc.string "Leaver")
            ]
        in
        \_ ->
          case Dec.decodeValue (decoder simpleDecoder) j of
            Ok (Leaver data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.leaver
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 32 d.num
              , \d -> Expect.equal 987654 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testDoesNotFitDecoder "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 32)
          , ("Time", Enc.int 987654)
          , ("Intent", Enc.string "Leaver")
          ]

       ]

    , describe "Decoder for connection" <|
      [ test "Good opened" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "connected") ]
          |> Dec.decodeValue (decoder simpleDecoder)
          |> Expect.equal (Ok (Connection Connected))

      , test "Good connecting" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "connecting") ]
          |> Dec.decodeValue (decoder simpleDecoder)
          |> Expect.equal (Ok (Connection Connecting))

      , test "Good closed" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "disconnected") ]
          |> Dec.decodeValue (decoder simpleDecoder)
          |> Expect.equal (Ok (Connection Disconnected))

      , test "Bad connection (string)" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "garbage") ]
          |> Dec.decodeValue (decoder simpleDecoder)
          |> \result ->
            case result of
              Ok _ ->
                Expect.fail "Incorrectly ok"

              Err (Dec.Failure desc _) ->
                Expect.equal "Unrecognised connection value: 'garbage'" desc

              Err e ->
                Expect.fail <| "Wrong kind of error: " ++ (Debug.toString e)

      , testDecodeGivesError "Bad connection (non-string)" <|
          Enc.object [ ("connection", Enc.int 667) ]

      ]
    ]


testDoesNotFitDecoder : String -> Enc.Value -> Test
testDoesNotFitDecoder desc json =
  test desc <|
  \_ ->
    case Dec.decodeValue (decoder simpleDecoder) json of
      Err _ ->
        Expect.pass
      Ok env ->
        Expect.fail <| "Wrongly parsed Ok: " ++ (Debug.toString env)


expectErrorString : String -> Result Dec.Error (Envelope a) -> Expect.Expectation
expectErrorString str result =
  case result of
    Ok _ ->
      Expect.fail "Incorrectly ok"

    Err (Dec.Failure desc _) ->
      Expect.equal str desc

    Err e ->
      Expect.fail <| "Wrong kind of error: " ++ (Debug.toString e)
