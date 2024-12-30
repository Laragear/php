#!/command/with-contenv bash

# Check if the extensions environment variable is not empty.
if [ -z "$PHP_RUNTIME_EXTENSIONS" ]; then
  echo "No additional PHP extensions to install at runtime." > /dev/stdout
  exit 0
fi

echo "Installing additional PHP extensions at runtime:" > /dev/stdout
echo "$PHP_RUNTIME_EXTENSIONS" > /dev/stdout

# Install the new extensions
exec sudo install-php-extensions $PHP_RUNTIME_EXTENSIONS 2>&1
