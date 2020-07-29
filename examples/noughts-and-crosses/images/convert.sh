#!/bin/bash

# Crop down to a square image, from
# https://superuser.com/a/368134
# Uses graphicsmagick utility.
# Also creates the Elm code to reference that

function gen {
    INPUT=$1
    URL=$2
    OUTPUT=$3
    NAME=$4
    MARK=$5
    gm convert $INPUT -thumbnail '600x600^' -gravity center -extent 600x600 +profile "*" "$MARK$OUTPUT"

    echo -n "
    , { filename=\"$OUTPUT\"
      , name=\"$NAME\"
      , url=\"$URL\"
      }" >> ${MARK}out.elm
}

function genx {
    gen "$1" "$2" "$3" "$4" "x"
}

function geno {
    gen "$1" "$2" "$3" "$4" "o"
}

# Generating the X images

genx '14114788851_8ce4713c51_o.jpg' 'https://www.flickr.com/photos/miglesias/14114788851/' '0.jpg' "Maria Iglesias Barroso"
genx '28659408095_9db7dcb12c_o.jpg' 'https://www.flickr.com/photos/adabo/28659408095/' '1.jpg' "Björn"


# Generating the O images

geno '2286486623_7bdbd2194a_o.jpg' 'https://www.flickr.com/photos/mag3737/2286486623/' '0.jpg' "Tom Magliery"
geno '2371325881_ecea401f6d_o.jpg' 'https://www.flickr.com/photos/mag3737/2371325881/' '1.jpg' "Tom Magliery"
