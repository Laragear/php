#!/bin/bash

# Ensure the user home exists by setting the correct path, creating it, and adding proper permissions.
echo "Ensuring the '$HOME' home directory exists for '$USER'" > /dev/stdout
HOME="/home/$USER"
export HOME
mkdir -p $HOME
chown $USER_ID:$GROUP_ID $HOME

# Check if the USER_ID already exists
if id -u $USER_ID >/dev/null 2>&1; then
    EXISTING_USER=$(getent passwd $USER_ID | cut -d: -f1)

    # If the user name is different than the container user, change the name
    if [ "$EXISTING_USER" != "$USER" ]; then
        echo "Changing the '$EXISTING_USER' user to '$USER'." > /dev/stdout
        # Move the home directory of the existing user
        usermod -l $USER -d /home/$USER -m $EXISTING_USER
    fi
# The USER_ID doesn't exists, so we will create it
else
    # Check if the GROUP_ID exists
    if ! getent group $GROUP_ID >/dev/null 2>&1; then
        echo "Creating the '$GROUP_ID'." > /dev/stdout
        # Create the group with the specified GROUP_ID
        groupadd -g $GROUP_ID groupname
    fi

    # Check if the USER doesn't exists
    if ! id -u $USER >/dev/null 2>&1; then
        echo "Adding '$USER' as '$USER_ID:$GROUP_ID' to the container." > /dev/stdout
        # Create a new user with the specified USER_ID and GROUP_ID
        useradd -u $USER_ID -g $GROUP_ID -m -d /home/$USER $USER
    fi
fi

# Fix the home directory permissions just in case
echo "Fixing Home permissions" > /dev/stdout
chown -R $USER_ID:$GROUP_ID $HOME

# Set the user password to whatever it set
echo "Setting the '$USER' password." > /dev/stdout
echo $USER:$USER_PWD | chpasswd
