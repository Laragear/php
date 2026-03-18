#!/bin/sh

if [ $# -eq 0 ]; then
  exec /init
fi

exec /command/s6-setuidgid "${USER:-developer}" "$@"
