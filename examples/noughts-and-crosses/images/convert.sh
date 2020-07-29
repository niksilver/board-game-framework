#!/bin/sh

# Crop down to a square image, from
# https://superuser.com/a/368134
# Uses graphicsmagick utility.

INPUT=$1
OUTPUT=image2.jpg
gm convert -size 200x200 $INPUT -thumbnail '600x600^' -gravity center -extent 600x600 +profile "*" $OUTPUT
file $OUTPUT
