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
              , \d -> Expect.equal 7654321 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testWontParse "To is not a list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.int 123)
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "To is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.int [123, 222])
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "To is empty list" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string [])
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "To is a list of right type, but too long" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "From is a list of wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.int [222, 333])
          , ("To", Enc.list Enc.string ["123", "222"])
          , ("Time", Enc.int 76487293)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "From is wrong type" <|
          Enc.object
          [ ("From", Enc.int 1000)
          , ("To", Enc.list Enc.string ["123.456"])
          , ("Time", Enc.int 7654321)
          , ("Intent", Enc.string "Welcome")
          ]

      , testWontParse "Time is wrong type" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456"])
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
              , \d -> Expect.equal 8765432 d.time
              , \d -> Expect.equal {colour = "Red"} d.body
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testWontParse "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
          , ("Body", Enc.object [("colour", Enc.string "Red")])
          ]

      , testWontParse "Body shouldn't parse" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Time", Enc.int 8765432)
          , ("Intent", Enc.string "Peer")
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
              , \d -> Expect.equal 6543210 d.time
              ] data
            other ->
              Expect.fail <| "Got other result: " ++ (Debug.toString other)

      , testWontParse "From is more than a singleton" <|
          Enc.object
          [ ("From", Enc.list Enc.string ["222.234", "333.345"])
          , ("To", Enc.list Enc.string ["123.456", "333.345"])
          , ("Time", Enc.int 6543210)
          , ("Intent", Enc.string "Peer")
          ]


       ]
    ]


testWontParse : String -> Enc.Value -> Test
testWontParse desc json =
  test desc <|
  \_ ->
    case decodeEnvelope simpleDecoder json of
      Err _ ->
        Expect.pass
      Ok env ->
        Expect.fail <| "Wrongly parsed Ok: " ++ (Debug.toString env)


simpleDecoder : Dec.Decoder { colour : String }
simpleDecoder =
  Dec.map (\s -> {colour = s}) <|
    Dec.field "colour" Dec.string
