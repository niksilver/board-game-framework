#!/bin/bash

# Crop down to a square image, from
# https://superuser.com/a/368134
# Uses graphicsmagick utility.
# Also creates the Elm code to reference that

function gen {
    MARK=$1
    OUTPUT="$MARK/$2.jpg"
    INPUT="source$MARK/$3"
    URL=$4
    NAME=$5
    gm convert $INPUT -thumbnail '600x600^' -gravity center -extent 600x600 +profile "*" "$OUTPUT"

    echo -n "
  , { src = \"images/$OUTPUT\"
    , name = \"$NAME\"
    , link = \"$URL\"
    }" >> ${MARK}out.elm
}

function genx {
    gen "x" "$1" "$2" "$3" "$4"
}

function geno {
    gen "o" "$1" "$2" "$3" "$4"
}

# Generating the X images

rm -f xout.elm

genx 0 '14114788851_8ce4713c51_o.jpg' 'https://www.flickr.com/photos/miglesias/14114788851/' "Maria Iglesias Barroso"
genx 1 '28659408095_9db7dcb12c_o.jpg' 'https://www.flickr.com/photos/adabo/28659408095/' "Björn"


# Generating the O images

rm -f oout.elm

geno 0 '2286486623_7bdbd2194a_o.jpg' 'https://www.flickr.com/photos/mag3737/2286486623/' "Tom Magliery"
geno 1 '2371325881_ecea401f6d_o.jpg' 'https://www.flickr.com/photos/mag3737/2371325881/' "Tom Magliery"
