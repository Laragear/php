#!/command/with-contenv bash

# Check if a command was provided
if [ $# -eq 0 ]; then
  echo "No command provided. Exiting..."
  exit 0
fi

# Execute the command
exec /command/s6-setuidgid $USER "$@"
