#!/command/with-contenv bash

echo "Fixing permissions for '${USER}' mapped as ${USER_ID}:${GROUP_ID}" > /dev/stdout

chown -R ${USER_ID}:${GROUP_ID} /app

chown ${USER_ID}:${GROUP_ID} /var/www/html
chown ${USER_ID}:${GROUP_ID} /opt/project
chown ${USER_ID}:${GROUP_ID} /home/${USER}/project
