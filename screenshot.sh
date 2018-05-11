#!/usr/bin/env bash
# Break script on any non-zero status of any command
set -e

NAME=$(date +%Y%m%d_%H%M%S)

if [[ -n "$1" ]]; then
    NAME=$1
fi

NAME=${NAME}.png

echo NAME:$NAME

import -window root /tmp/screenshots/$NAME
