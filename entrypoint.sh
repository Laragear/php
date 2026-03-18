#!/bin/sh

if [ $# -eq 0 ]; then
  exec /init
fi

exec su "${USER:-developer}" -c "$*"
