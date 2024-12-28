#!/bin/bash

echo "Creating the '$PROJECT_PATH' directory" > /dev/stdout

mkdir -p $PROJECT_PATH

echo "Adding project symlinks to '$PROJECT_PATH'" > /dev/stdout

PATHS="/var/www/html /opt/project /home/${USER}/project"

for TARGET_PATH in $PATHS; do
    # First, ensure the target path exists if it doesn't
    echo "Ensuring the '$TARGET_PATH' exists." > /dev/stdout
    mkdir -p $TARGET_PATH

    # If the path is a symlink, do nothing.
    if [ -L "$TARGET_PATH" ]; then
        continue
    fi

    # If the directory exists and is empty, remove it.
    if [ -d "$TARGET_PATH" ] && [ -z "$(ls -A $TARGET_PATH)" ]; then
        echo "The path '$TARGET_PATH' exists and is empty, removing it." > /dev/stdout
        rmdir $TARGET_PATH
    fi

    # Create a symlink replacing the directory
    echo "Add a symlink to '$PROJECT_PATH' in '$TARGET_PATH'."
    ln -sfn $PROJECT_PATH $TARGET_PATH
done
