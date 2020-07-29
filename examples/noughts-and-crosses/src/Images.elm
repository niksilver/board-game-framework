-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module Images exposing (stepX, stepO)


import Random


type alias Ref =
  { src : String
  , name : String
  , link : String
  }


stepX : Random.Seed -> (Ref, Random.Seed)
stepX =
  Random.uniform xHead xTail
  |> Random.step


stepO : Random.Seed -> (Ref, Random.Seed)
stepO =
  Random.uniform oHead oTail
  |> Random.step


xHead : Ref
xHead =
  { src = "images/x/0.jpg"
  , name = "Maria Iglesias Barroso"
  , link = "https://www.flickr.com/photos/miglesias/14114788851/"
  }


xTail : List Ref
xTail =
  [ { src = "images/x/1.jpg"
    , name = "Björn"
    , link = "https://www.flickr.com/photos/adabo/28659408095/"
    }
  ]


oHead : Ref
oHead =
  { src = "images/o/0.jpg"
  , name = "Tom Magliery"
  , link = "https://www.flickr.com/photos/mag3737/2286486623/"
  }

oTail : List Ref
oTail =
  [ { src = "images/o/1.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2371325881/"
    }
  ]
