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
  , name = "Patrícia Lobo"
  , link = "https://live.staticflickr.com/17/22322265_cea2967432_o.jpg"
  }


xTail : List Ref
xTail =
  [ { src = "images/x/1.jpg"
    , name = "Pabellón de México de la Isla de la Cartuja"
    , link = "https://live.staticflickr.com/7335/14114788851_8ce4713c51_o.jpg"
    }
  , { src = "images/x/2.jpg"
    , name = "Follow me on Twitter, Tumblr, or Diaspora*"
    , link = "https://live.staticflickr.com/8652/28659408095_9db7dcb12c_o.jpg"
    }
  , { src = "images/x/3.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/155/437040711_e09094a34e_o.jpg"
    }
  , { src = "images/x/4.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/138/338679886_3fccb0c56c_o.jpg"
    }
  , { src = "images/x/5.jpg"
    , name = "stomen"
    , link = "https://live.staticflickr.com/1004/581113862_ea9565cfd2_o.jpg"
    }
  , { src = "images/x/6.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/8042/7895949896_af3d773ab2_o.jpg"
    }
  , { src = "images/x/7.jpg"
    , name = "2020-040 6/52"
    , link = "https://live.staticflickr.com/65535/49512289641_2af631ac81_o.jpg"
    }
  , { src = "images/x/8.jpg"
    , name = "ThoreauDown"
    , link = "https://live.staticflickr.com/4069/4462010636_2f52d91042_o.jpg"
    }
  , { src = "images/x/9.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/2088/1976928551_7ca556e17c_o.jpg"
    }
  , { src = "images/x/10.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8319/8049594329_3a68e4a867_o.jpg"
    }
  , { src = "images/x/11.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/58/202058768_7d60bc49b0_o.jpg"
    }
  , { src = "images/x/12.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/3034/2640277187_65bcf12b62_o.jpg"
    }
  , { src = "images/x/13.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/8783/16861230960_53e1955551_o.jpg"
    }
  , { src = "images/x/14.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/3234/2333776824_cb47dcabc5_o.jpg"
    }
  , { src = "images/x/15.jpg"
    , name = "[Mesa, Arizona]"
    , link = "https://live.staticflickr.com/8/7897244_3731c0cfd5_o.jpg"
    }
  , { src = "images/x/16.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/5339/30126568570_27d1490f9a_o.jpg"
    }
  , { src = "images/x/17.jpg"
    , name = "letter X a light on the school wall in Milton"
    , link = "https://live.staticflickr.com/3633/3461029517_b2ae8a3fb3_o.jpg"
    }
  , { src = "images/x/18.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/68/182858181_4b77bc37f0_o.jpg"
    }
  , { src = "images/x/19.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5150/5645699930_b7535c2f86_o.jpg"
    }
  , { src = "images/x/20.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/126/377018022_c7e6995170_o.jpg"
    }
  , { src = "images/x/21.jpg"
    , name = "Alvin Trusty"
    , link = "https://live.staticflickr.com/5444/9113796592_f3158a0ed3_o.jpg"
    }
  , { src = "images/x/22.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/71/158985299_4328c1afff_o.jpg"
    }
  , { src = "images/x/23.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6016/5987020486_90ae282790_o.jpg"
    }
  , { src = "images/x/24.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/148/367538757_d860de74f1_o.jpg"
    }
  , { src = "images/x/25.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6070/6138424021_2b0c1c5ea8_o.jpg"
    }
  , { src = "images/x/26.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/2531/3789759262_cd9a4e3e6d_o.jpg"
    }
  , { src = "images/x/27.jpg"
    , name = "boris drenec"
    , link = "https://live.staticflickr.com/1020/569118974_11f068d39b_o.jpg"
    }
  , { src = "images/x/28.jpg"
    , name = "accidental and on the streets of Shoxditch"
    , link = "https://live.staticflickr.com/3022/3090869594_c2c53f65ea_o.jpg"
    }
  , { src = "images/x/29.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6021/5987018910_948f6ddd16_o.jpg"
    }
  , { src = "images/x/30.jpg"
    , name = "Voigtlander Bessa R2, Color-Skopar 35mm."
    , link = "https://live.staticflickr.com/964/41206611494_4bc234cfcf_o.jpg"
    }
  , { src = "images/x/31.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1470/23862771503_66e8da6b44_o.jpg"
    }
  , { src = "images/x/32.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/7011/6480338013_47e380c652_o.jpg"
    }
  , { src = "images/x/33.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6126/5987020702_60a94b6a00_o.jpg"
    }
  , { src = "images/x/34.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/112/312983060_189a42b510_o.jpg"
    }
  , { src = "images/x/35.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/47/158983348_0920c49121_o.jpg"
    }
  , { src = "images/x/36.jpg"
    , name = "boris drenec"
    , link = "https://live.staticflickr.com/3217/2767435675_0d0ccb7d7f_o.jpg"
    }
  , { src = "images/x/37.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/54/149476669_8462be3f33_o.jpg"
    }
  , { src = "images/x/38.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/46/158983570_33eb46db0d_o.jpg"
    }
  , { src = "images/x/39.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/63/202049432_350e1fc4c3_o.jpg"
    }
  , { src = "images/x/40.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/95/226345416_8389696793_o.jpg"
    }
  , { src = "images/x/41.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/42/114302806_9d5f53a71f_o.jpg"
    }
  , { src = "images/x/42.jpg"
    , name = "falcon0125"
    , link = "https://live.staticflickr.com/3229/3029180868_034b2ec0bb_o.jpg"
    }
  , { src = "images/x/43.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/56/158983251_d45ad4bbab_o.jpg"
    }
  , { src = "images/x/44.jpg"
    , name = "Pat.Mtl."
    , link = "https://live.staticflickr.com/2626/4125965432_dc2014e970_o.jpg"
    }
  , { src = "images/x/45.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/3537/3411096285_70926bdc3a_o.jpg"
    }
  , { src = "images/x/46.jpg"
    , name = "J M"
    , link = "https://live.staticflickr.com/36/107479706_0bb616150c_o.jpg"
    }
  , { src = "images/x/47.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6023/5986496229_2d0289b254_o.jpg"
    }
  , { src = "images/x/48.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/60/184813490_ee8809efc2_o.jpg"
    }
  , { src = "images/x/49.jpg"
    , name = "sofia hög"
    , link = "https://live.staticflickr.com/8112/8517164923_7ecf712033_o.jpg"
    }
  , { src = "images/x/50.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/55/114302718_d18b591f78_o.jpg"
    }
  , { src = "images/x/51.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/52/158985240_51467bbac5_o.jpg"
    }
  , { src = "images/x/52.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/58/226345622_2c85602308_o.jpg"
    }
  , { src = "images/x/53.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/36/114303725_e6f9f03247_o.jpg"
    }
  , { src = "images/x/54.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/2258/2443794738_d8b1fbdcec_o.jpg"
    }
  , { src = "images/x/55.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/60/158983196_6a74c185a4_o.jpg"
    }
  , { src = "images/x/56.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/213/487463283_4c85c9fd97_o.jpg"
    }
  , { src = "images/x/57.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/169/487431868_1e3b6f0fbf_o.jpg"
    }
  , { src = "images/x/58.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1203/528795547_920e7dfff4_o.jpg"
    }
  , { src = "images/x/59.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/7154/6444139697_8ac95959b8_o.jpg"
    }
  , { src = "images/x/60.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/7460/9339599532_4e3bb915d1_o.jpg"
    }
  , { src = "images/x/61.jpg"
    , name = "Kate Andrews"
    , link = "https://live.staticflickr.com/23/29640955_3e3648a4d5_o.jpg"
    }
  , { src = "images/x/62.jpg"
    , name = "Shot for A-Ö -set"
    , link = "https://live.staticflickr.com/3254/3010236037_d3de6c6fda_o.jpg"
    }
  , { src = "images/x/63.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/7318/8967245205_b62a7bc10d_o.jpg"
    }
  , { src = "images/x/64.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/93/215494056_49342ea98c_o.jpg"
    }
  , { src = "images/x/65.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/2204/2270030010_21617d5fdf_o.jpg"
    }
  , { src = "images/x/66.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1095/566538386_b0582d2f85_o.jpg"
    }
  , { src = "images/x/67.jpg"
    , name = "Thomas Hawk"
    , link = "https://live.staticflickr.com/4451/37620228412_96f87f452f_o.jpg"
    }
  , { src = "images/x/68.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/7288/16765172345_7d2e17e7dd_o.jpg"
    }
  , { src = "images/x/69.jpg"
    , name = "Chris Smith"
    , link = "https://live.staticflickr.com/7429/12432840033_9d36a3551d_o.jpg"
    }
  , { src = "images/x/70.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/1196/537708260_0df6a79d0c_o.jpg"
    }
  , { src = "images/x/71.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/7531/26945844184_2aa8d7701a_o.jpg"
    }
  , { src = "images/x/72.jpg"
    , name = "Daniel Tejedor"
    , link = "https://live.staticflickr.com/1968/44826306025_a88e794a5c_o.jpg"
    }
  , { src = "images/x/73.jpg"
    , name = "Thomas Hawk"
    , link = "https://live.staticflickr.com/4710/27809279749_c4faf3913b_o.jpg"
    }
  , { src = "images/x/74.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6087/6142943062_d102403221_o.jpg"
    }
  , { src = "images/x/75.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/80/244674768_60702c8d44_o.jpg"
    }
  , { src = "images/x/76.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/3604/3582875464_2fc42c60bf_o.jpg"
    }
  , { src = "images/x/77.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/182/399308894_d0c6049a32_o.jpg"
    }
  , { src = "images/x/78.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/6239/6312749935_7448bf1231_o.jpg"
    }
  , { src = "images/x/79.jpg"
    , name = "The Other Dan"
    , link = "https://live.staticflickr.com/186/484651465_1a94af281d_o.jpg"
    }
  , { src = "images/x/80.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/3489/5709126189_52b6b9ecde_o.jpg"
    }
  , { src = "images/x/81.jpg"
    , name = "boris drenec"
    , link = "https://live.staticflickr.com/6006/6002378384_12b5397f6d_o.jpg"
    }
  , { src = "images/x/82.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/5691/23345492416_382ab81607_o.jpg"
    }
  , { src = "images/x/83.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/6052/6242700214_c506ca629c_o.jpg"
    }
  , { src = "images/x/84.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/299/19823472461_e04af77505_o.jpg"
    }
  , { src = "images/x/85.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8398/8707880575_88360ba010_o.jpg"
    }
  , { src = "images/x/86.jpg"
    , name = "Miguel Ariel Contreras Drake-McLaughlin"
    , link = "https://live.staticflickr.com/2363/2459376341_d1671eab3c_o.jpg"
    }
  , { src = "images/x/87.jpg"
    , name = "Amber Orenstein"
    , link = "https://live.staticflickr.com/2358/2350657726_c8265c9592_o.jpg"
    }
  , { src = "images/x/88.jpg"
    , name = "boris drenec"
    , link = "https://live.staticflickr.com/120/267804756_6f08024a72_o.jpg"
    }
  , { src = "images/x/89.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/2136/5820884646_fdd3b0d66a_o.jpg"
    }
  , { src = "images/x/90.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/8144/7378902494_d0d4e74364_o.jpg"
    }
  , { src = "images/x/91.jpg"
    , name = "Romain Piera"
    , link = "https://live.staticflickr.com/4222/35202543195_8ccc4ed7fc_o.jpg"
    }
  , { src = "images/x/92.jpg"
    , name = "universaldilletant"
    , link = "https://live.staticflickr.com/1609/25012938882_aa31c1581e_o.jpg"
    }
  , { src = "images/x/93.jpg"
    , name = "Judith"
    , link = "https://live.staticflickr.com/65535/48786079243_e107c167ed_o.jpg"
    }
  , { src = "images/x/94.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/8168/7645245776_0730ab2f3c_o.jpg"
    }
  , { src = "images/x/95.jpg"
    , name = "Gijón // Spain"
    , link = "https://live.staticflickr.com/8348/8161016839_fa33022591_o.jpg"
    }
  , { src = "images/x/96.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3187/5792971358_998ab364c7_o.jpg"
    }
  , { src = "images/x/97.jpg"
    , name = "Wasatch County, Utah."
    , link = "https://live.staticflickr.com/938/29959871538_25f88cbf34_o.jpg"
    }
  , { src = "images/x/98.jpg"
    , name = "Emiliano Grusovin"
    , link = "https://live.staticflickr.com/8204/28845305145_41512b3035_o.jpg"
    }
  ]


oHead : Ref
oHead =
  { src = "images/o/0.jpg"
  , name = "Tom Magliery"
  , link = "https://live.staticflickr.com/2110/2196424855_e7242cc725_o.jpg"
  }

oTail : List Ref
oTail =
  [ { src = "images/o/1.jpg"
    , name = "Howard Stanbury"
    , link = "https://live.staticflickr.com/8/9815355_68d92b53d5_o.jpg"
    }
  , { src = "images/o/2.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/27/36252614_67739cc0df_o.jpg"
    }
  , { src = "images/o/3.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2110/2196424855_e7242cc725_o.jpg"
    }
  , { src = "images/o/4.jpg"
    , name = "Howard Stanbury"
    , link = "https://live.staticflickr.com/8/9815355_68d92b53d5_o.jpg"
    }
  , { src = "images/o/5.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/27/36252614_67739cc0df_o.jpg"
    }
  , { src = "images/o/6.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1305/1351781514_5b87c5be4a_o.jpg"
    }
  , { src = "images/o/7.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/26/94748840_1afcb9fa64_o.jpg"
    }
  , { src = "images/o/8.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2257/2286486623_7bdbd2194a_o.jpg"
    }
  , { src = "images/o/9.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/3156/3086261259_2a69ec158e_o.jpg"
    }
  , { src = "images/o/10.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/65535/50080439522_2fe1abc20c_o.jpg"
    }
  , { src = "images/o/11.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2389/2371325881_ecea401f6d_o.jpg"
    }
  , { src = "images/o/12.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5660/20371714790_19702c80fb_o.jpg"
    }
  , { src = "images/o/13.jpg"
    , name = "Brett Patterson"
    , link = "https://live.staticflickr.com/4048/4392322123_ac55389883_o.jpg"
    }
  , { src = "images/o/14.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/3076/2641104292_4324918ef0_o.jpg"
    }
  , { src = "images/o/15.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6121/5917422625_4ebc36f3d3_o.jpg"
    }
  , { src = "images/o/16.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/48/128737320_dfe64beee0_o.jpg"
    }
  , { src = "images/o/17.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/3113/2743752773_04d02ba0df_o.jpg"
    }
  , { src = "images/o/18.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://live.staticflickr.com/3218/4593339607_ea7ffbeef6_o.jpg"
    }
  , { src = "images/o/19.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://live.staticflickr.com/1361/4593342161_fffe940a75_o.jpg"
    }
  , { src = "images/o/20.jpg"
    , name = "Mary Hockenbery"
    , link = "https://live.staticflickr.com/1228/1012662624_3699e2ff34_o.jpg"
    }
  , { src = "images/o/21.jpg"
    , name = "easy enough.."
    , link = "https://live.staticflickr.com/4063/4460929557_d6d426801d_o.jpg"
    }
  , { src = "images/o/22.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2086/2090758756_2f1400df7a_o.jpg"
    }
  , { src = "images/o/23.jpg"
    , name = "Mark Simpkins"
    , link = "https://live.staticflickr.com/23/39523552_1677de567b_o.jpg"
    }
  , { src = "images/o/24.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/5180/5501027093_646c412428_o.jpg"
    }
  , { src = "images/o/25.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/2407/1501179314_6e192c04ca_o.jpg"
    }
  , { src = "images/o/26.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/43/120874452_80dbc67976_o.jpg"
    }
  , { src = "images/o/27.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/7343/9065097992_032911e010_o.jpg"
    }
  , { src = "images/o/28.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3534/5845617174_bb461c4309_o.jpg"
    }
  , { src = "images/o/29.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/46/149475623_17b4c7d235_o.jpg"
    }
  , { src = "images/o/30.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/2091/2457393747_c9ca477848_o.jpg"
    }
  , { src = "images/o/31.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/48/137096798_a2c52bc907_o.jpg"
    }
  , { src = "images/o/32.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3168/5845858762_6664864031_o.jpg"
    }
  , { src = "images/o/33.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/228/518516030_26075a5441_o.jpg"
    }
  , { src = "images/o/34.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/129/397460214_2e2a2b1d0f_o.jpg"
    }
  , { src = "images/o/35.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3646/3824180237_5050bb90af_o.jpg"
    }
  , { src = "images/o/36.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8107/8562387285_858f79403a_o.jpg"
    }
  , { src = "images/o/37.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8094/8562375477_939fda16a1_o.jpg"
    }
  , { src = "images/o/38.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2029/2231644893_f3cce2d46e_o.jpg"
    }
  , { src = "images/o/39.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2110/2196424855_e7242cc725_o.jpg"
    }
  , { src = "images/o/40.jpg"
    , name = "Howard Stanbury"
    , link = "https://live.staticflickr.com/8/9815355_68d92b53d5_o.jpg"
    }
  , { src = "images/o/41.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/27/36252614_67739cc0df_o.jpg"
    }
  , { src = "images/o/42.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1305/1351781514_5b87c5be4a_o.jpg"
    }
  , { src = "images/o/43.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/26/94748840_1afcb9fa64_o.jpg"
    }
  , { src = "images/o/44.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2257/2286486623_7bdbd2194a_o.jpg"
    }
  , { src = "images/o/45.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/3156/3086261259_2a69ec158e_o.jpg"
    }
  , { src = "images/o/46.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/65535/50080439522_2fe1abc20c_o.jpg"
    }
  , { src = "images/o/47.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2389/2371325881_ecea401f6d_o.jpg"
    }
  , { src = "images/o/48.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5660/20371714790_19702c80fb_o.jpg"
    }
  , { src = "images/o/49.jpg"
    , name = "Brett Patterson"
    , link = "https://live.staticflickr.com/4048/4392322123_ac55389883_o.jpg"
    }
  , { src = "images/o/50.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/3076/2641104292_4324918ef0_o.jpg"
    }
  , { src = "images/o/51.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6121/5917422625_4ebc36f3d3_o.jpg"
    }
  , { src = "images/o/52.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/48/128737320_dfe64beee0_o.jpg"
    }
  , { src = "images/o/53.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/3113/2743752773_04d02ba0df_o.jpg"
    }
  , { src = "images/o/54.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://live.staticflickr.com/3218/4593339607_ea7ffbeef6_o.jpg"
    }
  , { src = "images/o/55.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://live.staticflickr.com/1361/4593342161_fffe940a75_o.jpg"
    }
  , { src = "images/o/56.jpg"
    , name = "Mary Hockenbery"
    , link = "https://live.staticflickr.com/1228/1012662624_3699e2ff34_o.jpg"
    }
  , { src = "images/o/57.jpg"
    , name = "easy enough.."
    , link = "https://live.staticflickr.com/4063/4460929557_d6d426801d_o.jpg"
    }
  , { src = "images/o/58.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2086/2090758756_2f1400df7a_o.jpg"
    }
  , { src = "images/o/59.jpg"
    , name = "Mark Simpkins"
    , link = "https://live.staticflickr.com/23/39523552_1677de567b_o.jpg"
    }
  , { src = "images/o/60.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/5180/5501027093_646c412428_o.jpg"
    }
  , { src = "images/o/61.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/2407/1501179314_6e192c04ca_o.jpg"
    }
  , { src = "images/o/62.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/43/120874452_80dbc67976_o.jpg"
    }
  , { src = "images/o/63.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/7343/9065097992_032911e010_o.jpg"
    }
  , { src = "images/o/64.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3534/5845617174_bb461c4309_o.jpg"
    }
  , { src = "images/o/65.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/46/149475623_17b4c7d235_o.jpg"
    }
  , { src = "images/o/66.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/2091/2457393747_c9ca477848_o.jpg"
    }
  , { src = "images/o/67.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/48/137096798_a2c52bc907_o.jpg"
    }
  , { src = "images/o/68.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3168/5845858762_6664864031_o.jpg"
    }
  , { src = "images/o/69.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/228/518516030_26075a5441_o.jpg"
    }
  , { src = "images/o/70.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/129/397460214_2e2a2b1d0f_o.jpg"
    }
  , { src = "images/o/71.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3646/3824180237_5050bb90af_o.jpg"
    }
  , { src = "images/o/72.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8107/8562387285_858f79403a_o.jpg"
    }
  , { src = "images/o/73.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8094/8562375477_939fda16a1_o.jpg"
    }
  , { src = "images/o/74.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2029/2231644893_f3cce2d46e_o.jpg"
    }
  , { src = "images/o/75.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/3132/2652748571_676eefde14_o.jpg"
    }
  , { src = "images/o/76.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8458/8049582673_1e89826be2_o.jpg"
    }
  , { src = "images/o/77.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3829/9062877503_a219821d01_o.jpg"
    }
  , { src = "images/o/78.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3173/2633461630_5f578c43e5_o.jpg"
    }
  , { src = "images/o/79.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/2287/2743737853_d7cf368238_o.jpg"
    }
  , { src = "images/o/80.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/45/158985325_31fb282355_o.jpg"
    }
  , { src = "images/o/81.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/93/226359071_4cf4964db9_o.jpg"
    }
  , { src = "images/o/82.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/2230/1572609476_66e2d6a9c7_o.jpg"
    }
  , { src = "images/o/83.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1407/1197620379_889ce2ea2c_o.jpg"
    }
  , { src = "images/o/84.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/19/118376065_c985b62bbc_o.jpg"
    }
  , { src = "images/o/85.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8318/8049597634_1e813e6fe9_o.jpg"
    }
  , { src = "images/o/86.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/243/514217328_105eef9e0a_o.jpg"
    }
  , { src = "images/o/87.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2052/2185719247_0c4270163b_o.jpg"
    }
  , { src = "images/o/88.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2349/2594450936_a6e4332178_o.jpg"
    }
  , { src = "images/o/89.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8478/8202988253_d20f56a284_o.jpg"
    }
  , { src = "images/o/90.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5046/5332523666_f9bec06e49_o.jpg"
    }
  , { src = "images/o/91.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/102/362755499_2dc771b82d_o.jpg"
    }
  , { src = "images/o/92.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/52/115573940_c6ff808f39_o.jpg"
    }
  , { src = "images/o/93.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/1279/537830161_e36769efc6_o.jpg"
    }
  , { src = "images/o/94.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/196/514249239_15f0b20fcf_o.jpg"
    }
  , { src = "images/o/95.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3214/5845679242_0d47ebb82f_o.jpg"
    }
  , { src = "images/o/96.jpg"
    , name = "Pat Joyce"
    , link = "https://live.staticflickr.com/5134/5401691576_6bf27ef01c_o.jpg"
    }
  , { src = "images/o/97.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/2666/3789240809_a9ab7072b1_o.jpg"
    }
  , { src = "images/o/98.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3133/5830485303_3cd98fb932_o.jpg"
    }
  , { src = "images/o/99.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1313/922098188_9568b46d23_o.jpg"
    }
  , { src = "images/o/100.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/149/402819245_3dca806273_o.jpg"
    }
  , { src = "images/o/101.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/55/112661896_b99bf7f6d1_o.jpg"
    }
  , { src = "images/o/102.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6004/5942404498_e66d13d965_o.jpg"
    }
  , { src = "images/o/103.jpg"
    , name = "Alvin Trusty"
    , link = "https://live.staticflickr.com/3696/9113796878_9e7960ef03_o.jpg"
    }
  , { src = "images/o/104.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2883/9065107146_0f95138a69_o.jpg"
    }
  , { src = "images/o/105.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2416/2371323705_4ac57d72ab_o.jpg"
    }
  , { src = "images/o/106.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/56/119577094_9555704fc7_o.jpg"
    }
  , { src = "images/o/107.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/578/31945462313_d0dd4af6f3_o.jpg"
    }
  , { src = "images/o/108.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/48/129596176_8442940856_o.jpg"
    }
  , { src = "images/o/109.jpg"
    , name = "From a red Corvette 1961"
    , link = "https://live.staticflickr.com/46/129596272_a42d873625_o.jpg"
    }
  , { src = "images/o/110.jpg"
    , name = "vd1966"
    , link = "https://live.staticflickr.com/65535/48821375302_812ba7acef_o.jpg"
    }
  , { src = "images/o/111.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6077/6034473996_fe040ae5b3_o.jpg"
    }
  , { src = "images/o/112.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/60/185815523_4a4965f521_o.jpg"
    }
  , { src = "images/o/113.jpg"
    , name = "Letter O"
    , link = "https://live.staticflickr.com/4117/4888235059_56e1536b69_o.jpg"
    }
  , { src = "images/o/114.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/98/226363735_7081b48321_o.jpg"
    }
  , { src = "images/o/115.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8242/8630711898_4c5a171531_o.jpg"
    }
  , { src = "images/o/116.jpg"
    , name = "Judith, Bremen"
    , link = "https://live.staticflickr.com/7632/16143766384_e1062cbee3_o.jpg"
    }
  , { src = "images/o/117.jpg"
    , name = "Norm Wright"
    , link = "https://live.staticflickr.com/8242/8515087736_53a389ebdb_o.jpg"
    }
  , { src = "images/o/118.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/8312/7895950334_4bbb093cdf_o.jpg"
    }
  , { src = "images/o/119.jpg"
    , name = "Pekka Nikrus"
    , link = "https://live.staticflickr.com/1754/42174884894_827d1d50de_o.jpg"
    }
  , { src = "images/o/120.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/78/198424329_1a586d5991_o.jpg"
    }
  , { src = "images/o/121.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8170/8049580761_1196c08c13_o.jpg"
    }
  , { src = "images/o/122.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3699/9065108266_a78d9e9332_o.jpg"
    }
  , { src = "images/o/123.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5150/5659862566_b0cfc45079_o.jpg"
    }
  , { src = "images/o/124.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8531/8606990362_129ed4e575_o.jpg"
    }
  , { src = "images/o/39.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2110/2196424855_e7242cc725_o.jpg"
    }
  , { src = "images/o/40.jpg"
    , name = "Howard Stanbury"
    , link = "https://live.staticflickr.com/8/9815355_68d92b53d5_o.jpg"
    }
  , { src = "images/o/41.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/27/36252614_67739cc0df_o.jpg"
    }
  , { src = "images/o/0.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2110/2196424855_e7242cc725_o.jpg"
    }
  , { src = "images/o/1.jpg"
    , name = "Howard Stanbury"
    , link = "https://live.staticflickr.com/8/9815355_68d92b53d5_o.jpg"
    }
  , { src = "images/o/2.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/27/36252614_67739cc0df_o.jpg"
    }
  , { src = "images/o/3.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1305/1351781514_5b87c5be4a_o.jpg"
    }
  , { src = "images/o/4.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/26/94748840_1afcb9fa64_o.jpg"
    }
  , { src = "images/o/5.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2257/2286486623_7bdbd2194a_o.jpg"
    }
  , { src = "images/o/6.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/3156/3086261259_2a69ec158e_o.jpg"
    }
  , { src = "images/o/7.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/65535/50080439522_2fe1abc20c_o.jpg"
    }
  , { src = "images/o/8.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2389/2371325881_ecea401f6d_o.jpg"
    }
  , { src = "images/o/9.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5660/20371714790_19702c80fb_o.jpg"
    }
  , { src = "images/o/10.jpg"
    , name = "Brett Patterson"
    , link = "https://live.staticflickr.com/4048/4392322123_ac55389883_o.jpg"
    }
  , { src = "images/o/11.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/3076/2641104292_4324918ef0_o.jpg"
    }
  , { src = "images/o/12.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6121/5917422625_4ebc36f3d3_o.jpg"
    }
  , { src = "images/o/13.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/48/128737320_dfe64beee0_o.jpg"
    }
  , { src = "images/o/14.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/3113/2743752773_04d02ba0df_o.jpg"
    }
  , { src = "images/o/15.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://live.staticflickr.com/3218/4593339607_ea7ffbeef6_o.jpg"
    }
  , { src = "images/o/16.jpg"
    , name = "1964 Ford F-100 pickup"
    , link = "https://live.staticflickr.com/1361/4593342161_fffe940a75_o.jpg"
    }
  , { src = "images/o/17.jpg"
    , name = "Mary Hockenbery"
    , link = "https://live.staticflickr.com/1228/1012662624_3699e2ff34_o.jpg"
    }
  , { src = "images/o/18.jpg"
    , name = "easy enough.."
    , link = "https://live.staticflickr.com/4063/4460929557_d6d426801d_o.jpg"
    }
  , { src = "images/o/19.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2086/2090758756_2f1400df7a_o.jpg"
    }
  , { src = "images/o/20.jpg"
    , name = "Mark Simpkins"
    , link = "https://live.staticflickr.com/23/39523552_1677de567b_o.jpg"
    }
  , { src = "images/o/21.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/5180/5501027093_646c412428_o.jpg"
    }
  , { src = "images/o/22.jpg"
    , name = "Karyn Christner"
    , link = "https://live.staticflickr.com/2407/1501179314_6e192c04ca_o.jpg"
    }
  , { src = "images/o/23.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/43/120874452_80dbc67976_o.jpg"
    }
  , { src = "images/o/24.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/7343/9065097992_032911e010_o.jpg"
    }
  , { src = "images/o/25.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3534/5845617174_bb461c4309_o.jpg"
    }
  , { src = "images/o/26.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/46/149475623_17b4c7d235_o.jpg"
    }
  , { src = "images/o/27.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/2091/2457393747_c9ca477848_o.jpg"
    }
  , { src = "images/o/28.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/48/137096798_a2c52bc907_o.jpg"
    }
  , { src = "images/o/29.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3168/5845858762_6664864031_o.jpg"
    }
  , { src = "images/o/30.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/228/518516030_26075a5441_o.jpg"
    }
  , { src = "images/o/31.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/129/397460214_2e2a2b1d0f_o.jpg"
    }
  , { src = "images/o/32.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3646/3824180237_5050bb90af_o.jpg"
    }
  , { src = "images/o/33.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8107/8562387285_858f79403a_o.jpg"
    }
  , { src = "images/o/34.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8094/8562375477_939fda16a1_o.jpg"
    }
  , { src = "images/o/35.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2029/2231644893_f3cce2d46e_o.jpg"
    }
  , { src = "images/o/36.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/3132/2652748571_676eefde14_o.jpg"
    }
  , { src = "images/o/37.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8458/8049582673_1e89826be2_o.jpg"
    }
  , { src = "images/o/38.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3829/9062877503_a219821d01_o.jpg"
    }
  , { src = "images/o/39.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3173/2633461630_5f578c43e5_o.jpg"
    }
  , { src = "images/o/40.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/2287/2743737853_d7cf368238_o.jpg"
    }
  , { src = "images/o/41.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/45/158985325_31fb282355_o.jpg"
    }
  , { src = "images/o/42.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/93/226359071_4cf4964db9_o.jpg"
    }
  , { src = "images/o/43.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/2230/1572609476_66e2d6a9c7_o.jpg"
    }
  , { src = "images/o/44.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1407/1197620379_889ce2ea2c_o.jpg"
    }
  , { src = "images/o/45.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/19/118376065_c985b62bbc_o.jpg"
    }
  , { src = "images/o/46.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8318/8049597634_1e813e6fe9_o.jpg"
    }
  , { src = "images/o/47.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/243/514217328_105eef9e0a_o.jpg"
    }
  , { src = "images/o/48.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2052/2185719247_0c4270163b_o.jpg"
    }
  , { src = "images/o/49.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2349/2594450936_a6e4332178_o.jpg"
    }
  , { src = "images/o/50.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8478/8202988253_d20f56a284_o.jpg"
    }
  , { src = "images/o/51.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5046/5332523666_f9bec06e49_o.jpg"
    }
  , { src = "images/o/52.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/102/362755499_2dc771b82d_o.jpg"
    }
  , { src = "images/o/53.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/52/115573940_c6ff808f39_o.jpg"
    }
  , { src = "images/o/54.jpg"
    , name = "duncan c"
    , link = "https://live.staticflickr.com/1279/537830161_e36769efc6_o.jpg"
    }
  , { src = "images/o/55.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/196/514249239_15f0b20fcf_o.jpg"
    }
  , { src = "images/o/56.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3214/5845679242_0d47ebb82f_o.jpg"
    }
  , { src = "images/o/57.jpg"
    , name = "Pat Joyce"
    , link = "https://live.staticflickr.com/5134/5401691576_6bf27ef01c_o.jpg"
    }
  , { src = "images/o/58.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/2666/3789240809_a9ab7072b1_o.jpg"
    }
  , { src = "images/o/59.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3133/5830485303_3cd98fb932_o.jpg"
    }
  , { src = "images/o/60.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1313/922098188_9568b46d23_o.jpg"
    }
  , { src = "images/o/61.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/149/402819245_3dca806273_o.jpg"
    }
  , { src = "images/o/62.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/55/112661896_b99bf7f6d1_o.jpg"
    }
  , { src = "images/o/63.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6004/5942404498_e66d13d965_o.jpg"
    }
  , { src = "images/o/64.jpg"
    , name = "Alvin Trusty"
    , link = "https://live.staticflickr.com/3696/9113796878_9e7960ef03_o.jpg"
    }
  , { src = "images/o/65.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2883/9065107146_0f95138a69_o.jpg"
    }
  , { src = "images/o/66.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2416/2371323705_4ac57d72ab_o.jpg"
    }
  , { src = "images/o/67.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/56/119577094_9555704fc7_o.jpg"
    }
  , { src = "images/o/68.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/578/31945462313_d0dd4af6f3_o.jpg"
    }
  , { src = "images/o/69.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/48/129596176_8442940856_o.jpg"
    }
  , { src = "images/o/70.jpg"
    , name = "From a red Corvette 1961"
    , link = "https://live.staticflickr.com/46/129596272_a42d873625_o.jpg"
    }
  , { src = "images/o/71.jpg"
    , name = "vd1966"
    , link = "https://live.staticflickr.com/65535/48821375302_812ba7acef_o.jpg"
    }
  , { src = "images/o/72.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/6077/6034473996_fe040ae5b3_o.jpg"
    }
  , { src = "images/o/73.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/60/185815523_4a4965f521_o.jpg"
    }
  , { src = "images/o/74.jpg"
    , name = "Letter O"
    , link = "https://live.staticflickr.com/4117/4888235059_56e1536b69_o.jpg"
    }
  , { src = "images/o/75.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/98/226363735_7081b48321_o.jpg"
    }
  , { src = "images/o/76.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8242/8630711898_4c5a171531_o.jpg"
    }
  , { src = "images/o/77.jpg"
    , name = "Judith, Bremen"
    , link = "https://live.staticflickr.com/7632/16143766384_e1062cbee3_o.jpg"
    }
  , { src = "images/o/78.jpg"
    , name = "Norm Wright"
    , link = "https://live.staticflickr.com/8242/8515087736_53a389ebdb_o.jpg"
    }
  , { src = "images/o/79.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/8312/7895950334_4bbb093cdf_o.jpg"
    }
  , { src = "images/o/80.jpg"
    , name = "Pekka Nikrus"
    , link = "https://live.staticflickr.com/1754/42174884894_827d1d50de_o.jpg"
    }
  , { src = "images/o/81.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/78/198424329_1a586d5991_o.jpg"
    }
  , { src = "images/o/82.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8170/8049580761_1196c08c13_o.jpg"
    }
  , { src = "images/o/83.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3699/9065108266_a78d9e9332_o.jpg"
    }
  , { src = "images/o/84.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5150/5659862566_b0cfc45079_o.jpg"
    }
  , { src = "images/o/85.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/8531/8606990362_129ed4e575_o.jpg"
    }
  , { src = "images/o/86.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/5274/14570729736_8c34815de2_o.jpg"
    }
  , { src = "images/o/87.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/3902/14407338147_af1ae1b245_o.jpg"
    }
  , { src = "images/o/88.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/57/240972296_5fa699219b_o.jpg"
    }
  , { src = "images/o/89.jpg"
    , name = "as in Otis"
    , link = "https://live.staticflickr.com/159/377132686_38453891e2_o.jpg"
    }
  , { src = "images/o/90.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/1/184812776_bcd19ee675_o.jpg"
    }
  , { src = "images/o/91.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/7319/9065106258_c4a9a8b7e0_o.jpg"
    }
  , { src = "images/o/92.jpg"
    , name = "Jess C"
    , link = "https://live.staticflickr.com/40/76710277_ad7b6e6a18_o.jpg"
    }
  , { src = "images/o/93.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/38/110630772_f5554cda65_o.jpg"
    }
  , { src = "images/o/94.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/7319/9062877775_9c751483e4_o.jpg"
    }
  , { src = "images/o/95.jpg"
    , name = "Tom Magliery"
    , link = "https://live.staticflickr.com/2489/3901957083_b6cbdc287d_o.jpg"
    }
  , { src = "images/o/96.jpg"
    , name = "Monceau"
    , link = "https://live.staticflickr.com/3008/2428973772_0cb8d33b9e_o.jpg"
    }
  , { src = "images/o/97.jpg"
    , name = "Marko V Niemelä"
    , link = "https://live.staticflickr.com/65535/48331560391_90528ffb0e_o.jpg"
    }
  ]
