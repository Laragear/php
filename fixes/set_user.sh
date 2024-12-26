#!/usr/bin/env bash

# Check if the USER_ID already exists
if id -u $USER_ID >/dev/null 2>&1; then
    EXISTING_USER=$(getent passwd $USER_ID | cut -d: -f1)

    if [ "$EXISTING_USER" != "$USER" ]; then
        echo "Changing the '$EXISTING_USER' user to '$USER' to." > /dev/stdout
        # Move the home directory of the existing user
        usermod -l $USER -d /home/$USER -m $EXISTING_USER
    fi
else
    # Check if the USER exists
    if id -u $USER >/dev/null 2>&1; then
        echo "Adjusting '$USER' permissions to '$USER:$GROUP_ID'." > /dev/stdout
        # Adjust home directory permissions to the new USER_ID and GROUP_ID
        chown -R $USER_ID:$GROUP_ID /home/$USER
    else
        echo "Adding '$USER' as '$USER:$GROUP_ID' to the container." > /dev/stdout
        # Create a new user with the specified USER_ID and GROUP_ID
        useradd -u $USER_ID -g $GROUP_ID -m -d /home/$USER $USER
        # Add a symlink to the application directory
        ln -s /app /home/$USER/project
    fi
fi

# Set the user password to whatever it set
echo "Setting the '$USER' password." > /dev/stdout
echo "$USER:$USER_PWD" | chpasswd
