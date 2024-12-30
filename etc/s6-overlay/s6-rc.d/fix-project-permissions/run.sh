#!/command/with-contenv bash

echo "Fixing permissions for '${USER}' mapped as ${USER_ID}:${GROUP_ID}" > /dev/stdout

PATHS="$PROJECT_PATH /var/www/html /opt/project /home/${USER}/project"

for PROJECT_DIRECTORY in $PATHS; do
    if [ "$(stat -c "%u" "$PROJECT_DIRECTORY")" -ne $USER_ID ]; then
        # If the PROJECT_DIRECTORY is a directory and not a symlink
        echo "Fixing permissions for '${PROJECT_DIRECTORY}'" > /dev/stdout
        if [ -d "$PROJECT_DIRECTORY" ] && [ ! -L "$PROJECT_DIRECTORY" ]; then
            sudo chown -R "$USER_ID:$GROUP_ID" $PROJECT_DIRECTORY
        elif [ -e "$PROJECT_DIRECTORY" ]; then
            sudo chown "$USER_ID:$GROUP_ID" $PROJECT_DIRECTORY
        fi
    fi
done
