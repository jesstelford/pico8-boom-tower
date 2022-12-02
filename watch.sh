#!/bin/sh
pico8bin=$(which pico8)
if [ -z $pico8bin ]
then
  OS="`uname`"
  case $OS in
    'Linux')
      echo "ERROR: Please add pico8 to your path"
      exit 1
      ;;
    'Darwin') 
      pico8bin="/Applications/PICO-8.app/Contents/MacOS/pico8"
      ;;
    *)
      echo "ERROR: Unknown OS"
      exit 1
    ;;
  esac
fi

if [ ! -f $pico8bin ]; then
    echo "ERROR: Unable to locate pico8 binary"
    exit 1
fi

npx --yes chokidar-cli@^3.0.0 "**/*.{lua,p8}" -c "$pico8bin -x ./main.p8 -export ./export/index.html"
