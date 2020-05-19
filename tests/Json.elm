module Json exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)

import Json.Encode as Enc

import BoardGameFramework exposing (..)


decodeEnvelopeTest : Test
decodeEnvelopeTest =
  describe "decodeEnvelope test"
    [ describe "Decode Welcome " <|
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
          case decodeEnvelope j of
            Ok (Welcome data) ->
              Expect.all
              [ \d -> Expect.equal "123.456" d.me
              , \d -> Expect.equal ["222.234", "333.345"] d.others
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

      -- Insert bad From tests here

      ]
    ]

testWontParse : String -> Enc.Value -> Test
testWontParse desc json =
  test desc <|
  \_ ->
    case decodeEnvelope json of
      Err _ ->
        Expect.pass
      Ok env ->
        Expect.fail <| "Wrongly parsed Ok: " ++ (Debug.toString env)
