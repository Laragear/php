#!/bin/bash

if [ ! -L /etc/localtime ]; then
    echo "Linking the timezone '$TZ' to /etc/localtime"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
fi

echo "Setting the container timezone to '$TZ'" > /dev/stdout
echo $TZ > /etc/timezone
