#!/bin/bash
# Make doc/cover.png, the Amiga GCC User's Manual cover, from the original
# drawing, which is not in the repository:
#
#   doc/cover.sh <cover-large.jpeg>
#
# Half size, 16 colors without dithering (enough for the antialiased line art),
# the top corners of the paper filled with blue-grey, the title in URW Z003
# (Zapf Chancery), then a lossless recompression.  Needs ImageMagick 7,
# zopflipng and the urw-base35 fonts.

set -euo pipefail

if [ $# -ne 1 ]; then
	echo "usage: $0 <cover-large.jpeg>" >&2
	exit 2
fi

out=$(dirname "$0")/cover.png
tmp=$(mktemp --suffix=.png)
trap 'rm -f "$tmp"' EXIT

magick "$1" -resize 50% -dither None -colors 16 \
	-fuzz 5% -fill '#d1e1e1' -draw 'color 0,0 floodfill' -draw 'color %[fx:w-1],0 floodfill' \
	-gravity North -font /usr/share/fonts/urw-base35/Z003-MediumItalic.otf \
	-pointsize 80 -interline-spacing -14 -fill '#1c1a17' -annotate +0+12 "Amiga GCC User's Manual" \
	-dither None -colors 16 PNG8:"$tmp"
zopflipng -y --iterations=15 "$tmp" "$out" >/dev/null
