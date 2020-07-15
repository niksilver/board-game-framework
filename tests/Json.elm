module Json exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)

import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework exposing (..)


decodeEnvelopeTest : Test
decodeEnvelopeTest =
  describe "decodeEnvelope test"

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
          case decodeEnvelope simpleDecoder j of
            Ok (Welcome data) ->
              Expect.all
              [ \d -> Expect.equal "123.456" d.me
              , \d -> Expect.equal ["222.234", "333.345"] d.others
              , \d -> Expect.equal 28 d.num
              , \d -> Expect.equal 7654321 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testWontParse "To is not a list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.int 123)
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "To is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.int [123, 222])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "To is empty list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string [])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "To is a list of right type, but too long" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "From is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.int [222, 333])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "From is wrong type" <|
          Enc.object
          [ ("From", Enc.int 1000)
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.int 28)
          , ("Time", Enc.int 7654321)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "Num is wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Num", Enc.string "Twenty eight")
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "Time is wrong type" <|
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
          case decodeEnvelope simpleDecoder j of
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

      , testWontParse "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 29)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", Enc.object [("colour", Enc.string "Red")])
          ]

      , testWontParse "Body shouldn't parse" <|
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
          case decodeEnvelope simpleDecoder j of
            Ok (Receipt data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.from
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 30 d.num
              , \d -> Expect.equal 8765432 d.time
              , \d -> Expect.equal {colour = "Red"} d.body
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testWontParse "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Num", Enc.int 30)
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Receipt")
          , ("Body", Enc.object [("colour", Enc.string "Red")])
          ]

      , testWontParse "Body shouldn't parse" <|
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
          case decodeEnvelope simpleDecoder j of
            Ok (Joiner data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.joiner
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 31 d.num
              , \d -> Expect.equal 6543210 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testWontParse "From is more than a singleton" <|
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
          case decodeEnvelope simpleDecoder j of
            Ok (Leaver data) ->
              Expect.all
              [ \d -> Expect.equal "222.234" d.leaver
              , \d -> Expect.equal ["123.456", "333.345"] d.to
              , \d -> Expect.equal 32 d.num
              , \d -> Expect.equal 987654 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testWontParse "From is more than a singleton" <|
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
          Enc.object [ ("connection", Enc.string "opened") ]
          |> decodeEnvelope simpleDecoder
          |> Expect.equal (Ok (Connection Opened))

      , test "Good reconnecting" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "reconnecting") ]
          |> decodeEnvelope simpleDecoder
          |> Expect.equal (Ok (Connection Reconnecting))

      , test "Good closed" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "closed") ]
          |> decodeEnvelope simpleDecoder
          |> Expect.equal (Ok (Connection Closed))

      , test "Bad connection (string)" <|
        \_ ->
          Enc.object [ ("connection", Enc.string "garbage") ]
          |> decodeEnvelope simpleDecoder
          |> Expect.equal (Err (LowLevel "Unrecognised connection: 'garbage'"))

      , test "Bad connection (non-string)" <|
        \_ ->
          Enc.object [ ("connection", Enc.int 667) ]
          |> decodeEnvelope simpleDecoder
          |> \res ->
            case res of
              Err (Json _) ->
                Expect.pass
              _ ->
                Expect.fail "Expected JSON error, but got something else"

      ]

    , describe "Decode error" <|
      [ test "Good error" <|
        \_ ->
          Enc.object [ ("error", Enc.string "This is my error") ]
          |> decodeEnvelope simpleDecoder
          |> Expect.equal (Err (LowLevel "This is my error"))

      , testWontParse "Error isn't a string" <|
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
          |> decodeEnvelope simpleDecoder
          |> Expect.equal (Err (LowLevel "Unrecognised Intent: 'Peculiar'"))

      , test "Not of recognised format" <|
        \_ ->
          Enc.object
          [ ("Frim", Enc.list Enc.string ["222.234"])
          , ("Tx", Enc.list Enc.string ["123.456"])
          , ("Tome", Enc.int 987654)
          , ("Ontint", Enc.string "Peculiar")
          ]
          |> decodeEnvelope simpleDecoder
          |> \res ->
            case res of
              Err (Json _) ->
                Expect.pass
              Err (LowLevel desc) ->
                Expect.fail ("Expected JSON error but got low level: " ++ desc)
              Ok _ ->
                Expect.fail "Expected JSON error but got Ok"


      , testWontParse "Envelope isn't an object" <|
          Enc.int 222

      ]

    ]


testWontParse : String -> Enc.Value -> Test
testWontParse desc json =
  test desc <|
  \_ ->
    case decodeEnvelope simpleDecoder json of
      Err (Json _) ->
        Expect.pass
      Err (LowLevel str) ->
        Expect.fail <| "Wrongly got low level error: " ++ str
      Ok env ->
        Expect.fail <| "Wrongly parsed Ok: " ++ (Debug.toString env)


simpleDecoder : Dec.Decoder { colour : String }
simpleDecoder =
  Dec.map (\s -> {colour = s}) <|
    Dec.field "colour" Dec.string
