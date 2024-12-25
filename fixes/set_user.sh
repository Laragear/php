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

# Find user name with the given UID
USER_FOUND=$(getent passwd "$USER_ID" | cut -d: -f1)

# If we found an user for the given ID...
if [ -n "$USER_FOUND" ]; then
    echo "Changing the '${USER_FOUND}' to '${USER}'" > /dev/stdout
    # Change the name of the user found for what the developer has set, including its home directory.
    change_user_name_and_home "$USER" "$USER_FOUND"
else
    # If user doesn't exist, create a new user with a home directory
    echo "Creating the user '$USER' mapped as '$USER_ID:$GROUP_ID'" > /dev/stdout
    useradd -m -d "/home/$USER" $USER
    chown -R $USER_ID:$GROUP_ID "/home/$USER"
fi

# Set the user password to whatever it set
echo "Setting the '${USER}' password." > /dev/stdout
set_user_password "$USER"
