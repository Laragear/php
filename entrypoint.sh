#!/command/with-contenv bash

if [ $# -gt 0 ]; then
  exec "$@"
else
  exec /init
fi
