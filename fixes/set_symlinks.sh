#!/bin/bash

echo "Creating the '$PROJECT_PATH' directory for '$USER_ID:$GROUP_ID'" > /dev/stdout

mkdir -p $PROJECT_PATH
chown $USER_ID:$GROUP_ID $PROJECT_PATH

echo "Adding project symlinks to '$PROJECT_PATH'" > /dev/stdout

PATHS="/var/www/html /opt/project /home/${USER}/project"

for TARGET_PATH in $PATHS; do
    # First, ensure the target path exists if it doesn't
    echo "Ensuring the '$TARGET_PATH' exists for '$USER_ID:$GROUP_ID'." > /dev/stdout
    mkdir -p $TARGET_PATH
    chown $USER_ID:$GROUP_ID $TARGET_PATH

    # If the path is a symlink, do nothing and continue
    if [ -L "$TARGET_PATH" ]; then
        continue
    fi

    # If the path is a directory and is empty, remove it.
    if [ -d "$TARGET_PATH" ] && [ -z "$(ls -A $TARGET_PATH)" ]; then
        echo "The path '$TARGET_PATH' exists and is empty, removing it forcefully." > /dev/stdout
        rmdir $TARGET_PATH
    fi

    # Create a symlink replacing the directory
    echo "Add a symlink to '$PROJECT_PATH' in '$TARGET_PATH' for '$USER_ID:$GROUP_ID'."
    ln -sfn $PROJECT_PATH $TARGET_PATH
    chown $USER_ID:$GROUP_ID $TARGET_PATH
done
