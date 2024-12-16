#!/usr/bin/env bash

# Function to change user's name and set home directory permissions
change_user_name_and_home() {
    usermod -l "$1" -d "/home/$1" -m "$2"
    chown -R "$1:$1" "/home/$1"
}

# Function to set user's password
set_user_password() {
    echo "$1:${USER_PWD}" | chpasswd
}

# Find user with the given UID
USER_FOUND=$(getent passwd "$USER_ID" | cut -d: -f1)

if [ -n "$USER_FOUND" ]; then
    echo "Changing the '${USER_FOUND}' to '${USER}'" > /dev/stdout
    # If user exists for the given User ID, change the name and set the home directory with proper permissions
    change_user_name_and_home "$USER" "$USER_FOUND"
    set_user_password "$USER"
else
    # If user doesn't exist, create a new user with a home directory
    echo "Creating the user '$USER' mapped as '$USER_ID:$GROUP_ID'" > /dev/stdout
    useradd -m -d "/home/$USER" $USER
    set_user_password "$USER"
    chown -R $USER_ID:$GROUP_ID "/home/$USER"
fi
