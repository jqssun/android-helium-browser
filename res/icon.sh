#!/bin/sh

# nix-shell -p imagemagick librsvg
tpl=$(dirname "$0")/icon.svg
w=$(identify -format %w "$1")

# k: design scale; dk/md/lt: sample points
case $(basename "$1") in
  layered_app_icon_background*) k=0.821 dk="500 100" md="80 500"  lt="920 500" \
                                mod='-e s/r="208"/r="9999"/' ;;
  layered_app_icon*)            k=0.593 dk="500 320" md="377 551" lt="644 575" ;;
  app_icon*)                    k=1.147 dk="500 151" md="262 598" lt="780 644" ;;
  *)                            k=1     dk="500 195" md="293 586" lt="742 625" ;;
esac

p() { echo "%[hex:u.p{$(($w * $1 / 1000)),$(($w * $2 / 1000))}]"; }
read dark mid light core <<EOF
$(convert "$1" -alpha off -format "$(p $dk) $(p $md) $(p $lt) $(p 500 500)" info:)
EOF

sed -e "s/#1c1c31/#$dark/" -e "s/#50507a/#$mid/" -e "s/#9393bf/#$light/" \
    -e "s/#23233b/#$core/" -e "s/scale(1)/scale($k)/" $mod "$tpl" \
  | rsvg-convert -w "$w" -h "$w" -o "$1" -
echo "$1 (${w}px, dark=#$dark mid=#$mid light=#$light)"
