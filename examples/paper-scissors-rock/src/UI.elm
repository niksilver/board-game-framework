-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module UI exposing
  ( fontSize, bigFontSize, scaled, scaledInt
  , white, black
  , layout, paddedRow, centredTextWith
  , button, inputText
  , smallImage
  )


import Html
import Element as El
import Element.Input as Input
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font


-- Sizing


fontSize : Int
fontSize = 20


bigFontSize : Int
bigFontSize =
  scaledInt 2


scaled : Int -> Float
scaled =
  El.modular (toFloat fontSize) 1.5


scaledInt : Int -> Int
scaledInt =
  scaled >> round


-- Colours


white = El.rgb 1.0 1.0 1.0
black = El.rgb 0.0 0.0 0.0


-- A colour palette for a single-coloured area.
type alias MiniPalette =
  { background : El.Color
  , title : El.Color
  , text : El.Color
  , buttonEnabledBg : El.Color
  , buttonEnabledText : El.Color
  , buttonEnabledBorder : El.Color
  , buttonEnabledMouseOver : List El.Decoration
  , buttonDisabledBg : El.Color
  , buttonDisabledText : El.Color
  , buttonDisabledBorder : El.Color
  , buttonDisabledMouseOver : List El.Decoration
  , placeholder : El.Color
  }


miniPaletteBlack : MiniPalette
miniPaletteBlack =
  let
    closer = lighten black
  in
  { background = black
  , title = white
  , text = white
  , buttonEnabledBg = closer white 0.9
  , buttonEnabledText = white
  , buttonEnabledBorder = closer white 0.25
  , buttonEnabledMouseOver = [ Background.color <| closer white 0.8 ]
  , buttonDisabledBg = closer white 0.95
  , buttonDisabledText = closer white 0.75
  , buttonDisabledBorder = closer white 0.9
  , buttonDisabledMouseOver = []
  , placeholder = closer white 0.8
  }


-- Takes a paint colour (second parameter) and darkens it by some degree
-- to be closer to the base colour (first parameter).
-- Giving it a float of 0.0 leaves the paint colour unchanged;
-- giving it a float of 1.0 makes it the base colour;
darken : El.Color -> El.Color -> Float -> El.Color
darken base paint degree =
  let
    baseRgb = El.toRgb base
    paintRgb = El.toRgb paint
    adjust channel =
      let
        paintCol = paintRgb |> channel
        baseCol = baseRgb |> channel
      in
      paintCol - degree * (paintCol - baseCol)
  in
  { red = adjust .red
  , green = adjust .green
  , blue = adjust .blue
  , alpha = adjust .alpha
  }
  |> El.fromRgb


-- Takes a paint colour (second parameter) and lightens it by some degree
-- to be closer to the base colour (first parameter).
-- Giving it a float of 0.0 leaves the paint colour unchanged;
-- giving it a float of 1.0 makes it the base colour;
lighten : El.Color -> El.Color -> Float -> El.Color
lighten base paint degree =
  let
    baseRgb = El.toRgb base
    paintRgb = El.toRgb paint
    adjust channel =
      let
        paintCol = paintRgb |> channel
        baseCol = baseRgb |> channel
      in
      paintCol + degree * (baseCol - paintCol)
  in
  { red = adjust .red
  , green = adjust .green
  , blue = adjust .blue
  , alpha = adjust .alpha
  }
  |> El.fromRgb


-- Layout element


outerClearance = scaledInt 1
innerClearance = scaledInt 0


layout : El.Element msg -> Html.Html msg
layout =
  El.layout
  [ El.padding outerClearance
  , Font.size fontSize
  , Font.color white
  , Background.color black
  ]


paddedRow : List (El.Element msg) -> El.Element msg
paddedRow =
  El.row
  [ El.width El.fill
  , El.padding innerClearance
  , El.explain Debug.todo
  ]


centredTextWith : List (El.Attribute msg) -> String -> El.Element msg
centredTextWith attrs str =
  El.paragraph
  ( Font.center :: attrs )
  [ El.text str
  ]


-- Input elements


button :
  { enabled : Bool
  , onPress : Maybe msg
  , textLabel : String
  , imageLabel : El.Element msg
  } -> El.Element msg
button desc =
  let
    mp = miniPaletteBlack
    attrs =
      case desc.enabled of
        True ->
          { bgColor = mp.buttonEnabledBg
          , textColor = mp.buttonEnabledText
          , borderColor = mp.buttonEnabledBorder
          , mouseOver = mp.buttonEnabledMouseOver
          }

        False ->
          { bgColor = mp.buttonDisabledBg
          , textColor = mp.buttonDisabledText
          , borderColor = mp.buttonDisabledBorder
          , mouseOver = mp.buttonDisabledMouseOver
          }
    textLabel = El.el [Font.color attrs.textColor] (El.text desc.textLabel)
  in
  Input.button
  [ Background.color attrs.bgColor
  , Font.color attrs.textColor
  , Border.color attrs.borderColor
  , Border.width 4
  , Border.rounded 10
  , El.centerX
  , El.padding (scaledInt -1)
  , El.mouseOver attrs.mouseOver
  ]
  { onPress = if desc.enabled then desc.onPress else Nothing
  , label =
      El.row []
      [ textLabel
      , desc.imageLabel
      ]
  }


inputText :
  { onChange : String -> msg
  , text : String
  , placeholderText : String
  , label : String
  , fontScale : Int
  } -> El.Element msg
inputText desc =
  let
    mp = miniPaletteBlack
  in
  Input.text
  [ El.width (fontSize * desc.fontScale |> El.px)
  , Background.color mp.background
  , Font.color mp.text
  ]
  { onChange = desc.onChange
  , text = desc.text
  , placeholder =
    El.text desc.placeholderText
    |> Input.placeholder [Font.color mp.placeholder]
    |> Just
  , label =
      El.text desc.label
      |> El.el [Font.color mp.text]
      |> Input.labelLeft []
  }


-- Images

smallImage : String -> String -> Int -> El.Element msg
smallImage desc src pxHeight =
  El.image
  [ El.height <| El.px pxHeight
  ]
  { src = src
  , description = desc
  }
