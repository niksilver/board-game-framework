-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module Images exposing (x, o)

type alias Ref =
  { filename : String
  , name : String
  , link : String
  }

x : List Ref
x =
  [ { filename = "0.jpg"
    , name = "Maria Iglesias Barroso"
    , link = "https://www.flickr.com/photos/miglesias/14114788851/"
    }
  , { filename = "1.jpg"
    , name = "Björn"
    , link = "https://www.flickr.com/photos/adabo/28659408095/"
    }
  ]

o : List Ref
o =
  [ { filename = "0.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2286486623/"
    }
  , { filename = "1.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2371325881/"
    }
  ]
