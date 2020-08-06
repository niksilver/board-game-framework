-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module Images exposing (Ref, xRef, oRef)


import Array exposing (Array)

import Marks exposing (Mark(..))


type alias Ref =
  { src : String
  , name : String
  , link : String
  }


xs : Array Ref
xs =
  xHead :: xTail
  |> Array.fromList


os : Array Ref
os =
  oHead :: oTail
  |> Array.fromList


markRef : Ref -> Array Ref -> Int -> Ref
markRef default array num =
  let
    idx =
      num
      |> modBy (Array.length array)
  in
  case Array.get idx array of
    Nothing ->
      default

    Just ref ->
      ref


xRef : Int -> Ref
xRef =
  markRef xHead xs


oRef : Int -> Ref
oRef =
  markRef oHead os


xHead : Ref
xHead =
  { src = "images/x/0.jpg"
  , name = "Patrícia Lobo"
  , link = "https://www.flickr.com/photos/srta_lobo/22322265/"
  }


xTail : List Ref
xTail =
  [ { src = "images/x/1.jpg"
    , name = "Pabellón de México de la Isla de la Cartuja"
    , link = "https://www.flickr.com/photos/miglesias/14114788851/"
    }
  , { src = "images/x/2.jpg"
    , name = "Follow me on Twitter, Tumblr, or Diaspora*"
    , link = "https://www.flickr.com/photos/adabo/28659408095/"
    }
  , { src = "images/x/3.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/437040711/"
    }
  , { src = "images/x/4.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/338679886/"
    }
  , { src = "images/x/5.jpg"
    , name = "stomen"
    , link = "https://www.flickr.com/photos/stomen/581113862/"
    }
  , { src = "images/x/6.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/7895949896/"
    }
  , { src = "images/x/7.jpg"
    , name = "2020-040 6/52"
    , link = "https://www.flickr.com/photos/el_ramon/49512289641/"
    }
  , { src = "images/x/8.jpg"
    , name = "ThoreauDown"
    , link = "https://www.flickr.com/photos/thoreaudown/4462010636/"
    }
  , { src = "images/x/9.jpg"
    , name = "Karyn Christner"
    , link = "https://www.flickr.com/photos/toofarnorth/1976928551/"
    }
  , { src = "images/x/10.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8049594329/"
    }
  , { src = "images/x/11.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/202058768/"
    }
  , { src = "images/x/12.jpg"
    , name = "Karyn Christner"
    , link = "https://www.flickr.com/photos/toofarnorth/2640277187/"
    }
  , { src = "images/x/13.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/16861230960/"
    }
  , { src = "images/x/14.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/2333776824/"
    }
  , { src = "images/x/15.jpg"
    , name = "[Mesa, Arizona]"
    , link = "https://www.flickr.com/photos/donut2d/7897244/"
    }
  , { src = "images/x/16.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/30126568570/"
    }
  , { src = "images/x/17.jpg"
    , name = "letter X a light on the school wall in Milton"
    , link = "https://www.flickr.com/photos/kiermacz/3461029517/"
    }
  , { src = "images/x/18.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/182858181/"
    }
  , { src = "images/x/19.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5645699930/"
    }
  , { src = "images/x/20.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/377018022/"
    }
  , { src = "images/x/21.jpg"
    , name = "Alvin Trusty"
    , link = "https://www.flickr.com/photos/wclaphotography/9113796592/"
    }
  , { src = "images/x/22.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/158985299/"
    }
  , { src = "images/x/23.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5987020486/"
    }
  , { src = "images/x/24.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/367538757/"
    }
  , { src = "images/x/25.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/6138424021/"
    }
  , { src = "images/x/26.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/3789759262/"
    }
  , { src = "images/x/27.jpg"
    , name = "boris drenec"
    , link = "https://www.flickr.com/photos/_boris/569118974/"
    }
  , { src = "images/x/28.jpg"
    , name = "accidental and on the streets of Shoxditch"
    , link = "https://www.flickr.com/photos/jeremygetscash/3090869594/"
    }
  , { src = "images/x/29.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5987018910/"
    }
  , { src = "images/x/30.jpg"
    , name = "Voigtlander Bessa R2, Color-Skopar 35mm."
    , link = "https://www.flickr.com/photos/jonroman/41206611494/"
    }
  , { src = "images/x/31.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/23862771503/"
    }
  , { src = "images/x/32.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/6480338013/"
    }
  , { src = "images/x/33.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5987020702/"
    }
  , { src = "images/x/34.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/312983060/"
    }
  , { src = "images/x/35.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/158983348/"
    }
  , { src = "images/x/36.jpg"
    , name = "boris drenec"
    , link = "https://www.flickr.com/photos/_boris/2767435675/"
    }
  , { src = "images/x/37.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/149476669/"
    }
  , { src = "images/x/38.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/158983570/"
    }
  , { src = "images/x/39.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/202049432/"
    }
  , { src = "images/x/40.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/226345416/"
    }
  , { src = "images/x/41.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/114302806/"
    }
  , { src = "images/x/42.jpg"
    , name = "falcon0125"
    , link = "https://www.flickr.com/photos/falcon19880125/3029180868/"
    }
  , { src = "images/x/43.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/158983251/"
    }
  , { src = "images/x/44.jpg"
    , name = "Pat.Mtl."
    , link = "https://www.flickr.com/photos/seemypicshere_pat/4125965432/"
    }
  , { src = "images/x/45.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/3411096285/"
    }
  , { src = "images/x/46.jpg"
    , name = "J M"
    , link = "https://www.flickr.com/photos/jmsmytaste/107479706/"
    }
  , { src = "images/x/47.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5986496229/"
    }
  , { src = "images/x/48.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/184813490/"
    }
  , { src = "images/x/49.jpg"
    , name = "sofia hög"
    , link = "https://www.flickr.com/photos/63465296@N07/8517164923/"
    }
  , { src = "images/x/50.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/114302718/"
    }
  , { src = "images/x/51.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/158985240/"
    }
  , { src = "images/x/52.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/226345622/"
    }
  , { src = "images/x/53.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/114303725/"
    }
  , { src = "images/x/54.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/2443794738/"
    }
  , { src = "images/x/55.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/158983196/"
    }
  , { src = "images/x/56.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/487463283/"
    }
  , { src = "images/x/57.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/487431868/"
    }
  , { src = "images/x/58.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/528795547/"
    }
  , { src = "images/x/59.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/6444139697/"
    }
  , { src = "images/x/60.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/9339599532/"
    }
  , { src = "images/x/61.jpg"
    , name = "Kate Andrews"
    , link = "https://www.flickr.com/photos/thedepartment/29640955/"
    }
  , { src = "images/x/62.jpg"
    , name = "Shot for A-Ö -set"
    , link = "https://www.flickr.com/photos/zunkkis/3010236037/"
    }
  , { src = "images/x/63.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/8967245205/"
    }
  , { src = "images/x/64.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/215494056/"
    }
  , { src = "images/x/65.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/2270030010/"
    }
  , { src = "images/x/66.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/566538386/"
    }
  , { src = "images/x/67.jpg"
    , name = "Thomas Hawk"
    , link = "https://www.flickr.com/photos/thomashawk/37620228412/"
    }
  , { src = "images/x/68.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/16765172345/"
    }
  , { src = "images/x/69.jpg"
    , name = "Chris Smith"
    , link = "https://www.flickr.com/photos/cjsmithphotography/12432840033/"
    }
  , { src = "images/x/70.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/537708260/"
    }
  , { src = "images/x/71.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/26945844184/"
    }
  , { src = "images/x/72.jpg"
    , name = "Daniel Tejedor"
    , link = "https://www.flickr.com/photos/137221047@N04/44826306025/"
    }
  , { src = "images/x/73.jpg"
    , name = "Thomas Hawk"
    , link = "https://www.flickr.com/photos/thomashawk/27809279749/"
    }
  , { src = "images/x/74.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/6142943062/"
    }
  , { src = "images/x/75.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/244674768/"
    }
  , { src = "images/x/76.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/3582875464/"
    }
  , { src = "images/x/77.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/399308894/"
    }
  , { src = "images/x/78.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/6312749935/"
    }
  , { src = "images/x/79.jpg"
    , name = "The Other Dan"
    , link = "https://www.flickr.com/photos/theotherdan/484651465/"
    }
  , { src = "images/x/80.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/5709126189/"
    }
  , { src = "images/x/81.jpg"
    , name = "boris drenec"
    , link = "https://www.flickr.com/photos/_boris/6002378384/"
    }
  , { src = "images/x/82.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/23345492416/"
    }
  , { src = "images/x/83.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/6242700214/"
    }
  , { src = "images/x/84.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/19823472461/"
    }
  , { src = "images/x/85.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8707880575/"
    }
  , { src = "images/x/86.jpg"
    , name = "Miguel Ariel Contreras Drake-McLaughlin"
    , link = "https://www.flickr.com/photos/bigbabymiguel/2459376341/"
    }
  , { src = "images/x/87.jpg"
    , name = "Amber Orenstein"
    , link = "https://www.flickr.com/photos/2is3/2350657726/"
    }
  , { src = "images/x/88.jpg"
    , name = "boris drenec"
    , link = "https://www.flickr.com/photos/_boris/267804756/"
    }
  , { src = "images/x/89.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/5820884646/"
    }
  , { src = "images/x/90.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/7378902494/"
    }
  , { src = "images/x/91.jpg"
    , name = "Romain Piera"
    , link = "https://www.flickr.com/photos/rom01/35202543195/"
    }
  , { src = "images/x/92.jpg"
    , name = "universaldilletant"
    , link = "https://www.flickr.com/photos/universaldilletant/25012938882/"
    }
  , { src = "images/x/93.jpg"
    , name = "Judith"
    , link = "https://www.flickr.com/photos/29997533@N03/48786079243/"
    }
  , { src = "images/x/94.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/7645245776/"
    }
  , { src = "images/x/95.jpg"
    , name = "Gijón // Spain"
    , link = "https://www.flickr.com/photos/stencilsrx/8161016839/"
    }
  , { src = "images/x/96.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5792971358/"
    }
  , { src = "images/x/97.jpg"
    , name = "Wasatch County, Utah."
    , link = "https://www.flickr.com/photos/19779889@N00/29959871538/"
    }
  , { src = "images/x/98.jpg"
    , name = "Emiliano Grusovin"
    , link = "https://www.flickr.com/photos/emiliano-iko/28845305145/"
    }
  ]

oHead : Ref
oHead =
  { src = "images/o/0.jpg"
  , name = "Tom Magliery"
  , link = "https://www.flickr.com/photos/mag3737/2196424855/"
  }

oTail : List Ref
oTail =
  [ { src = "images/o/1.jpg"
    , name = "Howard Stanbury"
    , link = "https://www.flickr.com/photos/stanbury/9815355/"
    }
  , { src = "images/o/2.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/36252614/"
    }
  , { src = "images/o/3.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/1351781514/"
    }
  , { src = "images/o/4.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/94748840/"
    }
  , { src = "images/o/5.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2286486623/"
    }
  , { src = "images/o/6.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/3086261259/"
    }
  , { src = "images/o/7.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/50080439522/"
    }
  , { src = "images/o/8.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2371325881/"
    }
  , { src = "images/o/9.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/20371714790/"
    }
  , { src = "images/o/10.jpg"
    , name = "Brett Patterson"
    , link = "https://www.flickr.com/photos/brettpatterson/4392322123/"
    }
  , { src = "images/o/11.jpg"
    , name = "Karyn Christner"
    , link = "https://www.flickr.com/photos/toofarnorth/2641104292/"
    }
  , { src = "images/o/12.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5917422625/"
    }
  , { src = "images/o/13.jpg"
    , name = "Karyn Christner"
    , link = "https://www.flickr.com/photos/toofarnorth/128737320/"
    }
  , { src = "images/o/14.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/2743752773/"
    }
  , { src = "images/o/15.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://www.flickr.com/photos/41002268@N03/4593339607/"
    }
  , { src = "images/o/16.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://www.flickr.com/photos/41002268@N03/4593342161/"
    }
  , { src = "images/o/17.jpg"
    , name = "Mary Hockenbery"
    , link = "https://www.flickr.com/photos/reddirtrose/1012662624/"
    }
  , { src = "images/o/18.jpg"
    , name = "easy enough.."
    , link = "https://www.flickr.com/photos/thoreaudown/4460929557/"
    }
  , { src = "images/o/19.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2090758756/"
    }
  , { src = "images/o/20.jpg"
    , name = "Mark Simpkins"
    , link = "https://www.flickr.com/photos/marksimpkins/39523552/"
    }
  , { src = "images/o/21.jpg"
    , name = "Karyn Christner"
    , link = "https://www.flickr.com/photos/toofarnorth/5501027093/"
    }
  , { src = "images/o/22.jpg"
    , name = "Karyn Christner"
    , link = "https://www.flickr.com/photos/toofarnorth/1501179314/"
    }
  , { src = "images/o/23.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/120874452/"
    }
  , { src = "images/o/24.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/9065097992/"
    }
  , { src = "images/o/25.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5845617174/"
    }
  , { src = "images/o/26.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/149475623/"
    }
  , { src = "images/o/27.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/2457393747/"
    }
  , { src = "images/o/28.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/137096798/"
    }
  , { src = "images/o/29.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5845858762/"
    }
  , { src = "images/o/30.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/518516030/"
    }
  , { src = "images/o/31.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/397460214/"
    }
  , { src = "images/o/32.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/3824180237/"
    }
  , { src = "images/o/33.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8562387285/"
    }
  , { src = "images/o/34.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8562375477/"
    }
  , { src = "images/o/35.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2231644893/"
    }
  , { src = "images/o/36.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/2652748571/"
    }
  , { src = "images/o/37.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8049582673/"
    }
  , { src = "images/o/38.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/9062877503/"
    }
  , { src = "images/o/39.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2633461630/"
    }
  , { src = "images/o/40.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/2743737853/"
    }
  , { src = "images/o/41.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/158985325/"
    }
  , { src = "images/o/42.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/226359071/"
    }
  , { src = "images/o/43.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/1572609476/"
    }
  , { src = "images/o/44.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/1197620379/"
    }
  , { src = "images/o/45.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/118376065/"
    }
  , { src = "images/o/46.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8049597634/"
    }
  , { src = "images/o/47.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/514217328/"
    }
  , { src = "images/o/48.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2185719247/"
    }
  , { src = "images/o/49.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2594450936/"
    }
  , { src = "images/o/50.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8202988253/"
    }
  , { src = "images/o/51.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5332523666/"
    }
  , { src = "images/o/52.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/362755499/"
    }
  , { src = "images/o/53.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/115573940/"
    }
  , { src = "images/o/54.jpg"
    , name = "duncan c"
    , link = "https://www.flickr.com/photos/duncan/537830161/"
    }
  , { src = "images/o/55.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/514249239/"
    }
  , { src = "images/o/56.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5845679242/"
    }
  , { src = "images/o/57.jpg"
    , name = "Pat Joyce"
    , link = "https://www.flickr.com/photos/phatcontroller/5401691576/"
    }
  , { src = "images/o/58.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/3789240809/"
    }
  , { src = "images/o/59.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5830485303/"
    }
  , { src = "images/o/60.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/922098188/"
    }
  , { src = "images/o/61.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/402819245/"
    }
  , { src = "images/o/62.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/112661896/"
    }
  , { src = "images/o/63.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5942404498/"
    }
  , { src = "images/o/64.jpg"
    , name = "Alvin Trusty"
    , link = "https://www.flickr.com/photos/wclaphotography/9113796878/"
    }
  , { src = "images/o/65.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/9065107146/"
    }
  , { src = "images/o/66.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/2371323705/"
    }
  , { src = "images/o/67.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/119577094/"
    }
  , { src = "images/o/68.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/31945462313/"
    }
  , { src = "images/o/69.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/129596176/"
    }
  , { src = "images/o/70.jpg"
    , name = "From a red Corvette 1961"
    , link = "https://www.flickr.com/photos/monceau/129596272/"
    }
  , { src = "images/o/71.jpg"
    , name = "vd1966"
    , link = "https://www.flickr.com/photos/vd1966/48821375302/"
    }
  , { src = "images/o/72.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/6034473996/"
    }
  , { src = "images/o/73.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/185815523/"
    }
  , { src = "images/o/74.jpg"
    , name = "Letter O"
    , link = "https://www.flickr.com/photos/chrisinplymouth/4888235059/"
    }
  , { src = "images/o/75.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/226363735/"
    }
  , { src = "images/o/76.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8630711898/"
    }
  , { src = "images/o/77.jpg"
    , name = "Judith, Bremen"
    , link = "https://www.flickr.com/photos/revoltee/16143766384/"
    }
  , { src = "images/o/78.jpg"
    , name = "Norm Wright"
    , link = "https://www.flickr.com/photos/wwnorm/8515087736/"
    }
  , { src = "images/o/79.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/7895950334/"
    }
  , { src = "images/o/80.jpg"
    , name = "Pekka Nikrus"
    , link = "https://www.flickr.com/photos/skrubu/42174884894/"
    }
  , { src = "images/o/81.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/198424329/"
    }
  , { src = "images/o/82.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8049580761/"
    }
  , { src = "images/o/83.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/9065108266/"
    }
  , { src = "images/o/84.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/5659862566/"
    }
  , { src = "images/o/85.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/8606990362/"
    }
  , { src = "images/o/86.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/14570729736/"
    }
  , { src = "images/o/87.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/14407338147/"
    }
  , { src = "images/o/88.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/240972296/"
    }
  , { src = "images/o/89.jpg"
    , name = "as in Otis"
    , link = "https://www.flickr.com/photos/mag3737/377132686/"
    }
  , { src = "images/o/90.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/184812776/"
    }
  , { src = "images/o/91.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/9065106258/"
    }
  , { src = "images/o/92.jpg"
    , name = "Jess C"
    , link = "https://www.flickr.com/photos/slipstreamjc/76710277/"
    }
  , { src = "images/o/93.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/110630772/"
    }
  , { src = "images/o/94.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/9062877775/"
    }
  , { src = "images/o/95.jpg"
    , name = "Tom Magliery"
    , link = "https://www.flickr.com/photos/mag3737/3901957083/"
    }
  , { src = "images/o/96.jpg"
    , name = "Monceau"
    , link = "https://www.flickr.com/photos/monceau/2428973772/"
    }
  , { src = "images/o/97.jpg"
    , name = "Marko V Niemelä"
    , link = "https://www.flickr.com/photos/152084464@N08/48331560391/"
    }
  ]
