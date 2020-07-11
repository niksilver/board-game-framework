-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module UI exposing
  ( fontSize, scaled, scaledInt
  , layout
  , miniPaletteWhite, miniPaletteThunderCloud, miniPaletteWaterfall
  , heading, redLight, amberLight, greenLight, link, button
  , inputRow
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


scaled : Int -> Float
scaled =
  El.modular (toFloat fontSize) 1.5


scaledInt : Int -> Int
scaledInt =
  scaled >> round


-- Colours
-- From https://www.canva.com/learn/100-color-combinations/

white = El.rgb 1.0 1.0 1.0
black = El.rgb 0.0 0.0 0.0


thunderCloud = rgbHex "505160"
waterfall = rgbHex "68829e"
moss = rgbHex "aebd38"
meadow = rgbHex "598234"


-- A colour palette for a single-coloured area.
type alias MiniPalette =
  { background : El.Color
  , title : El.Color
  , text : El.Color
  , buttonEnabledBgColor : El.Color
  , buttonEnabledTextColor : El.Color
  , buttonEnabledBorderColor : El.Color
  , buttonEnabledMouseOver : List El.Decoration
  , buttonDisabledBgColor : El.Color
  , buttonDisabledTextColor : El.Color
  , buttonDisabledBorderColor : El.Color
  , buttonDisabledMouseOver : List El.Decoration
  }


miniPaletteWhite : MiniPalette
miniPaletteWhite =
  let
    closer = lighten white
  in
  { background = white
  , title = black
  , text = black
  , buttonEnabledBgColor = closer black 0.9
  , buttonEnabledTextColor = black
  , buttonEnabledBorderColor = closer black 0.5
  , buttonEnabledMouseOver = [ Background.color <| closer black 0.8 ]
  , buttonDisabledBgColor = closer black 0.95
  , buttonDisabledTextColor = closer black 0.75
  , buttonDisabledBorderColor = closer black 0.9
  , buttonDisabledMouseOver = []
  }


miniPaletteThunderCloud : MiniPalette
miniPaletteThunderCloud =
  let
    closer = darken thunderCloud
  in
  { background = thunderCloud
  , title = white
  , text = white
  , buttonEnabledBgColor = closer white 0.9
  , buttonEnabledTextColor = white
  , buttonEnabledBorderColor = closer white 0.5
  , buttonEnabledMouseOver = [ Background.color <| closer white 0.8 ]
  , buttonDisabledBgColor = closer white 0.8
  , buttonDisabledTextColor = closer white 0.6
  , buttonDisabledBorderColor = closer white 0.9
  , buttonDisabledMouseOver = []
  }


miniPaletteWaterfall : MiniPalette
miniPaletteWaterfall =
  let
    closer = darken waterfall
  in
  { background = waterfall
  , title = white
  , text = white
  , buttonEnabledBgColor = closer white 0.8
  , buttonEnabledTextColor = white
  , buttonEnabledBorderColor = closer white 0.5
  , buttonEnabledMouseOver = [ Background.color <| closer white 0.7 ]
  , buttonDisabledBgColor = closer white 0.7
  , buttonDisabledTextColor = closer white 0.5
  , buttonDisabledBorderColor = closer white 0.9
  , buttonDisabledMouseOver = []
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


-- Elements


layout : El.Color -> El.Element msg -> Html.Html msg
layout bgColor els =
  El.layout
  [ El.padding 0
  , Font.size fontSize
  , Background.color bgColor
  ]
  els


heading : String -> Int -> El.Element msg
heading text size =
  El.el
  [ Font.family [ Font.serif ]
  , Font.size (fontSize * size)
  , El.centerX
  ]
  (El.text text)


redLight : String -> El.Element msg
redLight text =
  El.el
  [ Background.color (El.rgb 1.0 0.3 0.3)
  , Font.color (El.rgb 1 1 1)
  , El.width (fontSize * 8 |> El.px)
  , Font.center
  , Border.rounded 4
  , Border.color (El.rgb 1 1 1)
  , Border.width 1
  , El.padding (scaledInt -1)
  ]
  (El.text text)


amberLight : String -> El.Element msg
amberLight text =
  El.el
  [ Background.color (El.rgb 1.0 1.0 0.7)
  , Border.rounded 4
  , El.padding (scaledInt -1)
  ]
  (El.text text)


greenLight : String -> El.Element msg
greenLight text =
  El.el
  [ Background.color (El.rgb 0.3 0.9 0.3)
  , Font.color (El.rgb 0 0 0)
  , El.width (fontSize * 8 |> El.px)
  , Font.center
  , Border.rounded 4
  , Border.color (El.rgb 1 1 1)
  , Border.width 1
  , El.padding (scaledInt -1)
  ]
  (El.text text)


link : { url : String, label : El.Element msg } -> El.Element msg
link desc =
  El.link
  [ Font.underline
  ] desc


button :
  { enabled : Bool
  , onPress : Maybe msg
  , label : El.Element msg
  , miniPalette: MiniPalette
  } -> El.Element msg
button desc =
  let
    mp = desc.miniPalette
    attrs =
      case desc.enabled of
        True ->
          { bgColor = mp.buttonEnabledBgColor
          , textColor = mp.buttonEnabledTextColor
          , borderColor = mp.buttonEnabledBorderColor
          , mouseOver = mp.buttonEnabledMouseOver
          }

        False ->
          { bgColor = mp.buttonDisabledBgColor
          , textColor = mp.buttonDisabledTextColor
          , borderColor = mp.buttonDisabledBorderColor
          , mouseOver = mp.buttonDisabledMouseOver
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


-- Utilities


-- Convert a six digit hex code to a colour; not robust.
rgbHex : String -> El.Color
rgbHex str =
  let
    r = str |> String.slice 0 2 |> rgbHex2
    g = str |> String.slice 2 4 |> rgbHex2
    b = str |> String.slice 4 6 |> rgbHex2
  in
    El.rgb r g b


-- Convert a two digit hex code to a float 0.0 to 1.0
rgbHex2 : String -> Float
rgbHex2 str =
  let
    toInt chr =
      if Char.isDigit chr then
        (Char.toCode chr) - (Char.toCode '0') |> toFloat
      else if Char.isUpper chr then
        (Char.toCode chr) - (Char.toCode 'A') |> toFloat
      else
        (Char.toCode chr) - (Char.toCode 'a') |> toFloat
    s1 = str |> String.left 1
    s2 = str |> String.right 1
  in
    case (String.uncons s1, String.uncons s2) of
      (Just(c1, _), Just(c2, _)) ->
        ((toInt c1 * 16) + toInt c2) / 255

      _ ->
        0
