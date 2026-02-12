#!/bin/bash

# Configuration
NEW_USER="saxo"
PASSWORD="t113"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# Create the user with a home directory and default shell
useradd -m -s /bin/bash "$NEW_USER"

# Set the password (using chpasswd to avoid plaintext exposure in process list)
echo "${NEW_USER}:${PASSWORD}" | chpasswd

# Add user to dialout group (needed for serial/USB device access)
usermod -aG dialout "$NEW_USER"

# Add user to sudo group (Debian uses 'sudo' group for admin privileges)
usermod -aG sudo "$NEW_USER"

echo "User '${NEW_USER}' created successfully."
echo "- Password set"
echo "- Added to 'dialout' group"
echo "- Granted sudo privileges"
