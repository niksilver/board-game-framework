-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module UI exposing (scaled, scaledInt, layout, link, button, inputRow)


import Html
import Element as El
import Element.Input as Input
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font


fontSize : Int
fontSize = 20


scaled : Int -> Float
scaled =
  El.modular (toFloat fontSize) 1.5


scaledInt : Int -> Int
scaledInt =
  scaled >> round


layout : El.Element msg -> Html.Html msg
layout els =
  El.layout
  [ El.padding (scaledInt 1)
  , Font.size fontSize
  ]
  els


link : { url : String, label : El.Element msg } -> El.Element msg
link desc =
  El.link
  [ Font.underline
  ] desc


button : { enabled : Bool, onPress : Maybe msg, label : El.Element msg } -> El.Element msg
button desc =
  let
    attrs =
      case desc.enabled of
        True ->
          { bgColor = El.rgb 0.9 0.9 0.9
          , textColor = El.rgb 0.0 0.0 0.0
          , borderColor = El.rgb 0.5 0.5 0.5
          , mouseOver =
            [ Background.color (El.rgb 0.8 0.8 0.8)
            ]
          }

        False ->
          { bgColor = El.rgb 0.95 0.95 0.95
          , textColor = El.rgb 0.8 0.8 0.8
          , borderColor = El.rgb 0.9 0.9 0.9
          , mouseOver = []
          }
  in
  Input.button
  [ Background.color attrs.bgColor
  , Font.color attrs.textColor
  , Border.color attrs.borderColor
  , Border.width 1
  , Border.rounded 4
  , El.padding (scaledInt -1)
  , El.mouseOver attrs.mouseOver
  ]
  { onPress = if desc.enabled then desc.onPress else Nothing
  , label = El.el [Font.color attrs.textColor] desc.label
  }


inputRow : List (El.Element msg) -> El.Element msg
inputRow els =
  El.row
  [ El.spacing (scaledInt 1)
  ]
  els
