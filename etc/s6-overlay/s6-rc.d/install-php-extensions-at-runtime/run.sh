#!/command/with-contenv bash

SENTINEL_FILE="/home/$USER/.php_extensions_installed"

# Check if the extensions environment variable is not empty.
if [ -z "$PHP_RUNTIME_EXTENSIONS" ]; then
  echo "No additional PHP extensions to install at runtime." > /dev/stdout
  exit 0
fi

if [ -f "$SENTINEL_FILE" ]; then
  echo "PHP extensions already installed (sentinel file exists). Skipping." > /dev/stdout
  exit 0
fi

echo "Installing additional PHP extensions at runtime:" > /dev/stdout
echo "$PHP_RUNTIME_EXTENSIONS" > /dev/stdout

# Install the new extensions
if install-php-extensions $PHP_RUNTIME_EXTENSIONS 2>&1; then
  echo "Installation successful. Creating sentinel file at $SENTINEL_FILE" > /dev/stdout
  s6-setuidgid $USER touch "$SENTINEL_FILE"
else
  echo "PHP extensions installation failed. Sentinel file not created." > /dev/stderr
  exit 1
fi
