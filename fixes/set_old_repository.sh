#!/bin/bash

# Get the Debian codename from /etc/os-release
codename=$(grep VERSION_CODENAME /etc/os-release | cut -d '=' -f 2)

# If VERSION_CODENAME is not set, try to extract it from VERSION
if [ -z "$codename" ]; then
    codename=$(grep VERSION /etc/os-release | sed -n 's/.*(\(.*\)).*/\1/p')
fi

# Check if there is no APT repository for the current version, and change to the archive
if ! curl --output /dev/null --silent --head --fail "https://ftp.debian.org/debian/dists/$codename"; then
     echo "This Debian release ($codename) has reached EOL. Using archive repository" > /dev/stdout
     sed -i s/deb.debian.org/archive.debian.org/g /etc/apt/sources.list
     sed -i s/security.debian.org/archive.debian.org/g /etc/apt/sources.list

     # Check if {CODENAME}-updates exists. If it doesn't remove it from the sources.list.
     if ! curl --output /dev/null --silent --head --fail "https://archive.debian.org/debian/dists/$codename-updates"; then
         echo "This Debian release ($codename) doesn't have *-updates repository, removing." > /dev/stdout
         sed -i /stretch-updates/d /etc/apt/sources.list
     fi
else
    echo "Your Debian release ($codename) is still supported. No repository change needed." > /dev/stdout
fi
