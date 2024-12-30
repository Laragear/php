#!/command/with-contenv bash

# Define user and directories
SSH_DIR="/ssh"
SSHD_CONFIG_DIR="$SSH_DIR/sshd_config"
SSHD_KEYS_DIR="$SSH_DIR/sshd_keys"

# Copy the host SSH keys for the server to the new directory
echo "Ensuring SSH keys exist before starting the SSH Server." > /dev/stdout
sudo cp --update /etc/ssh/ssh_host_{rsa,ecdsa,ed25519}_key $SSHD_KEYS_DIR/

# Create a minimal sshd_config file if it doesn't exists.
if [ ! -f $SSHD_CONFIG_DIR/config ]; then
  echo "Setting the default SSH Server configuration" > /dev/stdout
  cat <<EOL > $SSHD_CONFIG_DIR/config
Port 22
ListenAddress 0.0.0.0
HostKey $SSHD_KEYS_DIR/ssh_host_rsa_key
HostKey $SSHD_KEYS_DIR/ssh_host_ecdsa_key
HostKey $SSHD_KEYS_DIR/ssh_host_ed25519_key
PidFile ~/sshd.pid
AuthorizedKeysFile $SSH_DIR/authorized_keys
PasswordAuthentication yes
ChallengeResponseAuthentication no
AcceptEnv LANG LC_*
EOL
fi

# Ensure the SSH directory is owned by the user
echo "Ensuring SSH configuration is owned by $USER" > /dev/stdout
sudo chown -R $USER_ID:$GROUP_ID /ssh
