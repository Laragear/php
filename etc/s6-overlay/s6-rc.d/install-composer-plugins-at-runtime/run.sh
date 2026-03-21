#!/command/with-contenv bash

SENTINEL_FILE="/home/$USER/.composer_packages_installed"

# Check if the extensions environment variable is not empty.
if [ -z "$COMPOSER_RUNTIME_PACKAGES" ]; then
  echo "No additional Composer plugins to install at runtime." > /dev/stdout
  exit 0
fi

if [ -f "$SENTINEL_FILE" ]; then
  echo "Composer packages already installed (sentinel file exists). Skipping." > /dev/stdout
  exit 0
fi

echo "Installing additional Composer plugins at runtime:" > /dev/stdout
echo "$COMPOSER_RUNTIME_PACKAGES" > /dev/stdout

# Install the new extensions
if s6-setuidgid $USER /usr/local/bin/composer global require --no-cache --prefer-stable $COMPOSER_RUNTIME_PACKAGES 2>&1; then
  echo "Installation successful. Creating sentinel file at $SENTINEL_FILE" > /dev/stdout
  s6-setuidgid $USER touch "$SENTINEL_FILE"
else
  echo "Composer installation failed. Sentinel file not created." > /dev/stderr
  exit 1
fi
