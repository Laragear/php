#!/bin/sh

if [ $# -eq 0 ]; then
  exec /init
fi

if [ "$(id -u)" = "0" ]; then
  exec runuser -u "${USER:-developer}" -- "$@"
else
  exec "$@"
fi
