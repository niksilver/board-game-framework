-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module UI exposing
  ( fontSize, scaled, scaledInt
  , miniPaletteBlack, miniPaletteWhite
  , button, inputText
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


miniPaletteWhite : MiniPalette
miniPaletteWhite =
  let
    closer = lighten white
  in
  { background = white
  , title = black
  , text = black
  , buttonEnabledBg = closer black 0.9
  , buttonEnabledText = black
  , buttonEnabledBorder = closer black 0.5
  , buttonEnabledMouseOver = [ Background.color <| closer black 0.8 ]
  , buttonDisabledBg = closer black 0.95
  , buttonDisabledText = closer black 0.75
  , buttonDisabledBorder = closer black 0.9
  , buttonDisabledMouseOver = []
  , placeholder = closer black 0.8
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
  , buttonEnabledBorder = closer white 0.5
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


-- Elements


button :
  { enabled : Bool
  , onPress : Maybe msg
  , label : String
  , miniPalette: MiniPalette
  } -> El.Element msg
button desc =
  let
    mp = desc.miniPalette
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
  , label = El.el [Font.color attrs.textColor] (El.text desc.label)
  }


inputText :
  { onChange : String -> msg
  , text : String
  , placeholderText : String
  , label : String
  , fontScale : Int
  , miniPalette : MiniPalette
  } -> El.Element msg
inputText desc =
  let
    mp = desc.miniPalette
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
